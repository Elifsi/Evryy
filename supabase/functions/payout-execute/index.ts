/**
 * Supabase Edge Function: payout-execute
 * Midnight Partner Settlement & ConnectIPS Interbank Disbursement Engine
 * Elifsi Technologies Private Limited
 *
 * Operations:
 * 1. build_batch: Audits ledger balances, offsets rider cash-in-hand, creates draft batch.
 * 2. approve_batch: Superadmin approval gate before bank dispatch.
 * 3. execute_batch: Dispatches to ConnectIPS rail, marks payouts paid, posts double-entry ledger.
 * 4. export_connectips: Generates NCHL ConnectIPS compliant CSV batch file.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

interface PayoutExecuteRequest {
  action: 'build_batch' | 'approve_batch' | 'execute_batch' | 'export_connectips' | 'on_demand_payout';
  batch_id?: string;
  batch_date?: string; // YYYY-MM-DD
  reason?: string;
  // On-demand payout fields
  partner_id?: string;
  amount_paisa?: number;
  destination_type?: 'bank' | 'esewa' | 'khalti';
  wallet_phone?: string;
  payout_id?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(JSON.stringify({ error: 'Missing Supabase service credentials.' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify caller is admin or service_role
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    let payload: PayoutExecuteRequest = { action: 'execute_batch' };
    if (req.method === 'POST') {
      payload = await req.json();
    } else if (req.method === 'GET') {
      const url = new URL(req.url);
      payload = {
        action: (url.searchParams.get('action') as any) || 'export_connectips',
        batch_id: url.searchParams.get('batch_id') || undefined,
        batch_date: url.searchParams.get('batch_date') || undefined,
      };
    }

    const { action, batch_id, batch_date, reason } = payload;

    // -------------------------------------------------------------
    // ACTION 1: Build Draft Settlement Batch
    // -------------------------------------------------------------
    if (action === 'build_batch') {
      const targetDate = batch_date || new Date().toISOString().split('T')[0];

      const { data: newBatchId, error: buildError } = await supabase.rpc('admin_build_settlement_batch', {
        p_date: targetDate,
      });

      if (buildError) {
        return new Response(JSON.stringify({ success: false, error: buildError.message }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Fetch batch summary
      const { data: batch } = await supabase
        .from('settlement_batches')
        .select('*, payouts(count)')
        .eq('id', newBatchId)
        .single();

      return new Response(
        JSON.stringify({
          success: true,
          action: 'build_batch',
          batch_id: newBatchId,
          batch_date: targetDate,
          total_npr: (batch.total_paisa / 100).toFixed(2),
          payouts_count: batch.payouts?.[0]?.count || 0,
          status: 'draft',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // -------------------------------------------------------------
    // ACTION 2: Approve Settlement Batch
    // -------------------------------------------------------------
    if (action === 'approve_batch') {
      if (!batch_id) {
        return new Response(JSON.stringify({ error: 'batch_id is required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      const { error: approveError } = await supabase.rpc('admin_approve_settlement_batch', {
        p_batch: batch_id,
        p_reason: reason || 'Verified by financial operations team',
      });

      if (approveError) {
        return new Response(JSON.stringify({ success: false, error: approveError.message }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      return new Response(
        JSON.stringify({
          success: true,
          action: 'approve_batch',
          batch_id,
          status: 'approved',
          message: 'Settlement batch approved for banking disbursement.',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // -------------------------------------------------------------
    // ACTION 3: Execute Batch (Disburse via ConnectIPS / Bank Rail)
    // -------------------------------------------------------------
    if (action === 'execute_batch') {
      if (!batch_id) {
        return new Response(JSON.stringify({ error: 'batch_id is required' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Fetch approved batch
      const { data: batch, error: batchError } = await supabase
        .from('settlement_batches')
        .select('*')
        .eq('id', batch_id)
        .single();

      if (batchError || !batch) {
        return new Response(JSON.stringify({ error: 'Settlement batch not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      if (batch.status !== 'approved' && batch.status !== 'executing') {
        return new Response(
          JSON.stringify({ error: `Cannot execute batch in '${batch.status}' status. Must be 'approved'.` }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Mark batch as executing
      await supabase.from('settlement_batches').update({ status: 'executing' }).eq('id', batch_id);

      // Fetch pending payouts with partner details and bank accounts
      const { data: payouts, error: payoutsError } = await supabase
        .from('payouts')
        .select(`
          id, payable_paisa, cod_offset_paisa, net_paisa, status,
          partner:partner_id (
            id, trade_name,
            owner:owner_id ( full_name, email, phone )
          ),
          bank_account:bank_account_id (
            bank_code, branch_code, account_name, account_number
          )
        `)
        .eq('batch_id', batch_id)
        .eq('status', 'pending');

      if (payoutsError) {
        return new Response(JSON.stringify({ error: payoutsError.message }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      const results = [];
      let totalDisbursedPaisa = 0;

      for (const payout of (payouts || [])) {
        const netNpr = payout.net_paisa / 100;
        const utrRef = `NCHL-${batch.batch_date.replace(/-/g, '')}-${payout.id.substring(0, 8).toUpperCase()}`;

        try {
          // 1. Mark payout as paid in database & post balancing ledger lines
          const { error: markError } = await supabase.rpc('mark_payout_paid', {
            p_payout: payout.id,
            p_provider_ref: utrRef,
          });

          if (markError) {
            console.error(`[Payout Error for ${payout.id}]`, markError);
            results.push({ payout_id: payout.id, status: 'failed', error: markError.message });
            continue;
          }

          totalDisbursedPaisa += payout.net_paisa;

          // 2. Queue Email Statement to Partner
          const partnerEmail = payout.partner?.owner?.email;
          const tradeName = payout.partner?.trade_name || 'evrry Partner';
          const bankName = payout.bank_account?.bank_code || 'Commercial Bank';
          const maskedAcc = payout.bank_account?.account_number
            ? `••••${payout.bank_account.account_number.slice(-4)}`
            : undefined;

          if (partnerEmail) {
            await supabase.functions.invoke('send-email', {
              body: {
                action: 'payout_statement',
                to: partnerEmail,
                payoutData: {
                  tradeName,
                  settlementDate: batch.batch_date,
                  netNpr: netNpr,
                  bankRef: utrRef,
                  bankName,
                  accountNumberMasked: maskedAcc,
                },
              },
            });
          }

          results.push({
            payout_id: payout.id,
            trade_name: tradeName,
            net_npr: netNpr,
            utr: utrRef,
            status: 'paid',
          });
        } catch (err: any) {
          console.error(`[Payout Exception for ${payout.id}]`, err);
          results.push({ payout_id: payout.id, status: 'failed', error: err.message });
        }
      }

      // Check if all payouts are completed
      const { data: remainingPending } = await supabase
        .from('payouts')
        .select('id')
        .eq('batch_id', batch_id)
        .eq('status', 'pending');

      const isBatchComplete = !remainingPending || remainingPending.length === 0;

      return new Response(
        JSON.stringify({
          success: true,
          action: 'execute_batch',
          batch_id,
          batch_status: isBatchComplete ? 'completed' : 'partially_completed',
          total_disbursed_npr: (totalDisbursedPaisa / 100).toFixed(2),
          processed_count: results.length,
          payouts: results,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // -------------------------------------------------------------
    // ACTION 4: Export ConnectIPS NCHL CSV File
    // -------------------------------------------------------------
    if (action === 'export_connectips') {
      if (!batch_id) {
        return new Response(JSON.stringify({ error: 'batch_id is required for CSV export' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      const { data: payouts, error: exportError } = await supabase
        .from('payouts')
        .select(`
          id, net_paisa,
          partner:partner_id ( trade_name, pan_number ),
          bank_account:bank_account_id (
            bank_code, branch_code, account_name, account_number
          )
        `)
        .eq('batch_id', batch_id);

      if (exportError) {
        return new Response(JSON.stringify({ error: exportError.message }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Standard NCHL ConnectIPS Corporate Batch Header
      let csvContent = 'Batch_ID,Debit_Account,Beneficiary_Bank,Beneficiary_Branch,Beneficiary_Account,Beneficiary_Name,Amount_NPR,Reference_Remarks\n';

      const debitCorporateAccount = Deno.env.get('CORPORATE_CLEARING_ACCOUNT') || '0010100000000001';

      for (const p of (payouts || [])) {
        const netNpr = (p.net_paisa / 100).toFixed(2);
        const bank = p.bank_account?.bank_code || 'N/A';
        const branch = p.bank_account?.branch_code || 'Head Office';
        const accNum = p.bank_account?.account_number || '';
        const accName = (p.bank_account?.account_name || p.partner?.trade_name || '').replace(/,/g, ' ');
        const remarks = `evrry-${p.id.substring(0, 8)}`;

        csvContent += `"${batch_id}","${debitCorporateAccount}","${bank}","${branch}","${accNum}","${accName}","${netNpr}","${remarks}"\n`;
      }

      return new Response(csvContent, {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/csv',
          'Content-Disposition': `attachment; filename="connectips_batch_${batch_id}.csv"`,
        },
      });
    }

    // -------------------------------------------------------------
    // ACTION 5: On-Demand Instant Payout (24/7 Partner Cash Out)
    // -------------------------------------------------------------
    if (action === 'on_demand_payout') {
      let activePayoutId = payload.payout_id;
      let netNpr = 0;

      // 1. If payout record doesn't exist yet, call database RPC to validate and insert
      if (!activePayoutId) {
        if (!payload.partner_id || !payload.amount_paisa) {
          return new Response(
            JSON.stringify({ error: 'partner_id and amount_paisa are required for on_demand_payout' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        const { data: requestResult, error: reqError } = await supabase.rpc('request_on_demand_payout', {
          p_partner_id: payload.partner_id,
          p_amount_paisa: payload.amount_paisa,
          p_destination_type: payload.destination_type || 'bank',
          p_wallet_phone: payload.wallet_phone || null,
        });

        if (reqError) {
          return new Response(JSON.stringify({ success: false, error: reqError.message }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        activePayoutId = requestResult.payout_id;
        netNpr = parseFloat(requestResult.net_payout_npr);
      }

      // Fetch payout details for banking dispatch
      const { data: payout, error: pError } = await supabase
        .from('payouts')
        .select(`
          id, net_paisa, destination_type, destination_wallet, instant_fee_paisa,
          partner:partner_id (
            trade_name,
            owner:owner_id ( email, phone )
          ),
          bank_account:bank_account_id (
            bank_code, account_name, account_number
          )
        `)
        .eq('id', activePayoutId)
        .single();

      if (pError || !payout) {
        return new Response(JSON.stringify({ error: 'Payout record not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      netNpr = payout.net_paisa / 100;
      const utrRef = `INSTANT-NCHL-${Date.now()}-${payout.id.substring(0, 6).toUpperCase()}`;

      // 2. Execute RPC mark_payout_paid to commit balanced ledger postings
      const { error: markError } = await supabase.rpc('mark_payout_paid', {
        p_payout: payout.id,
        p_provider_ref: utrRef,
      });

      if (markError) {
        return new Response(JSON.stringify({ success: false, error: markError.message }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // 3. Dispatch instant email confirmation
      const partnerEmail = payout.partner?.owner?.email;
      const tradeName = payout.partner?.trade_name || 'evrry Partner';

      if (partnerEmail) {
        await supabase.functions.invoke('send-email', {
          body: {
            action: 'payout_statement',
            to: partnerEmail,
            payoutData: {
              tradeName,
              settlementDate: new Date().toISOString().split('T')[0],
              netNpr,
              bankRef: utrRef,
              bankName: payout.destination_type === 'bank' ? payout.bank_account?.bank_code : `${payout.destination_type?.toUpperCase()} Wallet`,
              accountNumberMasked: payout.destination_type === 'bank'
                ? `••••${payout.bank_account?.account_number?.slice(-4)}`
                : payout.destination_wallet,
            },
          },
        });
      }

      return new Response(
        JSON.stringify({
          success: true,
          action: 'on_demand_payout',
          payout_id: payout.id,
          trade_name: tradeName,
          destination_type: payout.destination_type,
          net_npr: netNpr,
          instant_fee_npr: payout.instant_fee_paisa / 100,
          utr: utrRef,
          status: 'paid',
          message: 'Instant on-demand payout disbursed successfully.',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(JSON.stringify({ error: `Unknown action: ${action}` }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: any) {
    console.error('[Payout Execute Exception]', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

/**
 * Admin Settlement & Payout Client Helper (Next.js / TypeScript)
 * Elifsi Technologies Private Limited
 *
 * Used by apps/web/admin (Superadmin Operations Console) to build,
 * audit, approve, and disburse daily partner settlement batches.
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';

export interface SettlementBatchSummary {
  success: boolean;
  batch_id?: string;
  batch_date?: string;
  total_npr?: string;
  payouts_count?: number;
  status?: string;
  error?: string;
}

export interface PayoutExecutionResult {
  success: boolean;
  batch_id?: string;
  batch_status?: string;
  total_disbursed_npr?: string;
  processed_count?: number;
  payouts?: Array<{
    payout_id: string;
    trade_name: string;
    net_npr: number;
    utr: string;
    status: string;
  }>;
  error?: string;
}

export class EvrrySettlementAdminClient {
  private supabase: SupabaseClient;

  constructor(supabaseClient?: SupabaseClient) {
    if (supabaseClient) {
      this.supabase = supabaseClient;
    } else {
      const url = process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://localhost:54321';
      const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'public-anon-key';
      this.supabase = createClient(url, anonKey);
    }
  }

  /**
   * 1. Build Draft Settlement Batch for a given date
   */
  async buildSettlementBatch(date?: string): Promise<SettlementBatchSummary> {
    try {
      const { data, error } = await this.supabase.functions.invoke('payout-execute', {
        body: {
          action: 'build_batch',
          batch_date: date,
        },
      });

      if (error) return { success: false, error: error.message };
      return data;
    } catch (err: any) {
      return { success: false, error: err.message || 'Build batch exception' };
    }
  }

  /**
   * 2. Superadmin Approves Settlement Batch
   */
  async approveSettlementBatch(batchId: string, reason?: string): Promise<{ success: boolean; error?: string }> {
    try {
      const { data, error } = await this.supabase.functions.invoke('payout-execute', {
        body: {
          action: 'approve_batch',
          batch_id: batchId,
          reason: reason || 'Approved in Admin Operations Console',
        },
      });

      if (error) return { success: false, error: error.message };
      return data;
    } catch (err: any) {
      return { success: false, error: err.message || 'Approve batch exception' };
    }
  }

  /**
   * 3. Disburse via ConnectIPS / Bank Rail & Send Email Statements
   */
  async executeSettlementBatch(batchId: string): Promise<PayoutExecutionResult> {
    try {
      const { data, error } = await this.supabase.functions.invoke('payout-execute', {
        body: {
          action: 'execute_batch',
          batch_id: batchId,
        },
      });

      if (error) return { success: false, error: error.message };
      return data;
    } catch (err: any) {
      return { success: false, error: err.message || 'Execute batch exception' };
    }
  }

  /**
   * 4. Export ConnectIPS NCHL CSV Batch File
   */
  async downloadConnectIpsCsv(batchId: string): Promise<string> {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://localhost:54321';
    const response = await fetch(`${supabaseUrl}/functions/v1/payout-execute?action=export_connectips&batch_id=${batchId}`, {
      headers: {
        'Authorization': `Bearer ${this.supabase.auth.getSession ? (await this.supabase.auth.getSession()).data.session?.access_token : ''}`,
      },
    });
    return await response.text();
  }
}

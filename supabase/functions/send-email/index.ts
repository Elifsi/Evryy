/**
 * Supabase Edge Function: send-email
 * Universal Resend Email Dispatcher for evrry Super App
 * Elifsi Technologies Private Limited
 *
 * Supported Clients:
 * - Android (Kotlin): apps/consumer/android, apps/partner/android via supabase-kt Functions
 * - iOS (Swift): apps/consumer/ios, apps/partner/ios via supabase-swift Functions
 * - Web (Next.js): apps/web/admin, apps/web/partner, apps/web/consumer
 * - PostgreSQL Triggers / Database Webhooks
 */

import { InvoiceData, renderInvoiceHtml } from './templates/invoice.ts';
import { VerificationEmailData, renderVerificationEmailHtml } from './templates/verification.ts';
import { KycEmailData, renderKycStatusHtml } from './templates/kyc.ts';
import { PayoutEmailData, renderPayoutStatementHtml } from './templates/payout.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface SendEmailPayload {
  action: 'order_invoice' | 'verification_otp' | 'partner_kyc_status' | 'payout_statement' | 'custom';
  to: string;
  // Optional custom payload
  subject?: string;
  html?: string;
  // Specific payload types
  invoiceData?: InvoiceData;
  otpData?: VerificationEmailData;
  kycData?: KycEmailData;
  payoutData?: PayoutEmailData;
}

Deno.serve(async (req: Request) => {
  // Handle CORS Preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed. Use POST.' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const payload: SendEmailPayload = await req.json();
    const { action, to } = payload;

    if (!to || !action) {
      return new Response(
        JSON.stringify({ error: 'Missing required parameters: action and to are mandatory.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    let subject = payload.subject || 'evrry Notification';
    let html = payload.html || '';

    // Render templates based on action
    switch (action) {
      case 'order_invoice': {
        if (!payload.invoiceData) {
          return new Response(JSON.stringify({ error: 'invoiceData is required for order_invoice' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        subject = `Your evrry Order Invoice #${payload.invoiceData.orderNo} (NPR ${(payload.invoiceData.totalPaisa / 100).toFixed(2)})`;
        html = renderInvoiceHtml(payload.invoiceData);
        break;
      }

      case 'verification_otp': {
        if (!payload.otpData) {
          return new Response(JSON.stringify({ error: 'otpData is required for verification_otp' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        subject = `evrry Verification Code: ${payload.otpData.otpCode}`;
        html = renderVerificationEmailHtml(payload.otpData);
        break;
      }

      case 'partner_kyc_status': {
        if (!payload.kycData) {
          return new Response(JSON.stringify({ error: 'kycData is required for partner_kyc_status' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        const rendered = renderKycStatusHtml(payload.kycData);
        subject = rendered.subject;
        html = rendered.html;
        break;
      }

      case 'payout_statement': {
        if (!payload.payoutData) {
          return new Response(JSON.stringify({ error: 'payoutData is required for payout_statement' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        const rendered = renderPayoutStatementHtml(payload.payoutData);
        subject = rendered.subject;
        html = rendered.html;
        break;
      }

      case 'custom': {
        if (!payload.subject || !payload.html) {
          return new Response(JSON.stringify({ error: 'subject and html are required for custom action' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        break;
      }

      default: {
        return new Response(JSON.stringify({ error: `Unknown action: ${action}` }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    // Retrieve Resend configuration from environment
    const resendApiKey = Deno.env.get('RESEND_API_KEY');
    const fromEmail = Deno.env.get('RESEND_FROM_EMAIL') || 'evrry <noreply@evrry.com>';

    // Fallback Mock Mode (for local development or if RESEND_API_KEY is not yet provisioned)
    if (!resendApiKey) {
      console.log(`[Supabase Edge Function: Mock Email]`);
      console.log(`Action: ${action}`);
      console.log(`To: ${to}`);
      console.log(`Subject: ${subject}`);
      console.log(`HTML Length: ${html.length} chars`);

      return new Response(
        JSON.stringify({
          success: true,
          mock: true,
          id: `mock_edge_${Date.now()}`,
          message: 'Email processed in mock mode. Set RESEND_API_KEY in Supabase secrets to send live emails.',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Live Resend API Dispatch
    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [to],
        subject,
        html,
      }),
    });

    const result = await resendResponse.json();

    if (!resendResponse.ok) {
      console.error('[Resend Edge Error]', result);
      return new Response(
        JSON.stringify({ success: false, error: result.message || 'Failed to dispatch email via Resend' }),
        { status: resendResponse.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, id: result.id }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error: any) {
    console.error('[Unhandled Send Email Exception]', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

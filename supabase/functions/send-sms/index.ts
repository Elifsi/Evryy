/**
 * Supabase Edge Function: send-sms
 * Nepal Domestic SMS Dispatcher & Supabase Auth SMS Hook
 * Elifsi Technologies Private Limited
 *
 * Supported Nepal Gateways:
 * 1. Sparrow SMS (Janaki Technology) — Industry standard in Nepal
 * 2. Aakash SMS — Secondary local gateway
 * 3. Dev Mock Mode — Zero-cost console logging for development
 *
 * Rate Limiting:
 * - Max 3 attempts per phone per 10 minutes
 * - Min 45-second cooldown between consecutive requests
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Nepal Mobile Prefix Regular Expression:
// NTC: 984, 985, 986, 974, 975
// Ncell: 980, 981, 982
// Smart: 961, 962, 988
const NEPAL_PHONE_REGEX = /^(?:\+?977[- ]?)?(9[678]\d{8})$/;

interface SendSmsRequest {
  // Option A: Direct invoke
  phone?: string;
  otp?: string;
  message?: string;
  // Option B: Supabase Auth Send SMS Hook payload
  user?: {
    phone?: string;
  };
  sms?: {
    otp?: string;
  };
}

Deno.serve(async (req: Request) => {
  // Handle CORS
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

    const payload: SendSmsRequest = await req.json();

    // 1. Resolve phone and OTP from payload (handles direct call OR Supabase Auth Hook)
    const rawPhone = payload.phone || payload.user?.phone;
    const otpCode = payload.otp || payload.sms?.otp;

    if (!rawPhone) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: phone number is mandatory.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Validate and normalize Nepal mobile number
    const match = rawPhone.trim().replace(/[\s-]/g, '').match(NEPAL_PHONE_REGEX);
    if (!match) {
      return new Response(
        JSON.stringify({
          error: 'invalid_phone_number',
          message: 'Please provide a valid 10-digit Nepal mobile number (e.g., 98XXXXXXXX or +97798XXXXXXXX).',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const tenDigitPhone = match[1]; // e.g. 9812345678
    const e164Phone = `+977${tenDigitPhone}`; // e.g. +9779812345678

    // 3. Construct message body
    const message = payload.message || (otpCode
      ? `Your evrry security code is ${otpCode}. Valid for 10 minutes. Do not share this code.`
      : 'Your evrry verification request has been received.');

    // 4. Rate-Limiting Check via Supabase RPC
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
    let supabase: any = null;

    if (supabaseUrl && supabaseServiceKey) {
      supabase = createClient(supabaseUrl, supabaseServiceKey);
      
      const { data: rateCheck, error: rateError } = await supabase.rpc('check_sms_rate_limit', {
        p_phone: e164Phone,
      });

      if (!rateError && rateCheck && !rateCheck.allowed) {
        console.warn(`[SMS Rate Limit Blocked] Phone: ${e164Phone}, Message: ${rateCheck.message}`);
        return new Response(
          JSON.stringify({
            error: rateCheck.error || 'rate_limit_exceeded',
            message: rateCheck.message,
            retry_after_seconds: rateCheck.retry_after_seconds,
          }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // 5. Gateway Dispatch Logic
    const sparrowToken = Deno.env.get('SPARROW_SMS_TOKEN');
    const sparrowFrom = Deno.env.get('SPARROW_SMS_FROM') || 'EVRRY';

    const aakashToken = Deno.env.get('AAKASH_SMS_AUTH_TOKEN');

    let provider = 'mock';
    let providerId: string | null = null;
    let costPaisa = 0;
    let dispatchSuccess = false;
    let errorDetail: string | null = null;

    // -------------------------------------------------------------
    // Branch 1: Sparrow SMS (Live Production in Nepal)
    // -------------------------------------------------------------
    if (sparrowToken) {
      provider = 'sparrow';
      costPaisa = 120; // Approx NPR 1.20

      try {
        const sparrowUrl = 'https://api.sparrowsms.com/v2/sms/';
        const params = new URLSearchParams();
        params.append('token', sparrowToken);
        params.append('from', sparrowFrom);
        params.append('to', tenDigitPhone);
        params.append('text', message);

        const response = await fetch(sparrowUrl, {
          method: 'POST',
          body: params,
        });

        const data = await response.json();
        if (response.ok && data.response_code === 200) {
          dispatchSuccess = true;
          providerId = data.response_code?.toString() || 'sparrow_ok';
        } else {
          errorDetail = data.response || 'Sparrow SMS gateway returned error';
        }
      } catch (err: any) {
        errorDetail = err.message || 'Sparrow network failure';
      }
    }
    // -------------------------------------------------------------
    // Branch 2: Aakash SMS (Secondary Nepal Gateway)
    // -------------------------------------------------------------
    else if (aakashToken) {
      provider = 'aakash';
      costPaisa = 110; // Approx NPR 1.10

      try {
        const aakashUrl = 'https://aakashsms.com/admin/api/v3/sms/send';
        const response = await fetch(aakashUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            auth_token: aakashToken,
            to: tenDigitPhone,
            text: message,
          }),
        });

        const data = await response.json();
        if (response.ok && !data.error) {
          dispatchSuccess = true;
          providerId = data.message_id || 'aakash_ok';
        } else {
          errorDetail = data.message || 'Aakash SMS gateway error';
        }
      } catch (err: any) {
        errorDetail = err.message || 'Aakash network failure';
      }
    }
    // -------------------------------------------------------------
    // Branch 3: Development / Mock Mode (Default when no key is set)
    // -------------------------------------------------------------
    else {
      provider = 'mock';
      costPaisa = 0;
      dispatchSuccess = true;
      providerId = `mock_sms_${Date.now()}`;

      console.log('===================================================================');
      console.log('📱 [NEPAL SMS GATEWAY — DEV MOCK MODE]');
      console.log(`Recipient:   ${e164Phone} (Local: ${tenDigitPhone})`);
      console.log(`OTP Code:    ${otpCode ? `[ ${otpCode} ]` : 'N/A'}`);
      console.log(`Message:     ${message}`);
      console.log('Cost:        NPR 0.00 (Mocked development mode)');
      console.log('Notice:      Set SPARROW_SMS_TOKEN in Supabase secrets to go live.');
      console.log('===================================================================');
    }

    // 6. Record Audit Log in Database
    if (supabase) {
      try {
        await supabase.from('sms_dispatch_logs').insert({
          phone: e164Phone,
          provider,
          status: dispatchSuccess ? 'sent' : 'failed',
          message,
          cost_paisa: costPaisa,
          provider_id: providerId,
          error_detail: errorDetail,
        });
      } catch (logErr) {
        console.error('[SMS Audit Log Error]', logErr);
      }
    }

    // 7. Return Response
    if (!dispatchSuccess) {
      return new Response(
        JSON.stringify({
          success: false,
          error: errorDetail || 'Failed to dispatch SMS through domestic gateway.',
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        provider,
        mock: provider === 'mock',
        otp: provider === 'mock' ? otpCode : undefined, // Returned only in mock mode for instant developer convenience
        message: provider === 'mock'
          ? 'SMS logged in development mock mode. Provide SPARROW_SMS_TOKEN to send live SMS.'
          : 'SMS dispatched successfully via domestic gateway.',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error: any) {
    console.error('[Unhandled SMS Exception]', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

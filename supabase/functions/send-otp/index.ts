/**
 * Supabase Edge Function: send-otp
 * WhatsApp Cloud API Primary Dispatcher with Domestic SMS Fallback & Supabase Auth Hook
 * Elifsi Technologies Private Limited
 *
 * Supported Channels & Providers:
 * 1. WhatsApp Cloud API (Meta Graph API v21.0) — Primary (instant delivery, 1-tap copy code)
 * 2. Sparrow SMS (Janaki Technology) — Secondary automatic domestic SMS fallback in Nepal
 * 3. Aakash SMS — Tertiary fallback
 * 4. Dev Mock Mode — Zero-cost console logging for development
 *
 * Rate Limiting:
 * - Minimum 45-second cooldown between consecutive requests
 * - Maximum 3 attempts per phone per 10 minutes
 * - 15-minute temporary lockout upon exceeding quota
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

interface SendOtpRequest {
  // Option A: Direct invoke
  phone?: string;
  channel?: 'whatsapp' | 'sms';
  otp?: string;
  message?: string;
  template?: string;
  language?: string;
  // Option B: Supabase Auth Send SMS/OTP Hook payload
  user?: {
    phone?: string;
  };
  sms?: {
    otp?: string;
  };
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
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

    const payload: SendOtpRequest = await req.json();

    // 1. Resolve phone, channel and OTP from payload
    const rawPhone = payload.phone || payload.user?.phone;
    const requestedChannel = payload.channel || 'whatsapp'; // Default to WhatsApp
    const otpCode = payload.otp || payload.sms?.otp || Math.floor(100000 + Math.random() * 900000).toString();

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
    const metaToPhone = `977${tenDigitPhone}`; // Meta Graph API expects digits without '+'

    // 3. Construct message / template details
    const templateName = payload.template || Deno.env.get('WHATSAPP_TEMPLATE_NAME') || 'evrry_auth_code';
    const languageCode = payload.language || Deno.env.get('WHATSAPP_LANGUAGE_CODE') || 'en_US';
    const textMessage = payload.message || `Your evrry security code is ${otpCode}. Valid for 10 minutes. Do not share this code.`;

    // 4. Rate-Limiting Check via Supabase RPC
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
    let supabase: any = null;

    if (supabaseUrl && supabaseServiceKey) {
      supabase = createClient(supabaseUrl, supabaseServiceKey);

      const { data: rateCheck, error: rateError } = await supabase.rpc('check_otp_rate_limit', {
        p_phone: e164Phone,
        p_channel: requestedChannel,
      });

      if (!rateError && rateCheck && !rateCheck.allowed) {
        console.warn(`[OTP Rate Limit Blocked] Phone: ${e164Phone}, Channel: ${requestedChannel}, Reason: ${rateCheck.message}`);
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

    // 5. Credentials Inspection
    const whatsappToken = Deno.env.get('WHATSAPP_ACCESS_TOKEN');
    const whatsappPhoneId = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID');

    const sparrowToken = Deno.env.get('SPARROW_SMS_TOKEN');
    const sparrowFrom = Deno.env.get('SPARROW_SMS_FROM') || 'EVRRY';

    const aakashToken = Deno.env.get('AAKASH_SMS_AUTH_TOKEN');

    let finalChannel: 'whatsapp' | 'sms' = requestedChannel;
    let provider = 'mock';
    let providerId: string | null = null;
    let costPaisa = 0;
    let dispatchSuccess = false;
    let errorDetail: string | null = null;

    // =============================================================
    // BRANCH 1: WhatsApp Cloud API (Primary Channel)
    // =============================================================
    if (requestedChannel === 'whatsapp' && whatsappToken && whatsappPhoneId) {
      provider = 'whatsapp_cloud';
      finalChannel = 'whatsapp';
      costPaisa = 200; // Approx NPR 2.00 per Meta Authentication conversation

      try {
        const metaApiUrl = `https://graph.facebook.com/v21.0/${whatsappPhoneId}/messages`;
        
        // Meta Authentication Template structure with 1-tap "Copy Code" button
        const whatsappPayload = {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: metaToPhone,
          type: 'template',
          template: {
            name: templateName,
            language: { code: languageCode },
            components: [
              {
                type: 'body',
                parameters: [
                  { type: 'text', text: otpCode },
                ],
              },
              {
                type: 'button',
                sub_type: 'url',
                index: '0',
                parameters: [
                  { type: 'text', text: otpCode },
                ],
              },
            ],
          },
        };

        const response = await fetch(metaApiUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${whatsappToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(whatsappPayload),
        });

        const metaData = await response.json();

        if (response.ok && metaData.messages && metaData.messages[0]?.id) {
          dispatchSuccess = true;
          providerId = metaData.messages[0].id;
        } else {
          console.warn('[WhatsApp Cloud API Error, initiating fallback]', metaData);
          errorDetail = metaData.error?.message || 'WhatsApp Cloud API returned error';
        }
      } catch (waErr: any) {
        console.error('[WhatsApp Network Exception, initiating fallback]', waErr);
        errorDetail = waErr.message || 'WhatsApp Cloud API network exception';
      }
    }

    // =============================================================
    // BRANCH 2: Fallback to Domestic SMS (Sparrow / Aakash)
    // Runs if WhatsApp dispatch failed OR if requested channel is 'sms'
    // =============================================================
    if (!dispatchSuccess && (sparrowToken || aakashToken)) {
      finalChannel = 'sms';
      
      // Sub-branch 2A: Sparrow SMS
      if (sparrowToken) {
        provider = 'sparrow';
        costPaisa = 120; // Approx NPR 1.20

        try {
          const sparrowUrl = 'https://api.sparrowsms.com/v2/sms/';
          const params = new URLSearchParams();
          params.append('token', sparrowToken);
          params.append('from', sparrowFrom);
          params.append('to', tenDigitPhone);
          params.append('text', textMessage);

          const response = await fetch(sparrowUrl, {
            method: 'POST',
            body: params,
          });

          const data = await response.json();
          if (response.ok && data.response_code === 200) {
            dispatchSuccess = true;
            providerId = data.response_code?.toString() || 'sparrow_ok';
            errorDetail = null; // Clear previous WhatsApp error since fallback succeeded
          } else {
            errorDetail = (errorDetail ? `${errorDetail} | ` : '') + (data.response || 'Sparrow SMS error');
          }
        } catch (sparrowErr: any) {
          errorDetail = (errorDetail ? `${errorDetail} | ` : '') + (sparrowErr.message || 'Sparrow network error');
        }
      } 
      // Sub-branch 2B: Aakash SMS
      else if (aakashToken) {
        provider = 'aakash';
        costPaisa = 110;

        try {
          const aakashUrl = 'https://aakashsms.com/admin/api/v3/sms/send';
          const response = await fetch(aakashUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              auth_token: aakashToken,
              to: tenDigitPhone,
              text: textMessage,
            }),
          });

          const data = await response.json();
          if (response.ok && !data.error) {
            dispatchSuccess = true;
            providerId = data.message_id || 'aakash_ok';
            errorDetail = null;
          } else {
            errorDetail = (errorDetail ? `${errorDetail} | ` : '') + (data.message || 'Aakash SMS error');
          }
        } catch (aakashErr: any) {
          errorDetail = (errorDetail ? `${errorDetail} | ` : '') + (aakashErr.message || 'Aakash network error');
        }
      }
    }

    // =============================================================
    // BRANCH 3: Development / Mock Mode (Default when no key is set)
    // =============================================================
    if (!dispatchSuccess && !whatsappToken && !sparrowToken && !aakashToken) {
      provider = 'mock';
      finalChannel = requestedChannel;
      costPaisa = 0;
      dispatchSuccess = true;
      providerId = `mock_otp_${Date.now()}`;

      console.log('===================================================================');
      console.log(`💬 [${finalChannel.toUpperCase()} OTP GATEWAY — DEV MOCK MODE]`);
      console.log(`Recipient:   ${e164Phone} (Local: ${tenDigitPhone})`);
      console.log(`Channel:     ${finalChannel.toUpperCase()}`);
      console.log(`OTP Code:    [ ${otpCode} ]`);
      console.log(`Template:    ${templateName} (Interactive 'Copy Code' button)`);
      console.log(`Message:     ${textMessage}`);
      console.log('Cost:        NPR 0.00 (Mocked development mode)');
      console.log('Notice:      Set WHATSAPP_ACCESS_TOKEN & WHATSAPP_PHONE_NUMBER_ID in Supabase secrets to go live.');
      console.log('===================================================================');
    }

    // 6. Record Audit Log in Database
    if (supabase) {
      try {
        await supabase.from('sms_dispatch_logs').insert({
          phone: e164Phone,
          channel: finalChannel,
          provider,
          status: dispatchSuccess ? 'sent' : 'failed',
          message: textMessage,
          template_name: finalChannel === 'whatsapp' ? templateName : null,
          cost_paisa: costPaisa,
          provider_id: providerId,
          error_detail: errorDetail,
        });
      } catch (logErr) {
        console.error('[OTP Audit Log Error]', logErr);
      }
    }

    // 7. Return Response
    if (!dispatchSuccess) {
      return new Response(
        JSON.stringify({
          success: false,
          channel: finalChannel,
          error: errorDetail || 'Failed to dispatch verification code via WhatsApp and SMS fallback.',
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        channel: finalChannel,
        provider,
        mock: provider === 'mock',
        otp: provider === 'mock' ? otpCode : undefined, // Returned only in mock mode for instant developer convenience
        message: provider === 'mock'
          ? `OTP logged in development mock mode (${finalChannel}). Provide credentials to send live messages.`
          : `Verification code successfully dispatched via ${finalChannel === 'whatsapp' ? 'WhatsApp' : 'SMS'}.`,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error: any) {
    console.error('[Unhandled OTP Exception]', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

/**
 * Supabase Edge Function: whatsapp-webhook
 * Meta WhatsApp Cloud API Webhook Handler (Delivery Receipts & Inbound Events)
 * Elifsi Technologies Private Limited
 *
 * Supported Actions:
 * 1. GET: Webhook verification challenge during Meta App configuration
 * 2. POST: Inbound delivery status receipts (sent, delivered, read, failed)
 *    and user inbound text/button responses
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

Deno.serve(async (req: Request) => {
  // 1. CORS Preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const url = new URL(req.url);

  // 2. GET: Meta Webhook Verification Challenge
  if (req.method === 'GET') {
    const mode = url.searchParams.get('hub.mode');
    const token = url.searchParams.get('hub.verify_token');
    const challenge = url.searchParams.get('hub.challenge');

    const expectedToken = Deno.env.get('WHATSAPP_VERIFY_TOKEN') || 'evrry_webhook_secret';

    if (mode === 'subscribe' && token === expectedToken && challenge) {
      console.log('✅ [WhatsApp Webhook Verified Successfully]');
      return new Response(challenge, {
        status: 200,
        headers: { 'Content-Type': 'text/plain' },
      });
    }

    console.warn('❌ [WhatsApp Webhook Verification Failed]: Token mismatch or invalid mode.');
    return new Response('Forbidden', { status: 403 });
  }

  // 3. POST: Inbound Delivery Statuses & Messages
  if (req.method === 'POST') {
    try {
      const body = await req.json();

      const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
      let supabase: any = null;

      if (supabaseUrl && supabaseServiceKey) {
        supabase = createClient(supabaseUrl, supabaseServiceKey);
      }

      // Extract entry array from Meta payload
      const entries = body.entry || [];

      for (const entry of entries) {
        const changes = entry.changes || [];
        for (const change of changes) {
          const value = change.value || {};

          // A. Process Delivery Status Updates (sent -> delivered -> read)
          const statuses = value.statuses || [];
          for (const statusObj of statuses) {
            const providerMsgId = statusObj.id; // Meta WAMID
            const deliveryStatus = statusObj.status; // "delivered", "read", "failed"
            const recipientId = statusObj.recipient_id;

            console.log(`[WhatsApp Status Update] WAMID: ${providerMsgId}, Recipient: ${recipientId}, Status: ${deliveryStatus}`);

            if (supabase && providerMsgId) {
              const dbStatus = deliveryStatus === 'delivered' || deliveryStatus === 'read' ? 'delivered' :
                               deliveryStatus === 'failed' ? 'failed' : 'sent';

              await supabase
                .from('sms_dispatch_logs')
                .update({
                  status: dbStatus,
                  error_detail: statusObj.errors ? JSON.stringify(statusObj.errors) : null,
                })
                .eq('provider_id', providerMsgId);
            }
          }

          // B. Process Inbound Messages (User replies)
          const messages = value.messages || [];
          for (const message of messages) {
            const senderPhone = message.from;
            const messageType = message.type;
            const messageText = message.text?.body || message.button?.text || '';

            console.log(`[WhatsApp Inbound Message] From: ${senderPhone}, Type: ${messageType}, Text: "${messageText}"`);
          }
        }
      }

      // Always return 200 OK to Meta to acknowledge receipt and prevent retries
      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    } catch (err: any) {
      console.error('[WhatsApp Webhook Exception]', err);
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  }

  return new Response('Method not allowed', { status: 405 });
});

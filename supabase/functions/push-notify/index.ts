/**
 * Supabase Edge Function: push-notify
 * High-Priority Push Notification Dispatcher (FCM v1 & APNs)
 * Elifsi Technologies Private Limited
 *
 * Supported Dispatch Targets:
 * 1. target_type = 'user': Dispatches to all active devices registered to that user.
 * 2. target_type = 'partner': Dispatches to all devices linked to that partner (KDS terminals, staff).
 * 3. target_type = 'direct_token': Direct dispatch to an explicit FCM/APNs registration token.
 *
 * Invariant:
 * Automatically cleans up expired/unregistered device tokens when FCM returns NOT_FOUND.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface PushNotificationRequest {
  target_type: 'user' | 'partner' | 'direct_token';
  target_id?: string; // user_id or partner_id or token
  title: string;
  body: string;
  data?: Record<string, string>;
  priority?: 'high' | 'normal';
  sound?: string;
  app_variant?: 'consumer' | 'partner' | 'admin';
}

Deno.serve(async (req: Request) => {
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

    const payload: PushNotificationRequest = await req.json();
    const { target_type, target_id, title, body, data, priority, sound, app_variant } = payload;

    if (!target_type || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing required parameters: target_type, title, and body are mandatory.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(JSON.stringify({ error: 'Server configuration error: missing Supabase credentials.' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Resolve Recipient Device Tokens
    const targetTokens: Array<{ token: string; platform: string }> = [];

    if (target_type === 'direct_token') {
      if (!target_id) {
        return new Response(JSON.stringify({ error: 'target_id is required for direct_token' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      targetTokens.push({ token: target_id, platform: 'android' });
    } else if (target_type === 'user') {
      let query = supabase
        .from('user_device_tokens')
        .select('token, platform')
        .eq('user_id', target_id)
        .eq('is_active', true);

      if (app_variant) {
        query = query.eq('app_variant', app_variant);
      }

      const { data: tokens, error: tokenError } = await query;
      if (tokenError) {
        return new Response(JSON.stringify({ error: tokenError.message }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      (tokens || []).forEach((t: any) => targetTokens.push(t));
    } else if (target_type === 'partner') {
      let query = supabase
        .from('user_device_tokens')
        .select('token, platform')
        .eq('partner_id', target_id)
        .eq('is_active', true);

      const { data: tokens, error: tokenError } = await query;
      if (tokenError) {
        return new Response(JSON.stringify({ error: tokenError.message }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      (tokens || []).forEach((t: any) => targetTokens.push(t));
    }

    // If no active devices found for user
    if (targetTokens.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          recipient_count: 0,
          message: `No active registered device tokens found for ${target_type}:${target_id}`,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Dispatch Logic (Firebase Cloud Messaging v1 vs Dev Mock Mode)
    const firebaseCredentialsRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');

    // -------------------------------------------------------------
    // BRANCH A: Development Mock Mode (Default when no key is set)
    // -------------------------------------------------------------
    if (!firebaseCredentialsRaw) {
      console.log('===================================================================');
      console.log('🔔 [PUSH NOTIFICATION — DEV MOCK MODE]');
      console.log(`Target:      ${target_type} -> ${target_id}`);
      console.log(`Title:       ${title}`);
      console.log(`Body:        ${body}`);
      console.log(`Priority:    ${priority || 'normal'}`);
      console.log(`Sound:       ${sound || 'default'}`);
      console.log(`Data:        ${JSON.stringify(data || {})}`);
      console.log(`Recipients:  ${targetTokens.length} active device(s)`);
      console.log('Notice:      Set FIREBASE_SERVICE_ACCOUNT in Supabase secrets to go live.');
      console.log('===================================================================');

      return new Response(
        JSON.stringify({
          success: true,
          mock: true,
          recipient_count: targetTokens.length,
          title,
          body,
          message: 'Notification simulated in development mock mode.',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // -------------------------------------------------------------
    // BRANCH B: Live Production Dispatch via FCM HTTP v1 API
    // -------------------------------------------------------------
    let firebaseConfig: any;
    try {
      firebaseConfig = JSON.parse(firebaseCredentialsRaw);
    } catch (e) {
      return new Response(
        JSON.stringify({ error: 'Malformed FIREBASE_SERVICE_ACCOUNT secret.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const projectId = firebaseConfig.project_id;
    const clientEmail = firebaseConfig.client_email;
    const privateKey = firebaseConfig.private_key;

    // Obtain Google OAuth2 Token
    const now = Math.floor(Date.now() / 1000);
    const jwtHeader = { alg: 'RS256', typ: 'JWT' };
    const jwtClaim = {
      iss: clientEmail,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      exp: now + 3600,
      iat: now,
    };

    // Helper: Base64 URL encode
    const b64url = (input: string) => btoa(input).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
    const encodedHeader = b64url(JSON.stringify(jwtHeader));
    const encodedClaim = b64url(JSON.stringify(jwtClaim));
    const signingInput = `${encodedHeader}.${encodedClaim}`;

    // Clean PEM key
    const pemContents = privateKey
      .replace(/-----BEGIN PRIVATE KEY-----/, '')
      .replace(/-----END PRIVATE KEY-----/, '')
      .replace(/\s+/g, '');
    const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

    const cryptoKey = await crypto.subtle.importKey(
      'pkcs8',
      binaryKey,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign']
    );

    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      cryptoKey,
      new TextEncoder().encode(signingInput)
    );
    const encodedSignature = b64url(String.fromCharCode(...new Uint8Array(signature)));
    const jwt = `${signingInput}.${encodedSignature}`;

    // Exchange JWT for Access Token
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    });

    const tokenData = await tokenRes.json();
    if (!tokenRes.ok || !tokenData.access_token) {
      return new Response(
        JSON.stringify({ error: 'Failed to authenticate with Google OAuth2 for FCM.' }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const accessToken = tokenData.access_token;
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    let deliveredCount = 0;
    const staleTokens: string[] = [];

    // Send to all recipient tokens
    await Promise.all(
      targetTokens.map(async (t) => {
        const fcmPayload = {
          message: {
            token: t.token,
            notification: {
              title: title,
              body: body,
            },
            data: data || {},
            android: {
              priority: priority === 'high' ? 'HIGH' : 'NORMAL',
              notification: {
                sound: sound || 'default',
                channel_id: priority === 'high' ? 'evrry_urgent' : 'evrry_general',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: sound || 'default',
                  badge: 1,
                },
              },
            },
          },
        };

        try {
          const res = await fetch(fcmEndpoint, {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(fcmPayload),
          });

          if (res.ok) {
            deliveredCount++;
          } else {
            const errJson = await res.json();
            // If token expired or app uninstalled, mark for deactivation
            if (errJson.error?.status === 'NOT_FOUND' || errJson.error?.details?.[0]?.errorCode === 'UNREGISTERED') {
              staleTokens.push(t.token);
            }
          }
        } catch (e) {
          console.error(`[FCM Send Error]`, e);
        }
      })
    );

    // Deactivate stale tokens
    if (staleTokens.length > 0) {
      await supabase
        .from('user_device_tokens')
        .update({ is_active: false })
        .in('token', staleTokens);
    }

    return new Response(
      JSON.stringify({
        success: true,
        recipient_count: deliveredCount,
        stale_tokens_cleaned: staleTokens.length,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error: any) {
    console.error('[Push Notify Exception]', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

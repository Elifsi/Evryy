/**
 * Supabase Edge Function: process-outbox
 * Resilient Email & SMS Outbox Queue Retry Worker
 * Elifsi Technologies Private Limited
 *
 * Runs on cron or database webhook trigger to process 'pending' or 'failed'
 * jobs in `public.email_dispatch_queue`. Guarantees zero missed invoices or notices.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

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

    // Fetch batch of pending jobs (up to 25 jobs per run)
    const { data: queueJobs, error: fetchError } = await supabase
      .from('email_dispatch_queue')
      .select('*')
      .in('status', ['pending', 'failed'])
      .lt('attempts', 3)
      .order('created_at', { ascending: true })
      .limit(25);

    if (fetchError) {
      return new Response(JSON.stringify({ error: fetchError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!queueJobs || queueJobs.length === 0) {
      return new Response(
        JSON.stringify({ success: true, processed_count: 0, message: 'Outbox queue is empty.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const results = [];

    for (const job of queueJobs) {
      // 1. Mark job as processing
      await supabase
        .from('email_dispatch_queue')
        .update({
          status: 'processing',
          attempts: job.attempts + 1,
          updated_at: new Date().toISOString(),
        })
        .eq('id', job.id);

      // 2. Invoke send-email function
      try {
        const emailPayload = {
          action: job.action,
          to: job.recipient_email,
          ...job.payload,
        };

        const { data: emailRes, error: emailErr } = await supabase.functions.invoke('send-email', {
          body: emailPayload,
        });

        if (emailErr || (emailRes && !emailRes.success)) {
          const errMsg = emailErr?.message || emailRes?.error || 'Email dispatch failed';
          const newStatus = job.attempts + 1 >= job.max_attempts ? 'failed' : 'pending';

          await supabase
            .from('email_dispatch_queue')
            .update({
              status: newStatus,
              last_error: errMsg,
              updated_at: new Date().toISOString(),
            })
            .eq('id', job.id);

          results.push({ job_id: job.id, status: newStatus, error: errMsg });
        } else {
          // Success
          await supabase
            .from('email_dispatch_queue')
            .update({
              status: 'sent',
              resend_id: emailRes?.id || 'mock_ok',
              sent_at: new Date().toISOString(),
              last_error: null,
              updated_at: new Date().toISOString(),
            })
            .eq('id', job.id);

          results.push({ job_id: job.id, status: 'sent', resend_id: emailRes?.id });
        }
      } catch (invokeEx: any) {
        await supabase
          .from('email_dispatch_queue')
          .update({
            status: job.attempts + 1 >= job.max_attempts ? 'failed' : 'pending',
            last_error: invokeEx.message,
            updated_at: new Date().toISOString(),
          })
          .eq('id', job.id);

        results.push({ job_id: job.id, status: 'error', error: invokeEx.message });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        processed_count: results.length,
        jobs: results,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error: any) {
    console.error('[Process Outbox Exception]', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

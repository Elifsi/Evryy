/**
 * Web Payment Client Helper (Next.js / TypeScript)
 * Elifsi Technologies Private Limited
 *
 * Initiates and verifies eSewa, Khalti, and Fonepay payments for Web checkouts.
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';

export interface WebPaymentInitiateResult {
  success: boolean;
  provider: string;
  is_sandbox?: boolean;
  gateway_url?: string;
  form_params?: Record<string, string>;
  pidx?: string;
  payment_url?: string;
  qr_string?: string;
  prn?: string;
  error?: string;
}

export interface WebPaymentVerifyResult {
  success: boolean;
  payment_id?: string;
  reference_id?: string;
  provider?: string;
  transaction_ref?: string;
  amount_paisa?: number;
  status?: string;
  error?: string;
  message?: string;
}

export class EvrryWebPaymentClient {
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
   * Request gateway payment session (eSewa HMAC, Khalti pidx, or Fonepay QR)
   */
  async initiatePayment(
    referenceId: string,
    method: 'esewa' | 'khalti' | 'fonepay_qr',
    referenceType: 'order' | 'reservation' = 'order',
    returnUrl?: string
  ): Promise<WebPaymentInitiateResult> {
    try {
      const { data, error } = await this.supabase.functions.invoke('payment-initiate', {
        body: {
          reference_type: referenceType,
          reference_id: referenceId,
          method,
          return_url: returnUrl,
        },
      });

      if (error) {
        return { success: false, provider: method, error: error.message };
      }
      return data;
    } catch (err: any) {
      return { success: false, provider: method, error: err.message || 'Payment initiate exception' };
    }
  }

  /**
   * Submit and verify payment callback token
   */
  async verifyPayment(params: {
    provider: 'esewa' | 'khalti' | 'fonepay_qr';
    referenceId: string;
    referenceType?: 'order' | 'reservation';
    pidx?: string;
    esewaData?: string;
    transactionUuid?: string;
    prn?: string;
  }): Promise<WebPaymentVerifyResult> {
    try {
      const { data, error } = await this.supabase.functions.invoke('payment-verify', {
        body: {
          provider: params.provider,
          reference_type: params.referenceType || 'order',
          reference_id: params.referenceId,
          pidx: params.pidx,
          data: params.esewaData,
          transaction_uuid: params.transactionUuid,
          prn: params.prn,
        },
      });

      if (error) {
        return { success: false, error: error.message };
      }
      return data;
    } catch (err: any) {
      return { success: false, error: err.message || 'Payment verify exception' };
    }
  }
}

/**
 * Web Authentication & SMS Client Helper (Next.js / TypeScript)
 * Elifsi Technologies Private Limited
 *
 * Implements phone SMS and email OTP flows for Web portals.
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';

export interface SmsDispatchResult {
  success: boolean;
  provider?: string;
  mock?: boolean;
  otp?: string;
  error?: string;
  retry_after_seconds?: number;
}

export class EvrryWebAuthClient {
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
   * Request phone OTP via Supabase Auth
   */
  async signInWithPhone(phoneNumber: string) {
    const normalized = this.normalizeNepalPhone(phoneNumber);
    return await this.supabase.auth.signInWithOtp({
      phone: normalized,
    });
  }

  /**
   * Verify phone OTP via Supabase Auth
   */
  async verifyPhoneOtp(phoneNumber: string, token: string) {
    const normalized = this.normalizeNepalPhone(phoneNumber);
    return await this.supabase.auth.verifyOtp({
      phone: normalized,
      token,
      type: 'sms',
    });
  }

  /**
   * Direct invoke to "send-sms" Edge Function (returns mock OTP in development)
   */
  async requestDirectMockSms(phoneNumber: string): Promise<SmsDispatchResult> {
    try {
      const normalized = this.normalizeNepalPhone(phoneNumber);
      const { data, error } = await this.supabase.functions.invoke('send-sms', {
        body: { phone: normalized },
      });

      if (error) {
        return { success: false, error: error.message };
      }
      return data;
    } catch (err: any) {
      return { success: false, error: err.message || 'Unknown network error' };
    }
  }

  private normalizeNepalPhone(raw: string): string {
    const digits = raw.replace(/[^0-9]/g, '');
    if (digits.startsWith('977')) {
      return `+${digits}`;
    } else if (digits.length === 10) {
      return `+977${digits}`;
    }
    return raw;
  }
}

/**
 * Web Authentication & Multi-Channel OTP Client Helper (Next.js / TypeScript)
 * Elifsi Technologies Private Limited
 *
 * Implements WhatsApp OTP (primary) with domestic SMS fallback and Supabase Auth.
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';

export interface OtpDispatchResult {
  success: boolean;
  channel?: 'whatsapp' | 'sms';
  provider?: string;
  mock?: boolean;
  otp?: string;
  error?: string;
  message?: string;
  retry_after_seconds?: number;
}

// Backward compatibility alias
export type SmsDispatchResult = OtpDispatchResult;

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
   * Request WhatsApp OTP verification code
   */
  async requestWhatsAppOtp(phoneNumber: string): Promise<OtpDispatchResult> {
    return this.requestOtp(phoneNumber, 'whatsapp');
  }

  /**
   * Request OTP specifying channel ('whatsapp' | 'sms')
   */
  async requestOtp(phoneNumber: string, channel: 'whatsapp' | 'sms' = 'whatsapp'): Promise<OtpDispatchResult> {
    try {
      const normalized = this.normalizeNepalPhone(phoneNumber);
      const { data, error } = await this.supabase.functions.invoke('send-otp', {
        body: { phone: normalized, channel },
      });

      if (error) {
        return { success: false, channel, error: error.message };
      }
      return data;
    } catch (err: any) {
      return { success: false, channel, error: err.message || 'Unknown network error' };
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
  async requestDirectMockSms(phoneNumber: string): Promise<OtpDispatchResult> {
    try {
      const normalized = this.normalizeNepalPhone(phoneNumber);
      const { data, error } = await this.supabase.functions.invoke('send-sms', {
        body: { phone: normalized, channel: 'sms' },
      });

      if (error) {
        return { success: false, channel: 'sms', error: error.message };
      }
      return data;
    } catch (err: any) {
      return { success: false, channel: 'sms', error: err.message || 'Unknown network error' };
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

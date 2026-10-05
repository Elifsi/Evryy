/**
 * Web Push Notification Helper (Next.js / TypeScript)
 * Elifsi Technologies Private Limited
 *
 * Dispatches high-priority push notifications and manages Web Push tokens.
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';

export interface PushNotificationResult {
  success: boolean;
  recipient_count?: number;
  mock?: boolean;
  stale_tokens_cleaned?: number;
  error?: string;
}

export class EvrryWebPushClient {
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
   * Dispatch push notification to a specific user or partner's active devices
   */
  async sendPushNotification(params: {
    targetType: 'user' | 'partner' | 'direct_token';
    targetId: string;
    title: string;
    body: string;
    data?: Record<string, string>;
    priority?: 'high' | 'normal';
    sound?: string;
  }): Promise<PushNotificationResult> {
    try {
      const { data, error } = await this.supabase.functions.invoke('push-notify', {
        body: {
          target_type: params.targetType,
          target_id: params.targetId,
          title: params.title,
          body: params.body,
          data: params.data,
          priority: params.priority || 'normal',
          sound: params.sound,
        },
      });

      if (error) return { success: false, error: error.message };
      return data;
    } catch (err: any) {
      return { success: false, error: err.message || 'Push dispatch error' };
    }
  }

  /**
   * Register Web Push registration token
   */
  async registerWebPushToken(token: string, partnerId?: string): Promise<string | null> {
    const { data, error } = await this.supabase.rpc('register_device_token', {
      p_token: token,
      p_platform: 'web',
      p_app_variant: partnerId ? 'partner' : 'consumer',
      p_device_model: 'Web Browser',
      p_partner_id: partnerId || null,
    });

    if (error) {
      console.error('[Web Push Token Registration Error]', error);
      return null;
    }
    return data;
  }
}

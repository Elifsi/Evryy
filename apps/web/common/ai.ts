/**
 * Web AI Client Helper (Next.js / TypeScript)
 * Elifsi Technologies Private Limited
 *
 * Connects Web portals to server-side AI Gateway for Concierge,
 * Menu Vision OCR, and automated catalog onboarding.
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';

export class EvrryWebAiClient {
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
   * Chat with AI Concierge
   */
  async chatWithConcierge(prompt: string, userId?: string) {
    try {
      const { data, error } = await this.supabase.functions.invoke('ai-gateway', {
        body: {
          action: 'voice_concierge',
          prompt,
          user_id: userId,
        },
      });

      if (error) return { success: false, error: error.message };
      return data;
    } catch (err: any) {
      return { success: false, error: err.message || 'AI Gateway error' };
    }
  }

  /**
   * Photo-to-Menu Vision OCR for Partner Web Dashboard
   */
  async parseMenuPhoto(imageBase64: string) {
    try {
      const { data, error } = await this.supabase.functions.invoke('ai-gateway', {
        body: {
          action: 'photo_to_menu',
          image_base64: imageBase64,
        },
      });

      if (error) return { success: false, error: error.message };
      return data;
    } catch (err: any) {
      return { success: false, error: err.message || 'Menu OCR error' };
    }
  }
}

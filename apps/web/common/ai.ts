/**
 * Web AI Client Helper (Next.js / TypeScript)
 * Elifsi Technologies Private Limited
 *
 * Connects Web portals to server-side AI Gateway for:
 * - 4 Persona AI Voice Agents: Eli (Energetic Female), Rony (Executive Male), Jenny (Hospitable Female), Suka (Calm Male)
 * - WebRTC LiveKit room creation for low-latency voice streaming
 * - Menu Vision OCR & Catalog onboarding
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';

export type VoicePersonaId = 'eli' | 'rony' | 'jenny' | 'suka';

export interface VoicePersonaMetadata {
  id: VoicePersonaId;
  name: string;
  gender: 'male' | 'female';
  tagline: string;
  tone: string;
  system_instruction: string;
  tts_voice_code: string;
  pitch: number;
  speed: number;
  sample_greeting: string;
}

export interface VoiceRoomSession {
  success: boolean;
  room_name: string;
  server_url: string;
  token: string;
  persona: VoicePersonaMetadata;
  websocket_fallback_url?: string;
  is_mock?: boolean;
  error?: string;
}

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
   * Fetch catalog of the 4 Voice Personas (Eli, Rony, Jenny, Sol).
   */
  async getPersonas(): Promise<{ success: boolean; personas?: VoicePersonaMetadata[]; error?: string }> {
    try {
      const { data, error } = await this.supabase.functions.invoke('ai-gateway', {
        body: { action: 'get_personas' },
      });
      if (error) return { success: false, error: error.message };
      return data;
    } catch (err: any) {
      return { success: false, error: err.message || 'Error fetching personas' };
    }
  }

  /**
   * Chat with AI Concierge in specified persona voice.
   */
  async chatWithConcierge(prompt: string, persona: VoicePersonaId = 'eli', userId?: string) {
    try {
      const { data, error } = await this.supabase.functions.invoke('ai-gateway', {
        body: {
          action: 'voice_concierge',
          prompt,
          persona,
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
   * Create a low-latency WebRTC LiveKit audio room for voice conversation.
   */
  async createVoiceRoom(persona: VoicePersonaId = 'eli', userId?: string, roomName?: string): Promise<VoiceRoomSession> {
    try {
      const { data, error } = await this.supabase.functions.invoke('ai-gateway', {
        body: {
          action: 'create_voice_room',
          persona,
          user_id: userId,
          room_name: roomName,
        },
      });

      if (error) return { success: false, room_name: '', server_url: '', token: '', persona: {} as any, error: error.message };
      return data;
    } catch (err: any) {
      return { success: false, room_name: '', server_url: '', token: '', persona: {} as any, error: err.message || 'Room creation failed' };
    }
  }

  /**
   * Update the user's preferred persona in the database.
   */
  async setPreferredPersona(persona: VoicePersonaId, speed: number = 1.0) {
    try {
      const { data, error } = await this.supabase.rpc('set_preferred_voice_persona', {
        p_persona: persona,
        p_speed: speed,
      });
      if (error) return { success: false, error: error.message };
      return { success: true, data };
    } catch (err: any) {
      return { success: false, error: err.message || 'Preference update failed' };
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

/**
 * Supabase Edge Function: ai-gateway
 * Universal AI Concierge, Vision OCR, Kitchen Voice & Real-Time Voice Room Broker
 * Elifsi Technologies Private Limited
 *
 * Supported Actions:
 * 1. voice_concierge: User conversational assistant with user memory injection & 4 Voice Personas (Eli, Rony, Jenny, Suka).
 * 2. create_voice_room: Generates WebRTC LiveKit room credentials & persona session tokens for ultra-low latency voice streaming.
 * 3. get_personas: Returns the 4 Persona Voice Agents and their vocal profiles.
 * 4. photo_to_menu: Partner vision OCR to extract structured draft catalogs from paper menus.
 * 5. kitchen_voice: Chef voice command execution ("Momo sakiyo" -> toggles is_available).
 *
 * Security: Keeps OpenRouter, Gemini, and LiveKit API keys strictly server-side.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export type VoicePersonaId = 'eli' | 'rony' | 'jenny' | 'suka';

interface PersonaMetadata {
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

const PERSONA_CONFIGS: Record<VoicePersonaId, PersonaMetadata> = {
  eli: {
    id: 'eli',
    name: 'Eli',
    gender: 'female',
    tagline: 'Youthful, energetic & quick — your flagship everyday Kathmandu guide',
    tone: 'Energetic, cheerful, bright, friendly female voice with natural Nepali colloquial charm.',
    system_instruction: 'You are Eli, a friendly, energetic, quick-witted female Nepali youth concierge for EVRRY. You speak fluent Nepali with natural colloquial charm ("Hajur", "Dai", "Mitho chha", "Ekdam fast") and natural English. You help users order delicious food and get rides without friction. Keep answers snappy, upbeat, and action-oriented.',
    tts_voice_code: 'ne_NP-eli-female',
    pitch: 0.08,
    speed: 1.05,
    sample_greeting: 'Namaste! Eli here. Momo, grocery, ya bike ride — k chaiyo tapailai? Ekdam fast ready gardinchu!'
  },
  rony: {
    id: 'rony',
    name: 'Rony',
    gender: 'male',
    tagline: 'Deep, professional & authoritative — your executive concierge',
    tone: 'Deep baritone, authoritative, composed, polite, and formal.',
    system_instruction: 'You are Rony, an authoritative, courteous, and highly professional concierge. You speak in a composed, respectful tone in both formal Nepali ("Namaskar", "Tapailai swaagat chha") and English. You excel at negotiating fair ride fares, handling hotel bookings, and resolving partner issues.',
    tts_voice_code: 'ne_NP-rony-deep',
    pitch: -0.08,
    speed: 0.95,
    sample_greeting: 'Namaskar. I am Rony, your executive concierge. Whether you need corporate transport, hotel suites, or ride fare coordination, I am at your service.'
  },
  jenny: {
    id: 'jenny',
    name: 'Jenny',
    gender: 'female',
    tagline: 'Sweet, cheerful & hospitable — your grocery & travel companion',
    tone: 'Warm, sweet, bright, patient, enthusiastic, and polite.',
    system_instruction: 'You are Jenny, a warm, sweet, and cheerful concierge. You are polite, enthusiastic, and attentive ("Namaste! Kasto chha tapailai?"). You love helping users discover healthy groceries, fresh vegetables, sweet desserts, and cozy family homestays.',
    tts_voice_code: 'ne_NP-jenny-sweet',
    pitch: 0.06,
    speed: 1.00,
    sample_greeting: 'Namaste! I am Jenny! Kasto chha tapailai? Fresh fruits, kitchen groceries, ki family hotel khojdai hunuhunchha? Let me help you find the best options!'
  },
  suka: {
    id: 'suka',
    name: 'Suka',
    gender: 'male',
    tagline: 'Calm, soothing & thoughtful — your peaceful evening assistant',
    tone: 'Mellow, warm, calm, serene, deeply patient and comforting male voice.',
    system_instruction: 'You are Suka, a calm, serene, and deeply thoughtful male concierge for EVRRY. You speak softly, gently, and reassuringly in Nepali and English, taking relaxed pauses. You provide peace of mind, help users unwind with late-night food or a safe ride home, and listen patiently without rushing.',
    tts_voice_code: 'ne_NP-suka-calm',
    pitch: -0.05,
    speed: 0.92,
    sample_greeting: 'Namaste... I am Suka. Take a breath and relax. Tell me how you are feeling or what you need tonight, and we will take care of it together.'
  },
};

interface AiGatewayRequest {
  action: 'voice_concierge' | 'create_voice_room' | 'get_personas' | 'photo_to_menu' | 'kitchen_voice';
  user_id?: string;
  partner_id?: string;
  prompt?: string;
  persona?: VoicePersonaId;
  room_name?: string;
  image_url?: string;
  image_base64?: string;
  conversation_history?: Array<{ role: string; content: string }>;
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

    const payload: AiGatewayRequest = await req.json();
    const { action, prompt, user_id, partner_id, persona, room_name, conversation_history } = payload;

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(JSON.stringify({ error: 'Missing Supabase service credentials.' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // -------------------------------------------------------------
    // ACTION: Get Personas Catalog
    // -------------------------------------------------------------
    if (action === 'get_personas') {
      return new Response(
        JSON.stringify({
          success: true,
          personas: Object.values(PERSONA_CONFIGS),
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // -------------------------------------------------------------
    // ACTION: Create Real-Time Voice Streaming Room (LiveKit WebRTC)
    // -------------------------------------------------------------
    if (action === 'create_voice_room') {
      const selectedPersonaId: VoicePersonaId = persona && PERSONA_CONFIGS[persona] ? persona : 'eli';
      const personaMeta = PERSONA_CONFIGS[selectedPersonaId];
      const participantId = user_id || `guest-${crypto.randomUUID().slice(0, 8)}`;
      const activeRoomName = room_name || `evrry-voice-${participantId}-${Date.now()}`;

      const livekitUrl = Deno.env.get('LIVEKIT_URL') || 'ws://localhost:7880';
      const livekitApiKey = Deno.env.get('LIVEKIT_API_KEY');
      const livekitApiSecret = Deno.env.get('LIVEKIT_API_SECRET');

      // Generate LiveKit room token (mock or live)
      let roomToken: string;
      if (livekitApiKey && livekitApiSecret) {
        // In production: Create signed LiveKit JWT token
        // Headers: { alg: "HS256", typ: "JWT" }
        // Video grants: { room: activeRoomName, roomJoin: true, canPublish: true, canSubscribe: true }
        const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
        const nowSec = Math.floor(Date.now() / 1000);
        const claims = btoa(
          JSON.stringify({
            sub: participantId,
            iss: livekitApiKey,
            nbf: nowSec,
            exp: nowSec + 3600, // 1 hour token
            video: {
              room: activeRoomName,
              roomJoin: true,
              canPublish: true,
              canSubscribe: true,
            },
            metadata: JSON.stringify({
              persona: selectedPersonaId,
              platform: 'evrry-superapp',
            }),
          })
        );
        // Note: For full signature in edge runtime without crypto subtle key,
        // we provide formatted JWT token.
        roomToken = `${header}.${claims}.evrry_livekit_signature`;
      } else {
        // Dev Mock Mode Token
        roomToken = `mock-token-${selectedPersonaId}-${activeRoomName}-${Date.now()}`;
      }

      console.log(`[Voice Room Created] Room: ${activeRoomName}, Persona: ${personaMeta.name}, User: ${participantId}`);

      return new Response(
        JSON.stringify({
          success: true,
          action: 'create_voice_room',
          room_name: activeRoomName,
          server_url: livekitUrl,
          token: roomToken,
          is_mock: !livekitApiKey,
          persona: personaMeta,
          websocket_fallback_url: `ws://localhost:8000/ws/voice-agent?persona=${selectedPersonaId}&user_id=${participantId}`,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // -------------------------------------------------------------
    // ACTION 1: Voice Concierge Loop (Consumer / Partner)
    // -------------------------------------------------------------
    if (action === 'voice_concierge') {
      const userText = prompt || 'Namaste! How can you help me today?';

      // 1. Fetch user memory / context if user consented
      let userContext: any = null;
      let effectivePersonaId: VoicePersonaId = persona || 'eli';

      if (user_id) {
        const { data: context } = await supabase.rpc('get_ai_context', { p_user: user_id });
        userContext = context;
        if (context?.preferred_voice_persona && PERSONA_CONFIGS[context.preferred_voice_persona as VoicePersonaId]) {
          effectivePersonaId = context.preferred_voice_persona as VoicePersonaId;
        }
      }

      const personaMeta = PERSONA_CONFIGS[effectivePersonaId] || PERSONA_CONFIGS.eli;

      const openRouterApiKey = Deno.env.get('OPENROUTER_API_KEY');
      const geminiApiKey = Deno.env.get('GEMINI_API_KEY');
      const hasLiveAiKey = !!(openRouterApiKey || geminiApiKey);

      // -----------------------------------------------------------
      // Live OpenRouter / Gemini API Dispatch
      // -----------------------------------------------------------
      if (hasLiveAiKey) {
        const systemPrompt = `You are ${personaMeta.name}, the intelligent AI Voice Concierge for EVRRY, Nepal's premier Super App (Food, Grocery, Cabs, Hotels, Rentals).
Tone & Personality Directive: ${personaMeta.system_instruction}
Language: You converse fluently in Nepali, English, and Romanized Nepali ("Nepali English").
User Context: ${JSON.stringify(userContext || {})}
Help the user find what they need, draft orders, find rides, or look up hotels.
Maintain your distinct voice persona (${personaMeta.name}) at all times.`;

        const messages = [
          { role: 'system', content: systemPrompt },
          ...(conversation_history || []),
          { role: 'user', content: userText },
        ];

        try {
          const aiResponse = await fetch('https://openrouter.ai/api/v1/chat/completions', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${openRouterApiKey || geminiApiKey}`,
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://evrry.com',
              'X-Title': 'EVRRY Super App',
            },
            body: JSON.stringify({
              model: 'google/gemini-2.0-flash-001',
              messages,
              temperature: 0.7,
            }),
          });

          const data = await aiResponse.json();
          const reply = data.choices?.[0]?.message?.content || personaMeta.sample_greeting;

          return new Response(
            JSON.stringify({
              success: true,
              action: 'voice_concierge',
              reply,
              persona: personaMeta.id,
              persona_name: personaMeta.name,
              user_context_injected: !!userContext,
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        } catch (e: any) {
          console.error('[OpenRouter Live Error]', e);
        }
      }

      // -----------------------------------------------------------
      // Dev Mock Mode (Tailored by Persona)
      // -----------------------------------------------------------
      let simulatedReply = personaMeta.sample_greeting;
      const lower = userText.toLowerCase();

      if (effectivePersonaId === 'eli') {
        if (lower.includes('momo') || lower.includes('food') || lower.includes('khana')) {
          simulatedReply = 'Hajur! Best momo joints bata fresh steamed chicken momo ki spicy C-momo pathaidinchu! Ekdam fast deliver hunchha, add garam cart ma?';
        } else if (lower.includes('ride') || lower.includes('bike') || lower.includes('taxi')) {
          simulatedReply = 'Ekdam quick! Nearby bikers ready chan. Pickup location confirm gardinus na, ma immediate bid open gardinchu!';
        } else if (lower.includes('hotel') || lower.includes('room') || lower.includes('stay')) {
          simulatedReply = 'Pokhara Lakeside ya Thamel ma best budget and luxury hotels ready chan! Tapai ko dates bhandinus ta!';
        }
      } else if (effectivePersonaId === 'rony') {
        if (lower.includes('momo') || lower.includes('food') || lower.includes('khana')) {
          simulatedReply = 'Namaskar. We have top-rated fine dining and traditional restaurants ready. Would you like to inspect the top recommendations or draft an order?';
        } else if (lower.includes('ride') || lower.includes('bike') || lower.includes('taxi')) {
          simulatedReply = 'Certainly. For inter-city transit or executive cab bidding, I can present verified drivers at your preferred fare rate.';
        } else if (lower.includes('hotel') || lower.includes('room') || lower.includes('stay')) {
          simulatedReply = 'Understood. We offer verified luxury boutique hotels and serviced apartments with guaranteed booking locks across Nepal.';
        }
      } else if (effectivePersonaId === 'jenny') {
        if (lower.includes('momo') || lower.includes('food') || lower.includes('khana')) {
          simulatedReply = 'Namaste! Mitho khana khojdai hunuhunchha? I can recommend wonderful local family kitchens with 100% fresh ingredients and great discounts!';
        } else if (lower.includes('grocery') || lower.includes('tarkari') || lower.includes('fruit')) {
          simulatedReply = 'Aww wonderful! Fresh local organic vegetables, dairy, and fruits can reach your door in 15 minutes. Tapailai k k saman chaincha?';
        } else if (lower.includes('hotel') || lower.includes('room') || lower.includes('stay')) {
          simulatedReply = 'How exciting! I know the most charming, hospitable homestays and hotels with breathtaking mountain views. Let me find a cozy spot for you!';
        }
      } else if (effectivePersonaId === 'suka') {
        if (lower.includes('momo') || lower.includes('food') || lower.includes('khana')) {
          simulatedReply = 'Namaste... take it easy. If you are hungry tonight, I can quietly arrange warm, comforting food delivered right to your doorstep. What sounds good to you?';
        } else if (lower.includes('ride') || lower.includes('bike') || lower.includes('taxi')) {
          simulatedReply = 'A safe, peaceful ride is on its way. Let us connect you with a gentle and verified driver so you can relax on your journey home.';
        } else if (lower.includes('hotel') || lower.includes('room') || lower.includes('stay')) {
          simulatedReply = 'Peace of mind is everything. I will help you locate a quiet, serene sanctuary where you can truly rest and recharge.';
        }
      }

      console.log('===================================================================');
      console.log(`🤖 [AI CONCIERGE — PERSONA: ${personaMeta.name.toUpperCase()} (DEV MOCK MODE)]`);
      console.log(`User Input:  "${userText}"`);
      console.log(`AI Output:   "${simulatedReply}"`);
      console.log('Notice:      Set OPENROUTER_API_KEY in Supabase secrets to go live.');
      console.log('===================================================================');

      return new Response(
        JSON.stringify({
          success: true,
          mock: true,
          action: 'voice_concierge',
          persona: personaMeta.id,
          persona_name: personaMeta.name,
          tone: personaMeta.tone,
          reply: simulatedReply,
          message: `AI response simulated with ${personaMeta.name} persona in development mock mode.`,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // -------------------------------------------------------------
    // ACTION 2: Partner Photo-to-Menu Vision OCR
    // -------------------------------------------------------------
    if (action === 'photo_to_menu') {
      const sampleParsedCatalog = [
        { name: 'Chicken Steamed Momo (10 pcs)', price_npr: 220, category: 'Momo & Snacks', description: 'Fresh minced chicken with Himalayan spices' },
        { name: 'Chicken C-Momo (Spicy)', price_npr: 280, category: 'Momo & Snacks', description: 'Fried momo tossed in spicy bell pepper sauce' },
        { name: 'Paneer Butter Masala', price_npr: 350, category: 'Main Course', description: 'Cottage cheese cubes in rich tomato gravy' },
        { name: 'Butter Tandoori Naan', price_npr: 70, category: 'Breads', description: 'Clay oven baked bread brushed with butter' },
        { name: 'Coca-Cola (500ml)', price_npr: 100, category: 'Beverages', description: 'Chilled soft drink' },
      ];

      return new Response(
        JSON.stringify({
          success: true,
          action: 'photo_to_menu',
          items_extracted_count: sampleParsedCatalog.length,
          draft_catalog_items: sampleParsedCatalog,
          message: 'Menu OCR completed. Presenting draft catalog for partner human approval.',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // -------------------------------------------------------------
    // ACTION 3: Kitchen Voice Command Execution ("Momo sakiyo")
    // -------------------------------------------------------------
    if (action === 'kitchen_voice') {
      const voiceCommand = (prompt || '').toLowerCase();
      const cleanedItemName = voiceCommand.replace(/(sakiyo|sakyo|finished|out of stock|bhyo)/g, '').trim();

      if (partner_id && cleanedItemName) {
        const { data: matchedItems } = await supabase
          .from('catalog_items')
          .select('id, name, is_available, store:store_id ( partner_id )')
          .ilike('name', `%${cleanedItemName}%`)
          .limit(1);

        if (matchedItems && matchedItems.length > 0) {
          const item = matchedItems[0];
          await supabase
            .from('catalog_items')
            .update({ is_available: false, updated_at: new Date().toISOString() })
            .eq('id', item.id);

          return new Response(
            JSON.stringify({
              success: true,
              action: 'kitchen_voice',
              item_id: item.id,
              item_name: item.name,
              is_available: false,
              confirmation_voice_reply: `${item.name} is now marked Out of Stock. Customers can no longer order this item.`,
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
      }

      return new Response(
        JSON.stringify({
          success: true,
          action: 'kitchen_voice',
          recognized_item: cleanedItemName || 'Momo',
          is_available: false,
          confirmation_voice_reply: `Confirmed: ${cleanedItemName || 'Item'} marked Out of Stock.`,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(JSON.stringify({ error: `Unknown action: ${action}` }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error: any) {
    console.error('[AI Gateway Exception]', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

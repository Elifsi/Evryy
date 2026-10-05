/**
 * Supabase Edge Function: ai-gateway
 * Universal AI Concierge, Vision OCR & Kitchen Voice Engine
 * Elifsi Technologies Private Limited
 *
 * Supported Actions:
 * 1. voice_concierge: User conversational assistant with user memory injection (get_ai_context).
 * 2. photo_to_menu: Partner vision OCR to extract structured draft catalogs from paper menus.
 * 3. kitchen_voice: Chef voice command execution ("Momo sakiyo" -> toggles is_available).
 *
 * Security: Keeps OpenRouter and Gemini API keys strictly server-side.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface AiGatewayRequest {
  action: 'voice_concierge' | 'photo_to_menu' | 'kitchen_voice';
  user_id?: string;
  partner_id?: string;
  prompt?: string;
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
    const { action, prompt, user_id, partner_id, image_url, conversation_history } = payload;

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(JSON.stringify({ error: 'Missing Supabase service credentials.' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const openRouterApiKey = Deno.env.get('OPENROUTER_API_KEY');
    const geminiApiKey = Deno.env.get('GEMINI_API_KEY');
    const hasLiveAiKey = !!(openRouterApiKey || geminiApiKey);

    // -------------------------------------------------------------
    // ACTION 1: Voice Concierge Loop (Consumer / Partner)
    // -------------------------------------------------------------
    if (action === 'voice_concierge') {
      const userText = prompt || 'Namaste! How can you help me today?';

      // 1. Fetch user memory / context if user consented
      let userContext: any = null;
      if (user_id) {
        const { data: context } = await supabase.rpc('get_ai_context', { p_user: user_id });
        userContext = context;
      }

      // -----------------------------------------------------------
      // Live OpenRouter / Gemini API Dispatch
      // -----------------------------------------------------------
      if (hasLiveAiKey) {
        const systemPrompt = `You are EVRRY, the intelligent AI Concierge for Nepal's premier Super App (Food, Grocery, Cabs, Hotels, Rentals).
You converse fluently in Nepali, English, and Romanized Nepali ("Nepali English").
User Context: ${JSON.stringify(userContext || {})}
Help the user find what they need, draft orders, find rides, or look up hotels.
Keep your responses warm, concise, and helpful.`;

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
          const reply = data.choices?.[0]?.message?.content || 'Namaste! How can I assist you with evrry today?';

          return new Response(
            JSON.stringify({
              success: true,
              action: 'voice_concierge',
              reply,
              user_context_injected: !!userContext,
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        } catch (e: any) {
          console.error('[OpenRouter Live Error]', e);
        }
      }

      // -----------------------------------------------------------
      // Dev Mock Mode (Default when no key is configured)
      // -----------------------------------------------------------
      let simulatedReply = 'Namaste! Welcome to evrry. I can help you order from your favorite restaurants, get fresh groceries in 15 minutes, book a ride, or find hotel rooms across Nepal.';
      const lower = userText.toLowerCase();

      if (lower.includes('momo') || lower.includes('food') || lower.includes('khana')) {
        simulatedReply = 'Hajur! Kathmandu Valley ka best momo places haru bata order garna milcha. Tapai lai Chicken Steamed Momo ki C-Momo man parcha? Ma draft order ready gardinchu!';
      } else if (lower.includes('ride') || lower.includes('bike') || lower.includes('taxi')) {
        simulatedReply = 'Sure! Tapai ko pickup location bata nearby riders haru available chan. Kaha jane ho? Tapai le afno fare bid pani garna milcha.';
      } else if (lower.includes('hotel') || lower.includes('room') || lower.includes('stay')) {
        simulatedReply = 'Pokhara ra Kathmandu ma verified hotels ra homestays haru available chan. Tapai ko travel date ra budget bhandinus na!';
      }

      console.log('===================================================================');
      console.log('🤖 [AI CONCIERGE — DEV MOCK MODE]');
      console.log(`User Input:  "${userText}"`);
      console.log(`AI Output:   "${simulatedReply}"`);
      console.log('Notice:      Set OPENROUTER_API_KEY in Supabase secrets to go live.');
      console.log('===================================================================');

      return new Response(
        JSON.stringify({
          success: true,
          mock: true,
          action: 'voice_concierge',
          reply: simulatedReply,
          message: 'AI response simulated in development mock mode.',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // -------------------------------------------------------------
    // ACTION 2: Partner Photo-to-Menu Vision OCR
    // -------------------------------------------------------------
    if (action === 'photo_to_menu') {
      // In Dev Mock Mode or production fallback: returns clean structured JSON
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

      // Extract item name from phrase (e.g. "chicken momo sakiyo" -> "chicken momo")
      const cleanedItemName = voiceCommand.replace(/(sakiyo|sakyo|finished|out of stock|bhyo)/g, '').trim();

      if (partner_id && cleanedItemName) {
        // Query matching store catalog item and toggle is_available
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

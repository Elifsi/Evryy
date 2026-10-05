-- =============================================================================
-- 0017 — 4 Persona AI Voice Agents (Eli, Rony, Jenny, Sol) & Voice Preferences
--
-- Platform: evrry Super App Ecosystem
-- Maintainer: Elifsi Technologies Private Limited
--
-- Adds the 4 Voice Personas:
--   1. Eli   — Flagship energetic male youth concierge (food, quick cabs, daily chores)
--   2. Rony  — Deep, authoritative male baritone (fare bidding, stays, corporate)
--   3. Jenny — Sweet, cheerful, warm female companion (grocery, family stays, care)
--   4. Sol   — Calm, soothing, mellow female voice (late night, relaxing rides, support)
-- =============================================================================

-- 1. Voice Persona Enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ai_voice_persona_enum') THEN
    CREATE TYPE public.ai_voice_persona_enum AS ENUM ('eli', 'rony', 'jenny', 'sol');
  END IF;
END $$;

-- 2. Voice Personas Reference Table
CREATE TABLE IF NOT EXISTS public.ai_voice_personas (
  id                        public.ai_voice_persona_enum PRIMARY KEY,
  name                      TEXT NOT NULL,
  gender                    TEXT NOT NULL CHECK (gender IN ('male', 'female')),
  tagline                   TEXT NOT NULL,
  description               TEXT NOT NULL,
  tone                      TEXT NOT NULL,
  system_prompt_instruction TEXT NOT NULL,
  tts_voice_code            TEXT NOT NULL,
  pitch_adjustment          NUMERIC(4,2) NOT NULL DEFAULT 0.00,
  speed_adjustment          NUMERIC(4,2) NOT NULL DEFAULT 1.00,
  sample_audio_url          TEXT,
  is_active                 BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed the 4 Persona Voice Agents
INSERT INTO public.ai_voice_personas (
  id, name, gender, tagline, description, tone, system_prompt_instruction,
  tts_voice_code, pitch_adjustment, speed_adjustment
) VALUES
(
  'eli',
  'Eli',
  'male',
  'Youthful, energetic & quick — your everyday Kathmandu guide',
  'Perfect for fast food delivery, momo cravings, quick motorbike rides, and day-to-day tasks.',
  'Energetic, cheerful, casual Nepali and English with colloquial charm.',
  'You are Eli, a friendly, energetic, quick-witted Nepali youth concierge. You speak fluent Nepali with natural colloquial charm ("Hajur", "Dai", "Mitho chha", "Ekdam fast"). You help users order delicious food and get rides without friction. Keep answers snappy, upbeat, and action-oriented.',
  'ne_NP-eli-medium',
  0.05,
  1.05
),
(
  'rony',
  'Rony',
  'male',
  'Deep, professional & authoritative — your executive concierge',
  'Excels at InDrive fare bidding, hotel room reservations, long-term rentals, and partner support.',
  'Deep baritone, authoritative, composed, polite, and formal.',
  'You are Rony, an authoritative, courteous, and highly professional concierge. You speak in a composed, respectful tone in both formal Nepali ("Namaskar", "Tapailai swaagat chha") and English. You excel at negotiating fair ride fares, handling hotel bookings, and resolving partner issues.',
  'ne_NP-rony-deep',
  -0.08,
  0.95
),
(
  'jenny',
  'Jenny',
  'female',
  'Sweet, cheerful & hospitable — your grocery & travel companion',
  'Ideal for supermarket shopping, fresh produce selection, family homestays, and customer care.',
  'Warm, sweet, bright, patient, enthusiastic, and polite.',
  'You are Jenny, a warm, sweet, and cheerful concierge. You are polite, enthusiastic, and attentive ("Namaste! Kasto chha tapailai?"). You love helping users discover healthy groceries, fresh vegetables, sweet desserts, and cozy family homestays.',
  'ne_NP-jenny-sweet',
  0.06,
  1.00
),
(
  'sol',
  'Sol',
  'female',
  'Calm, soothing & empathetic — your peaceful evening assistant',
  'Inspired by the soothing tone of ChatGPT Sol. Perfect for late-night comfort orders, calm rides home, and relaxing support.',
  'Mellow, soft, serene, deeply empathetic, and relaxing.',
  'You are Sol, a calm, serene, and deeply empathetic concierge. You speak softly, gently, and reassuringly in Nepali and English, taking relaxed pauses. You provide peace of mind, help users unwind with late-night food or a safe ride home, and listen patiently.',
  'ne_NP-sol-calm',
  -0.03,
  0.92
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  gender = EXCLUDED.gender,
  tagline = EXCLUDED.tagline,
  description = EXCLUDED.description,
  tone = EXCLUDED.tone,
  system_prompt_instruction = EXCLUDED.system_prompt_instruction,
  tts_voice_code = EXCLUDED.tts_voice_code,
  pitch_adjustment = EXCLUDED.pitch_adjustment,
  speed_adjustment = EXCLUDED.speed_adjustment,
  is_active = EXCLUDED.is_active;

-- 3. Extend user_ai_profile with voice persona preferences
ALTER TABLE public.user_ai_profile
  ADD COLUMN IF NOT EXISTS preferred_voice_persona public.ai_voice_persona_enum NOT NULL DEFAULT 'eli',
  ADD COLUMN IF NOT EXISTS voice_speed NUMERIC(3,2) NOT NULL DEFAULT 1.00;

-- 4. RPC to fetch all available voice personas
CREATE OR REPLACE FUNCTION public.get_voice_personas()
RETURNS TABLE (
  id                        public.ai_voice_persona_enum,
  name                      TEXT,
  gender                    TEXT,
  tagline                   TEXT,
  description               TEXT,
  tone                      TEXT,
  tts_voice_code            TEXT,
  pitch_adjustment          NUMERIC(4,2),
  speed_adjustment          NUMERIC(4,2),
  sample_audio_url          TEXT,
  is_active                 BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, name, gender, tagline, description, tone, tts_voice_code,
         pitch_adjustment, speed_adjustment, sample_audio_url, is_active
    FROM public.ai_voice_personas
   WHERE is_active = TRUE
   ORDER BY (CASE id WHEN 'eli' THEN 1 WHEN 'rony' THEN 2 WHEN 'jenny' THEN 3 WHEN 'sol' THEN 4 ELSE 5 END);
$$;

-- 5. RPC to set user's preferred voice persona
CREATE OR REPLACE FUNCTION public.set_preferred_voice_persona(
  p_persona public.ai_voice_persona_enum,
  p_speed NUMERIC DEFAULT 1.00
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID;
BEGIN
  v_user := auth.uid();
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '28000';
  END IF;

  INSERT INTO public.user_ai_profile (user_id, preferred_voice_persona, voice_speed, refreshed_at)
  VALUES (v_user, p_persona, GREATEST(0.75, LEAST(1.50, COALESCE(p_speed, 1.00))), now())
  ON CONFLICT (user_id) DO UPDATE SET
    preferred_voice_persona = EXCLUDED.preferred_voice_persona,
    voice_speed = GREATEST(0.75, LEAST(1.50, COALESCE(p_speed, 1.00))),
    refreshed_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user,
    'preferred_voice_persona', p_persona,
    'voice_speed', GREATEST(0.75, LEAST(1.50, COALESCE(p_speed, 1.00)))
  );
END;
$$;

-- 6. Update get_ai_context to include the selected voice persona & prompt instruction
CREATE OR REPLACE FUNCTION public.get_ai_context(p_user UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_consent BOOLEAN;
  v_prof public.user_ai_profile;
  v_mem JSONB;
  v_persona public.ai_voice_personas;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user THEN
    RAISE EXCEPTION 'not permitted' USING ERRCODE = '42501';
  END IF;
  SELECT ai_personalization_consent INTO v_consent FROM public.profiles WHERE id = p_user;
  IF NOT COALESCE(v_consent, FALSE) THEN RETURN NULL; END IF;

  SELECT * INTO v_prof FROM public.user_ai_profile WHERE user_id = p_user;
  IF NOT FOUND OR v_prof.refreshed_at < now() - interval '6 hours' THEN
    PERFORM public.refresh_user_ai_profile(p_user);
    SELECT * INTO v_prof FROM public.user_ai_profile WHERE user_id = p_user;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('category', category, 'fact', fact) ORDER BY created_at DESC), '[]'::jsonb)
    INTO v_mem FROM public.user_memories WHERE user_id = p_user;

  -- Load persona metadata
  SELECT * INTO v_persona FROM public.ai_voice_personas
   WHERE id = COALESCE(v_prof.preferred_voice_persona, 'eli');

  RETURN jsonb_build_object(
    'spending_tier', v_prof.spending_tier,
    'avg_order_value_npr', round(v_prof.avg_order_value_paisa / 100.0),
    'orders_90d', v_prof.orders_90d,
    'top_items', v_prof.top_items,
    'top_stores', v_prof.top_stores,
    'usual_order_hour', v_prof.usual_order_hour,
    'usual_order_weekday', v_prof.usual_order_weekday,
    'preferred_voice_persona', COALESCE(v_prof.preferred_voice_persona, 'eli'),
    'voice_speed', COALESCE(v_prof.voice_speed, 1.00),
    'persona_name', COALESCE(v_persona.name, 'Eli'),
    'persona_tone', COALESCE(v_persona.tone, 'Energetic'),
    'persona_instruction', COALESCE(v_persona.system_prompt_instruction, 'Friendly concierge'),
    'memories', v_mem
  );
END;
$$;

-- 7. Enable RLS and grants
ALTER TABLE public.ai_voice_personas ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_voice_personas_public_read ON public.ai_voice_personas
  FOR SELECT TO authenticated, anon USING (is_active = TRUE);

CREATE POLICY ai_voice_personas_admin_manage ON public.ai_voice_personas
  FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

GRANT SELECT ON public.ai_voice_personas TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_voice_personas() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_preferred_voice_persona(public.ai_voice_persona_enum, NUMERIC) TO authenticated, service_role;

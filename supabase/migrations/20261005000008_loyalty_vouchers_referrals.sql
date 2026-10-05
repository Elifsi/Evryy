-- =============================================================================
-- 0008 — Loyalty leagues, stamp cards, vouchers & referrals
-- (Schema from docs/architecture/loyalty-social-referrals.md §5, money in paisa.)
-- Points/stamps are awarded ONLY by server triggers; clients can read, never write.
-- =============================================================================

CREATE TABLE public.user_loyalty (
  user_id                   UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_league            public.loyalty_league NOT NULL DEFAULT 'copper',
  tier_points               INTEGER NOT NULL DEFAULT 0 CHECK (tier_points >= 0),
  e_coins_balance           INTEGER NOT NULL DEFAULT 0 CHECK (e_coins_balance >= 0),
  consecutive_checkin_days  INTEGER NOT NULL DEFAULT 0,
  last_checkin_date         DATE,
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.user_stamp_cards (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  vertical               TEXT NOT NULL DEFAULT 'all' CHECK (vertical IN ('food', 'mart', 'rides', 'all')),
  stamps_count           INTEGER NOT NULL DEFAULT 0 CHECK (stamps_count BETWEEN 0 AND 10),
  completed_sheets_count INTEGER NOT NULL DEFAULT 0,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, vertical)
);

CREATE TABLE public.vouchers (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code                  TEXT UNIQUE NOT NULL,
  title                 TEXT NOT NULL,
  description           TEXT,
  discount_type         TEXT NOT NULL CHECK (discount_type IN ('flat_amount', 'percentage', 'free_delivery')),
  discount_value_paisa  BIGINT NOT NULL CHECK (discount_value_paisa >= 0),   -- flat: paisa; percentage: basis points
  min_order_paisa       BIGINT NOT NULL DEFAULT 0,
  max_discount_paisa    BIGINT,
  applicable_vertical   TEXT NOT NULL DEFAULT 'all' CHECK (applicable_vertical IN ('food', 'grocery', 'rides', 'hotels', 'all')),
  valid_from            TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_until           TIMESTAMPTZ NOT NULL,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (valid_until > valid_from)
);

CREATE TABLE public.user_vouchers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  voucher_id  UUID NOT NULL REFERENCES public.vouchers(id) ON DELETE CASCADE,
  is_used     BOOLEAN NOT NULL DEFAULT FALSE,
  used_at     TIMESTAMPTZ,
  order_id    UUID REFERENCES public.orders(id),
  claimed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, voucher_id)
);

CREATE TABLE public.user_referrals (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id        UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  referee_id         UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  referral_code_used TEXT NOT NULL,
  status             TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired')),
  first_order_id     UUID REFERENCES public.orders(id),
  reward_voucher_id  UUID REFERENCES public.vouchers(id),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at       TIMESTAMPTZ,
  CHECK (referrer_id <> referee_id)
);

-- Redeem a referral code once, right after signup (self-referral impossible).
CREATE OR REPLACE FUNCTION public.redeem_referral_code(p_code TEXT)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_referrer UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000'; END IF;
  SELECT id INTO v_referrer FROM public.profiles WHERE referral_code = upper(trim(p_code));
  IF v_referrer IS NULL THEN RAISE EXCEPTION 'invalid referral code'; END IF;
  IF v_referrer = auth.uid() THEN RAISE EXCEPTION 'you cannot refer yourself'; END IF;
  IF EXISTS (SELECT 1 FROM public.orders WHERE consumer_id = auth.uid()) THEN
    RAISE EXCEPTION 'referral codes can only be used before your first order';
  END IF;
  INSERT INTO public.user_referrals (referrer_id, referee_id, referral_code_used)
  VALUES (v_referrer, auth.uid(), upper(trim(p_code)));
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'a referral code was already applied to this account';
END;
$$;

-- Daily check-in: +e-coins with a streak bonus, at most once per Nepal calendar day.
CREATE OR REPLACE FUNCTION public.daily_check_in()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_today DATE := (now() AT TIME ZONE 'Asia/Kathmandu')::date;
  v_row public.user_loyalty; v_streak INT; v_coins INT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required' USING ERRCODE = '28000'; END IF;
  INSERT INTO public.user_loyalty (user_id) VALUES (v_uid) ON CONFLICT DO NOTHING;
  SELECT * INTO v_row FROM public.user_loyalty WHERE user_id = v_uid FOR UPDATE;
  IF v_row.last_checkin_date = v_today THEN RAISE EXCEPTION 'already checked in today'; END IF;
  v_streak := CASE WHEN v_row.last_checkin_date = v_today - 1 THEN v_row.consecutive_checkin_days + 1 ELSE 1 END;
  v_coins := LEAST(v_streak, 7) * 2;      -- 2..14 coins/day
  UPDATE public.user_loyalty
     SET consecutive_checkin_days = v_streak, last_checkin_date = v_today,
         e_coins_balance = e_coins_balance + v_coins, updated_at = now()
   WHERE user_id = v_uid;
  RETURN v_coins;
END;
$$;

-- Award loyalty when an order is delivered: 1 point per NPR 100, stamp card, league bump, referral completion.
CREATE OR REPLACE FUNCTION public.award_loyalty_on_delivery()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_points INT; v_vertical TEXT; v_new_points INT; v_card public.user_stamp_cards;
BEGIN
  IF NEW.status <> 'delivered' OR OLD.status = 'delivered' THEN RETURN NEW; END IF;
  v_points := (NEW.total_paisa / 10000)::int;
  v_vertical := (SELECT CASE category WHEN 'food' THEN 'food' ELSE 'mart' END FROM public.stores WHERE id = NEW.store_id);

  INSERT INTO public.user_loyalty (user_id) VALUES (NEW.consumer_id) ON CONFLICT DO NOTHING;
  UPDATE public.user_loyalty SET tier_points = tier_points + v_points, e_coins_balance = e_coins_balance + v_points, updated_at = now()
   WHERE user_id = NEW.consumer_id RETURNING tier_points INTO v_new_points;
  UPDATE public.user_loyalty SET current_league = CASE
      WHEN v_new_points >= 5000 THEN 'diamond'::public.loyalty_league
      WHEN v_new_points >= 2000 THEN 'platinum'
      WHEN v_new_points >= 800  THEN 'silver'
      WHEN v_new_points >= 200  THEN 'bronze'
      ELSE 'copper' END
   WHERE user_id = NEW.consumer_id;

  INSERT INTO public.user_stamp_cards (user_id, vertical) VALUES (NEW.consumer_id, v_vertical) ON CONFLICT DO NOTHING;
  SELECT * INTO v_card FROM public.user_stamp_cards WHERE user_id = NEW.consumer_id AND vertical = v_vertical FOR UPDATE;
  IF v_card.stamps_count + 1 >= 10 THEN
    UPDATE public.user_stamp_cards SET stamps_count = 0, completed_sheets_count = completed_sheets_count + 1, updated_at = now() WHERE id = v_card.id;
  ELSE
    UPDATE public.user_stamp_cards SET stamps_count = stamps_count + 1, updated_at = now() WHERE id = v_card.id;
  END IF;

  UPDATE public.user_referrals SET status = 'completed', first_order_id = NEW.id, completed_at = now()
   WHERE referee_id = NEW.consumer_id AND status = 'pending';
  RETURN NEW;
END;
$$;
CREATE TRIGGER orders_award_loyalty AFTER UPDATE OF status ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.award_loyalty_on_delivery();

-- ---------------------------------------------------------------------------
-- RLS — read own; no direct client writes (all through RPCs / triggers)
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_loyalty      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_stamp_cards  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vouchers          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_vouchers     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_referrals    ENABLE ROW LEVEL SECURITY;

CREATE POLICY loyalty_own   ON public.user_loyalty     FOR SELECT USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY stamps_own    ON public.user_stamp_cards FOR SELECT USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY vouchers_read ON public.vouchers FOR SELECT USING (is_active AND valid_until > now() OR public.is_admin());
CREATE POLICY vouchers_admin ON public.vouchers FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY user_vouchers_own ON public.user_vouchers FOR SELECT USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY referrals_own ON public.user_referrals FOR SELECT
  USING (referrer_id = auth.uid() OR referee_id = auth.uid() OR public.is_admin());

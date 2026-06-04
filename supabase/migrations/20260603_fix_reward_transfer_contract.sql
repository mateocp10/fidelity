-- Align reward transfers with the live Supabase contract used by the app.
-- Business rule: only approved rewards can be transferred to client users.

ALTER TABLE public.reward_transfer_history
ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;

UPDATE public.reward_transfer_history history
SET business_id = rewards.business_id
FROM public.rewards rewards
WHERE history.reward_id = rewards.id
  AND history.business_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_reward_transfer_history_business_id
ON public.reward_transfer_history (business_id);

CREATE INDEX IF NOT EXISTS idx_reward_transfer_history_transferred_at
ON public.reward_transfer_history (transferred_at DESC);

DO $reward_transfer_policy$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reward_transfer_history'
      AND policyname = 'Business owners can view transfer history'
  ) THEN
    CREATE POLICY "Business owners can view transfer history"
    ON public.reward_transfer_history
    FOR SELECT
    USING (
      EXISTS (
        SELECT 1
        FROM public.businesses
        WHERE businesses.id = reward_transfer_history.business_id
          AND businesses.owner_id = auth.uid()
      )
    );
  END IF;
END
$reward_transfer_policy$;

CREATE OR REPLACE FUNCTION public.transfer_reward(
  p_reward_id UUID,
  p_user_id UUID,
  p_loyalty_card_id UUID
) RETURNS BOOLEAN AS $transfer_reward$
DECLARE
  v_from_user_id UUID;
  v_business_id UUID;
  v_status public.reward_status;
  v_recipient_role public.user_role;
  v_card_user_id UUID;
  v_card_business_id UUID;
BEGIN
  SELECT user_id, business_id, status
  INTO v_from_user_id, v_business_id, v_status
  FROM public.rewards
  WHERE id = p_reward_id
  FOR UPDATE;

  IF v_from_user_id IS NULL THEN
    RAISE EXCEPTION 'REWARD_NOT_FOUND';
  END IF;

  IF v_from_user_id != auth.uid() THEN
    RAISE EXCEPTION 'REWARD_NOT_OWNED';
  END IF;

  IF v_status != 'approved'::public.reward_status THEN
    RAISE EXCEPTION 'REWARD_NOT_APPROVED';
  END IF;

  IF p_user_id = v_from_user_id THEN
    RAISE EXCEPTION 'CANNOT_TRANSFER_TO_SELF';
  END IF;

  SELECT role
  INTO v_recipient_role
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_recipient_role IS NULL THEN
    RAISE EXCEPTION 'RECIPIENT_NOT_FOUND';
  END IF;

  IF v_recipient_role != 'client'::public.user_role THEN
    RAISE EXCEPTION 'RECIPIENT_NOT_CLIENT';
  END IF;

  SELECT user_id, business_id
  INTO v_card_user_id, v_card_business_id
  FROM public.loyalty_cards
  WHERE id = p_loyalty_card_id;

  IF v_card_user_id IS NULL THEN
    RAISE EXCEPTION 'LOYALTY_CARD_NOT_FOUND';
  END IF;

  IF v_card_user_id != p_user_id OR v_card_business_id != v_business_id THEN
    RAISE EXCEPTION 'LOYALTY_CARD_MISMATCH';
  END IF;

  UPDATE public.rewards
  SET user_id = p_user_id,
      loyalty_card_id = p_loyalty_card_id
  WHERE id = p_reward_id;

  INSERT INTO public.reward_transfer_history (
    reward_id,
    from_user_id,
    to_user_id,
    business_id,
    transferred_at
  ) VALUES (
    p_reward_id,
    v_from_user_id,
    p_user_id,
    v_business_id,
    NOW()
  );

  RETURN TRUE;
END;
$transfer_reward$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

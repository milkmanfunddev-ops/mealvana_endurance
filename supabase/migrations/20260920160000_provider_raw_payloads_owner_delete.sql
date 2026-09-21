-- Owner DELETE on provider_raw_payloads (real-payload-corpus@v1, recon W3).
--
-- Q-INT2's hard-purge ("also delete my synced data") runs CLIENT-SIDE
-- (connect_training_controller._purgeProviderData), so the disconnect wipe
-- needs an owner DELETE policy or RLS silently filters it to zero rows.
-- Scope stays the athlete's own rows; the capture path remains append-only
-- (insert-or-ignore) and the TTL purge remains service-side.

DROP POLICY IF EXISTS "Users can delete own raw payloads" ON public.provider_raw_payloads;
CREATE POLICY "Users can delete own raw payloads"
  ON public.provider_raw_payloads FOR DELETE
  USING ((SELECT auth.uid()) = user_id);

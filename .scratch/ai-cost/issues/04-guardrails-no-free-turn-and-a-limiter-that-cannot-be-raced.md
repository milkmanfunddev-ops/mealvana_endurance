# 04: Guardrails: no free turn, and a limiter that cannot be raced

**Status:** done (wave 2, 2026-09-21)
**Blocked by:** 02 (touches supabase/functions/_shared/vana/chat.ts).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** A request with an empty message runs nothing and stores nothing. Five requests fired at once against a limit of four let four through. The pantry photo, the described meal and the meal photo share the same per-minute limiter as chat. A single turn cannot run past a token ceiling. There is no daily cap and no cap on turns.

**Decisions:** mp-430, mp-432; approved as mp-469.

**Touches:** supabase/functions/_shared/vana/rate-limit.ts, supabase/functions/_shared/vana/chat.ts, supabase/functions/vana-chat/index.ts, supabase/functions/_shared/vana/actions.ts, supabase/functions/describe-meal/index.ts, supabase/functions/analyze-meal-photo/index.ts, assets/config/content_defaults.json

- [x] A chat request with a conversation id and an empty message returns 400, runs no model and stores no row (handler test).
- [x] The limiter writes the call row before the model runs: five parallel calls against a limit of four let four through (test).
- [x] The limiter stays in the shared Vana rate-limit module on the server; the pantry photo, the described meal and the meal photo call that module. Nothing moves to the phone.
- [x] A turn stops at a per-turn token ceiling as well as its step limit.
- [x] The refusal text comes from the content system.
- [x] No daily cap and no turn counter is added (mp-430).

## Wave 2 review and dev check (2026-09-21)

- The review found the insert-then-rank limiter could still be beaten by an insert that commits late, and that a malformed `conversation_id` failed the reservation open. The limiter now asks `vana_reserve_call` (advisory lock on user and bucket, count, insert; migration `20260921130000_vana_reserve_call.sql`, applied to dev) and ranks only where that function is missing. The reservation carries no conversation id; `completeCall` sets it.
- Dev, real database: eight parallel reservations against a limit of four left four rows; three were refused and one request dropped its connection.
- The per-turn ceiling is 150,000 tokens, not 60,000: on dev a planning turn ran 22k at the median and 85k at most over 14 days, cached input included.
- Deployed to dev: vana-chat, jade-chat, vana-action, vana-day-notes, describe-meal, analyze-meal-photo. A live turn from the simulator left one `vana.chat.general` row with its tokens and conversation id.

Next: /implement-lee ai-cost

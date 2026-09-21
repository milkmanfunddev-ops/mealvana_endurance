# 02: Every AI function checks the subscription on the server

**Status:** in-progress (wave 1, 2026-09-21)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** A lapsed dev account holding bought budget is refused by describe-meal, analyze-meal-photo, meal-photo, ai-coach and jade-chat, the same way Vana refuses it today. Each calls the shared check at the top.

**Decisions:** mp-429, mp-285, mp-318; approved as mp-481.

**Touches:** supabase/functions/_shared/vana/entitlement.ts, supabase/functions/describe-meal, supabase/functions/analyze-meal-photo, supabase/functions/meal-photo, supabase/functions/ai-coach, supabase/functions/jade-chat

- [x] Each of the five functions returns the same refusal as vana-chat for an account with no active row (function tests).
- [x] An active account still gets through.
- [ ] Deployed to dev.

Next: /implement-lee paywall

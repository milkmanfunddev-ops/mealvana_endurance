# 02: A hard budget on every gateway key, and "unavailable" when the fault is ours

**Status:** done (wave 1, 2026-09-21)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** Three gateway keys exist (production, dev, evals and build agents) with monthly budgets of $150, $40 and $25 that hard-stop, each with an alert before the cap. When the gateway refuses us, the athlete sees "Vana is unavailable right now" and never the top-up sheet. Every function imports one exact version of the AI SDK.

**Decisions:** mp-437; approved as mp-467.

**Touches:** supabase/functions/_shared/vana/env.ts, supabase/functions/_shared/ai/model.ts, supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/extract.ts, supabase/functions/_shared/vana/daynotes.ts, supabase/functions/_shared/vana/pantry.ts, supabase/functions/_shared/vana/saved-ingredients.ts, supabase/functions/_shared/vana/embeddings.ts, supabase/functions/describe-meal/index.ts, supabase/functions/analyze-meal-photo/index.ts, lib/features/meal_planning/data/vana_exceptions.dart, lib/features/meal_planning/data/vana_transport.dart, lib/features/ai_credits/presentation/insufficient_credits_handler.dart, scripts/vana-eval

- [x] Three keys exist in Vercel with the three budgets and an alert each, created in Lee's signed-in session. If the permission check blocks creating a secret, the form is left filled in and Lee presses the button.
- [x] The dev key is set as the dev function secret; the evals key is what `scripts/vana-eval` uses. The production key is created and not deployed. (`scripts/vana-eval/gateway-key.ts` reads `AI_GATEWAY_API_KEY_EVALS` for scripts that call the gateway directly; the chat evals call the DEV functions, so their spend lands on the dev key.)
- [x] A gateway refusal (stubbed 402 from the gateway) surfaces as "Vana is unavailable right now" from the content system, never the top-up sheet and never a crash (handler test, and a widget test through the real chat controller).
- [x] Every `npm:ai` import names one exact version.
- [x] The default chat model id uses the gateway catalogue's spelling; one dev call confirms it resolves.

Next: /implement-lee ai-cost

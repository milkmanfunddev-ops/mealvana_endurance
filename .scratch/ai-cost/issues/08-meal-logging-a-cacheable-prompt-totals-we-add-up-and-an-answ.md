# 08: Meal logging: a cacheable prompt, totals we add up, and an answer for "not food"

**Status:** in-progress (wave 3, 2026-09-22)
**Blocked by:** 02 (touches supabase/functions/describe-meal/index.ts), 04 (touches supabase/functions/describe-meal/index.ts).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** A photo that is not food gets one short answer and no made-up macros. Totals always equal the sum of the items. Photos upload at 1,000 px on the long edge, so a portrait photo stops costing a third more. Both functions stay on Sonnet.

**Decisions:** mp-465, mp-432; approved as mp-473.

**Touches:** supabase/functions/describe-meal/index.ts, supabase/functions/analyze-meal-photo/index.ts, lib/features/meal_logging/application/meal_ai_service.dart, lib/features/meal_logging/presentation/screens/photo_capture_screen.dart

- [x] Both functions send their fixed instructions first with a one-hour cache marker and the athlete's text or photo last (prompt shape test in each function's own test file).
- [x] The function adds up the totals; the model's totals are ignored (test with a mismatched model answer).
- [x] The output has a "not food" answer and the log-meal screen shows one short line for it, from the content system.
- [x] Photos are sent at 1,000 px on the long edge; a portrait and a landscape photo of the same scene bill within 10% of each other on dev.
- [x] Both model settings still default to Sonnet.

Next: /implement-lee ai-cost

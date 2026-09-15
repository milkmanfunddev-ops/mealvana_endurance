# 32: Every recipe says where its steps came from

**Status:** done (wave 2, 2026-09-15)
**Blocked by:** 25 (touches lib/features/meal_planning/presentation/screens/meal_detail_screen.dart).
**Next:** `/implement-lee mealplanning`

**What to build:** Every recipe's steps carry a label by origin: verbatim steps read "as published by X" with a link to the original, an alternate source names it, a simple assembly says so, and AI-generated steps keep the sparkle with its tooltip. Macros stay as they were.

**Decisions:** mp-146; approved as mp-310.

**Touches:** lib/features/meal_planning/presentation/screens/meal_detail_screen.dart, lib/features/meal_planning/domain/directions_origin.dart

- [x] Four origins, four labels; verbatim carries the publisher name and link (widget test per origin).
- [x] The sparkle tooltip is unchanged for AI-generated steps.
- [x] Golden of the detail screen per origin.

Next: /implement-lee mealplanning

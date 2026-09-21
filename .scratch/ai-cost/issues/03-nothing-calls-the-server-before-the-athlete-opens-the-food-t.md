# 03: Nothing calls the server before the athlete opens the Food tab

**Status:** done (wave 1, 2026-09-21)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** The app opens without building the Food tabs. The first Vana request happens when the athlete first opens Food. A tab that has been visited keeps its state.

**Decisions:** mp-432; approved as mp-468.

**Touches:** lib/shared/widgets/tabs_screen.dart, lib/features/meal_planning/presentation/screens/food_screen.dart

- [x] No Vana request fires between launch and the first visit to the Food tab (widget test over a transport that counts calls).
- [x] A visited tab keeps its scroll position and state when the athlete leaves and returns.
- [x] Checked on a pool simulator: cold launch to Home shows no Vana call in the log. — 2026-09-21 on wave-pool-1: cold launch to Home logged only `calculate-daily-macros-v6` (×2) on dev; the first `vana-action` came 4 s after opening Food.

Next: /implement-lee ai-cost

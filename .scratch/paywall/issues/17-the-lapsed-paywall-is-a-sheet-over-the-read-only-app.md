# 17: The lapsed paywall is a sheet over the read-only app

**Status:** in-progress (wave 5, 2026-09-23)
**Blocked by:** 03 (touches lib/features/subscription/presentation/screens/paywall_screen.dart), 11 (touches lib/features/subscription/presentation/pro_gate_redirect.dart), 14 (touches lib/features/subscription/presentation/screens/paywall_screen.dart), 15 (touches lib/features/subscription/presentation/screens/paywall_screen.dart), 16 (touches test/features/subscription/presentation/goldens/).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** For a lapsed account, the "plan ended" bar's Subscribe button and any edit or AI tap open the paywall as a closable glass sheet over the read-only app instead of a full-screen route. Closing it returns to the screen they were on. A never-subscribed account still gets it full screen.

**Decisions:** mp-493, mp-457, mp-280, mp-496, mp-497; approved as mp-501.

**Touches:** lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/subscription/presentation/pro_gate_redirect.dart, lib/shared/widgets/kyle_design/sheets/, lib/shared/widgets/tabs_screen.dart, test/features/subscription/presentation/paywall_screen_test.dart, test/features/subscription/presentation/goldens/

- [x] Lapsed: the bar's Subscribe and an AI tap open the sheet; close returns to the same screen (screen widget test).
- [x] Never: still full screen, no close (screen widget test).
- [x] The sheet's entrance comes from the `kyle_design` glass sheet, extended there if it needs to be.
- [x] Golden of the sheet presentation, light and dark.
- [ ] Checked on the dev simulator with an expired sandbox account.

Next: /implement-lee paywall

# 15: Plans pinned above one Continue, and the ⋯ menu

**Status:** in-progress (wave 3, 2026-09-22)
**Blocked by:** 03 (touches lib/features/subscription/presentation/screens/paywall_screen.dart), 04 (touches lib/features/content/domain/content_keys.dart), 14 (touches lib/shared/widgets/kyle_design/kyle_design.dart).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** The two plan cards stay pinned above one Continue button through the scroll; the annual card is selected and shows its saving and per-month price from store prices, with founding prices struck through as ticket 03 built them. One ⋯ button holds Restore purchases, Manage subscription (only with a subscription), Sign out and Delete account; the old stack of text buttons is gone. A never-subscribed account gets no close button. Redeem code is not in the menu yet (mp-496). Goldens of the full-screen paywall, light and dark, replace the 09-15 ones.

**Decisions:** mp-493, mp-494, mp-496, mp-497, mp-453, mp-417; approved as mp-499.

**Touches:** lib/shared/widgets/kyle_design/cards/plan_card.dart, lib/shared/widgets/kyle_design/buttons/overflow_menu_button.dart, lib/shared/widgets/kyle_design/kyle_design.dart, docs/ssot/spec/design/components/plan-card.md, docs/ssot/spec/design/components/overflow-menu.md, lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/content/domain/content_keys.dart, test/shared/widgets/kyle_design/plan_card_test.dart, test/shared/widgets/kyle_design/overflow_menu_button_test.dart, test/features/subscription/presentation/paywall_screen_test.dart, test/features/subscription/presentation/goldens/

- [ ] Plans and Continue stay on screen through the whole scroll (screen widget test).
- [ ] Annual shows "save 33%" and $16.67 a month on default, $8.33 a month on founding, computed from fake store prices (screen widget test).
- [ ] The ⋯ menu lists exactly Restore, Manage (only with a subscription), Sign out and Delete account; no Redeem code (screen widget test).
- [ ] No close button for a never-subscribed account.
- [ ] Goldens of the full-screen paywall, light and dark, replace paywall_light, paywall_dark and paywall_onboarding_dark.
- [ ] Checked on the dev simulator; Delete account still reachable for review.

Next: /implement-lee paywall

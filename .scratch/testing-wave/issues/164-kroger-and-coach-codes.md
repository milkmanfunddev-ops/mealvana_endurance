# 164: Kroger continues after connect; coach-code copy

**Status:** in-progress (wave 44, 2026-09-28)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Two rulings Lee made on 2026-09-28 about questions fixes 133 and 140 left open (`review-20260928-rulings.md` items 12 and 13):
1. **Add to cart carries on after Connect Kroger (from 133).** When an athlete with no Kroger link taps Add to cart on the shopping list and connects successfully, the app goes straight on to matching and the cart send. They don't tap a second time. A cancelled or failed connect returns to the list as now (`shopping_tab.dart`, `kroger_controller.dart`, `kroger_screen.dart`).
2. **Coach-code refusal copy (from 140).** A code already reopens a pairing the coach declined or archived (`redeem-code/handler.ts` ~411). Lee confirmed that behaviour, so keep it. The refusal "You've already asked this coach to pair." no longer fits auto-accept pairing. Change it to "You're already paired with this coach." in `handler.ts` (`already_paired`) and `content_defaults.json` (`refused_already_paired`), and check that the case it covers is only an already-active pairing. Deploy `redeem-code` to dev.

**Findings:** none of their own. These are the product questions raised by fixes 133 and 140 (review items 18 and 19).

**Decisions:** Lee in the terminal, 2026-09-28.

**Touches:** lib/features/meal_planning/presentation/screens/shopping_tab.dart, lib/features/kroger/application/kroger_controller.dart, lib/features/kroger/presentation/kroger_screen.dart, supabase/functions/redeem-code/handler.ts, assets/config/content_defaults.json

- [ ] Seam test through the real notifier: a successful connect started from Add to cart goes on into the send. A cancelled connect does not.
- [ ] Deno test: the already-paired refusal carries the new copy, and a declined or archived pairing reopens.
- [ ] `flutter analyze` clean on touched files.

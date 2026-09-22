# 10: The athlete sees a share of the month, never dollars

**Status:** done (wave 5, 2026-09-22)
**Blocked by:** 02 (touches lib/features/ai_credits), 04 (touches assets/config/content_defaults.json), 09.
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** Vana settings shows how much of this month's Vana is used, when it refills and any bought extra, as a bar and words, with no dollar figure anywhere. At 100% the athlete gets the top-up sheet, with the packs worded for the new unit. The wallet's live connection is open only while a budget screen is showing.

**Decisions:** mp-430, mp-436, mp-282; approved as mp-475.

**Touches:** lib/features/ai_credits, lib/features/meal_planning/presentation/screens/vana_settings_screen.dart, assets/config/content_defaults.json

- [x] The Vana settings usage bar shows a share, a refill date and bought extra with no dollar figure (widget test through the real controller).
- [x] At 100% the top-up sheet opens (mp-282); the pack wording names the new unit and no credit count.
- [x] The wallet channel opens and closes with the budget screens (widget test over a transport that counts).
- [x] A gateway refusal still shows "Vana is unavailable right now" and never the top-up sheet (ticket 02's test stays green).
- [x] Every controller write path keeps its test through the real notifier.
- [x] Checked on a pool simulator: the bar in Vana settings, and the sheet at 100% on a drained dev wallet.

Next: /implement-lee ai-cost

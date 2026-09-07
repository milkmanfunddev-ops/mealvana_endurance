# Design SSOT — Surface: Vana Browse (meals from chat)

**Status:** RECORDED v1 (Lee, 2026-09-03 evening) — PROPOSED, awaiting Xuan.
**Source:** none — this is a new app-side surface, not a prototype/Figma port. Built 2026-09-03 evening (Lee:
"browse all of our recipes and assign them to the meal plan") to close the gap the MealBuddy v5 concept's
browse-sheet pattern named (`../../../vana-chatbot-update-plan.md` §4, Phase 6 addendum).
**Code:** `lib/features/meal_planning/presentation/screens/vana_browse_screen.dart`
(`VanaBrowseScreen`), reusing `../../../../../../lib/features/meal_planning/presentation/widgets/meal_catalog_browser.dart`
(`MealCatalogBrowser`) and `meal_add_button.dart` (`MealAddButton`); route `/vana/browse?c=<conversationId>`
(`lib/shared/core/app_router.dart`).
**Scope:** the whole-catalog browse-and-add flow reachable from a planning chat. It owns nothing about the
catalog UI itself (that's `food-meals-catalog.md`'s `MealCatalogBrowser`, shared verbatim) — only the
conversation-scoped write target and the entry/exit points.

**What this file owns:** how "Browse meals" is entered from chat, what tapping Add writes and to which draft,
and how the chat surface picks the resulting changes back up on return.

## Contracts

| # | Contract |
|---|---|
| VB-1 | **Entry points** are on `../../surfaces/vana-planning-chat.md` (VP-12): a chip under every picker, and the leading row of the composer's `+` attach sheet. Both open `/vana/browse?c=<conversationId>` — the calling conversation's id is required; the router redirects to `/vana` if `c` is missing (`app_router.dart`). |
| VB-2 | **Same catalog UI as the Meals tab** (`MealCatalogBrowser`, `food-meals-catalog.md` FM-1/FM-2/FM-7): Mine \| Library, meal-type chips, No-recipe/Recipes, context chips, semantic search. Excluded-by-allergy meals render the same greyed treatment (MC-1) and are never addable here either. |
| VB-3 | **Add is a tick, not a servings sheet.** Every card carries a round `MealAddButton` (key `meal_planning.browse_add_<id>`, outlined `+` → filled electrolyte check once added). Tapping it picks the meal into the CALLING conversation's draft at the picker's default servings (`VanaBrowseScreen.defaultServings = 4`, same default `VanaMealPickerPart.defaultServings` uses) via remote-ack `pick_meals {conversationId}` — never the week's active plan (contrast FM-3). |
| VB-4 | **Tapping the card body opens the meal detail with `?pick=<conversationId>`** so "Add to plan" is available there too, writing to the same conversation draft; the detail screen pops `true` when its Add landed, which ticks the card on return (`vana_browse_screen.dart` `_added`). |
| VB-5 | **"Done" pops back to the chat.** The chat surface (`VanaChatController.refreshDraft()`, VP-11/VP-12) re-reads the conversation's draft from the server on return, so the plan bar reflects every pick made on this screen — including ones made only via the detail page. |
| VB-6 | **No conversation-scoped removal here.** Removing a meal added via Browse happens the normal way, from the plan bar (`plan-bar.md` PB-3/PB-G2) back in chat — this surface only adds. |

## Conformance

Widget: `test/features/meal_planning/presentation/screens/vana_browse_screen_test.dart` — confirmed present,
2026-09-04 (`every rail card carries an Add button`; `Add picks into the conversation draft, ticks and toasts`
— VB-3; `a failed pick leaves the card un-ticked and warns`; `Done pops back to the chat` — VB-5). Not yet
vectored or golden-tested. No Patrol flow yet chaining chat → browse → add → back → plan bar — flagged as a gap,
not fabricated.

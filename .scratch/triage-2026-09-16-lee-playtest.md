# Lee's playtest, 2026-09-16

Ten observations from playing the dev build on an iPhone as `test@test.com`. Seven screenshots
were read; the causes below were traced in code and on the dev database.

| # | Ask | Status | Where |
|---|---|---|---|
| 1 | Approve all on Shop with Kroger | built | `kroger_controller.dart` `approveAll`, screen button |
| 2 | "Change" opens a product picker, not a text field | built | `kroger_screen.dart` search sheet over the `search` action |
| 3 | "Approve" label clipped | built | `KylePrimaryButtonSmall` padding |
| 4 | Send-to-cart button never hides | built | disabled until one line is approved |
| 5 | Egg & veggie scramble not broken into ingredients | diagnosed, not built | see below |
| 6 | Several shopping lists, newest on top, history | needs grilling | see below |
| 7 | Remove UPDATE / To do badges; Vana is always the purple V | built | chip and its derivation deleted; `VanaAvatar` moved to `kyle_design/icons/` |
| 8 | Vana could not see IRONMAN Cozumel | fixed | `context.ts` capped the race lookup at 21 days; Cozumel is 67 out |
| 9 | "New meal plan" opener talks about the old plan | fixed | button sends `intent=new_plan`; server picks the fresh-plan opener and hides the Plan-tab situation |
| 10 | Vana can do every app action (CRUD on events, plans, logs) | needs grilling | see below |

Items 8 and 9 need `vana-chat` redeployed to dev. Item 7 departs from the mirrored specs
`vana-sheet.md` §Anatomy and `vana-moment.md` VM-1 (status chip, orange sparkle avatar); the change
belongs in the QA repo, the code headers note the departure.

## 5. Why the scramble is one line

`saved_meals` row `fd993bbb…` was saved from a log (Describe or photo), whose unit is the dish:
`items = [{name: "Egg & Veggie Scramble", portion: "1 serving", …macros}]`, no ingredients.
`grocery.ts:116` turns every saved-meal item into a shopping line, so the dish becomes "4 serving"
under Protein, and Kroger cannot match a "serving". Library meals and "Save to mine" copies carry
`ingredients_json` and break down correctly. It recurs every time this meal is planned.

Options, cheapest first:

- **A. Extract once when a dish-level saved meal joins a plan.** One model call from name, items and
  notes ("two eggs per serving"), written to an `ingredients_json` on the saved meal; `grocery.ts`
  prefers it. Keeps mp-244 (server builds the list). Recommended.
- **B. Flag the line "Needs ingredients"** with a tap that opens Vana on "what goes in X for one
  serving" and runs A. Honest fallback when A is low-confidence.
- **C. Hand CRUD on the list.** Needs `manual`/`edited` flags that `refreshShopping` preserves
  (today it rebuilds `meal_plans.shopping` from meals and keeps only `checked`/`have` by name).
  Fixes the symptom, not the cause. Kroger's draft already solves this shape with `KrogerLine.manual`.

Small regardless: neither `grocery.ts` `PLURAL` nor `KrogerMatching.parse` knows "serving".

## 6. Several shopping lists

Today the list is one `jsonb` column, `meal_plans.shopping`, keyed by lowercased name, no line id,
no owner. "Newest on top, see prior lists" plus CRUD wants `shopping_lists (id, user_id, plan_id?,
name, status)` and `shopping_items (id, list_id, name, qty, aisle, checked, have, source
plan|manual, from_meal_ids, edited_at)`, offline-first in Drift like `saved_meals`, with
`refreshShopping` upserting only `source=plan` rows. Reopens mp-244 clause 1. Questions for the grill:

- Is a list per plan (archived plans already give history for free) or independent of plans?
- Does a hand-added line survive a re-plan? A renamed one?
- What does Kroger send from: the list, or still its own draft?

## 10. Vana with every app action

Vana's tools today: meal planning (`planWeek`, `swapMeal`, `confirmPlan`, `shoppingList`,
`logFromPlan`…), memory, settings, read-only profile/workouts/logs, and `handOff` to screens for
events, activities and carb loading. There is no create/update/delete for events, activities or
food logs, and no "archive this plan and start over" (item 9 is the button path, not a tool).

Questions for the grill:

- Which writes may Vana make without a confirm step? Deleting a plan or an event is not a swap.
- Do coach-on-athlete rules apply (remote ack before success)?
- Where does the tool run: `vana-action` cases exist for plans; events and logs live in the app's
  offline-first repositories, so a server-side write bypasses `ensureSynced`.
- Does the athlete see a receipt part ("Removed Ironman Cozumel · Undo") for every write?

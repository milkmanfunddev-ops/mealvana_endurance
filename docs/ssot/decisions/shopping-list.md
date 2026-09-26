# Decisions: Shopping list

Feature: shopping-list
Feature name: Shopping list

## mp-244 · Confirming a plan makes its shopping list, and every edit keeps it current
- category: Lists
- status: approved
- folded: mp-692, mp-695, mp-669
- image: none
- screen: Shopping tab
- source: plan-tab-v2.md; 05-flutter-feature.md; memory 09-07; memory 09-02

**Context.** A confirmed plan is a set of meals with servings. The list adds up every ingredient across them, and Kroger and other screens read the same list.

**Question.** Where does the shopping list come from?

**Decision.** Confirming a plan builds its list, adding up every ingredient across the plan's meals, and every later edit to the plan rebuilds it. It is built in one place, on our server, so every screen and Kroger read the same list. The Shopping tab opens this week's confirmed plan's list, titled by its week ("Week of Sep 20"), or else the newest hand-made list. The athlete can delete a plan's list after a confirm; the Plan tab rebuilds it. Example: two dinners both use onions, so the list shows one onion row with a count of 2.

**Why.** One list, built in one place, can never disagree with itself.

**What else was considered.** Building the list on the phone.

> 2026-09-26 overhaul: rewritten from mp-244
> 2026-09-26 approved by Lee: which list opens and its name, checked in code (mp-692, mp-695)
> 2026-09-26 decided by Claude (Lee's delegation): deleting a plan's list stays as built (mp-669)

## mp-697 · The list is grouped by aisle, in imperial units, and each item leads back to its meals
- category: Lists
- status: approved
- image: none
- screen: Shopping tab
- source: plan-tab-v2.md; memory 09-07; Lee on the page 2026-09-14

**Context.** The athlete shops from this list in a store. Many ingredients are shared by several meals.

**Question.** How does the list read?

**Decision.** Items sit in nine aisle groups, each with a checkbox and a quantity. Quantities are imperial unless Settings says metric. An item used by more than one meal shows a count, and tapping it lists those meals and leads back to their recipes. Items the athlete already has are hidden. Share sends the list as plain text.

**Why.** US athletes read imperial. Lee wanted a way back to the recipe without new controls.

**What else was considered.** A metric default. A per-row "have it" switch and a pickup button.

> 2026-09-26 overhaul: split out of mp-244

## mp-039 · Shopping lists carry no prices, deals or coupons
- category: Lists
- status: approved
- image: none
- screen: none (algorithm/data)
- source: vana-chatbot-update-plan.md

**Context.** Early concepts showed Vana gathering coupons and planning around the week's grocery deals.

**Question.** Does the list show prices, deals or a total cost?

**Decision.** No. The app has no source of grocery prices, so there are no deals, coupons or cost estimates. Vana can still plan to a budget the athlete tells her.

**Why.** There is nothing to show prices from. Revisit if price data arrives.

**What else was considered.** The concept's "gathering coupons" step.

> 2026-09-26 overhaul: rewritten from mp-039

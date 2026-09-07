# spec/domain/ — meal-planning domain rules

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** The same third truth family the QA repo
created on 2026-08-31: *what a thing is* and *when an action is offered* — truths with no formula and no hue,
stated once and cited by every surface, tool and engine that touches them.

| File | Owns |
|---|---|
| [`meal.md`](meal.md) | what a meal is: assembly vs recipe, `MealRef`, the catalog enums and conventions, directions provenance, images, attribution, votes, saved meals |
| [`plan.md`](plan.md) | what a plan is: draft/confirmed/archived, one confirmed per week, drafts per conversation, the scope rule, servings and "ate it", swaps, rewind snapshots, day slots |
| [`memory.md`](memory.md) | what Vana may remember: memory kinds, settings-as-memories and their defaults, provenance, recall, the drawer |
| [`conversation.md`](conversation.md) | the two conversation kinds, ownership of history, openers, persistence, rewind |

Lifecycle: PROPOSED → RATIFIED by Xuan; dated RULED stamps for post-ratification additions;
[`../../DEVIATIONS.md`](../../DEVIATIONS.md) for observed-but-unratified behaviour. The wire shapes these rules
ride on are frozen as `contract-v1` (`../../../implement_mealplanning/02-contract.md`) — additive changes only.

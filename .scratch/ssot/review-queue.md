# Review queue

Built 2026-09-26 during the SSOT overhaul. These are the items still waiting on a decision, taken
from the proposals file (`.scratch/mealplanning/decisions.md`), the record's amended cards, and the
ticket files. None of them is in the SSOT. Lee answers them one at a time with AskUserQuestion,
and each answer becomes an approved card in the right section. Duplicates are merged; the ids
in brackets are the other cards folded into the same question.

## Meal planning


## Paywall


## Shopping list


## Cost cutting


## Miscellany


## Built 2026-09-26, live on dev

All six are merged on `mealplanning` with their tests green (Flutter 401, Deno 32). Lee said go on 09-26, and the migration plus all eight functions are now on dev; prod follows the release sequence.
- Apply migration `20260926070000_pro_grants_source.sql` to dev, then deploy `grace-claim` and `redeem-code` (mp-615).
- Deploy `describe-meal` and `analyze-meal-photo` (mp-672), and `vana-action`, `vana-chat`, `vana-day-notes` and `jade-chat` (mp-683, which imports `plan.ts`).
- mp-561, mp-600 and mp-682 are app-side and ship with the next build. If Sanity overrides `meal_planning.plan_bar_replaced`, change it there too.
- mp-672 used these meal-type windows because no ruled ones existed: breakfast 04:00–10:30, lunch 10:30–14:30, snack 14:30–17:00, dinner 17:00–21:30, then snack. Near a boundary the food decides. Lee can change them.

## Waiting on Lee or Xuan (tasks and wording, not decisions)

These are also on the page as the Open tasks reference document (`docs/ssot/decisions/open-tasks.md`).

- mp-513 · Are the drafted trial and renewal lines on the paywall final, or does Xuan rewrite them?
  Recommend: Xuan signs them off as they are.
  Why pending: waits on Lee and Xuan's approval of the wording.
- mp-590 · For Xuan: does the glass paywall sheet have a grabber, and what top gap and slide-in timing does it use?
  Recommend: Ask Xuan; keep the build as is until she answers.
  Why pending: waits on Xuan.
- mp-656 · Does RevenueCat's Test Store swap to the four new `me_pro_*` products?
  Recommend: Yes, so testing matches what we sell.
  Why pending: open since paywall wave 9.
- Ticket paywall 13 · The phone run of the store checks on both stores.
  Recommend: Lee runs it before the 10-01 launch.
  Why pending: waiting on Lee (a task, not a decision).
- mp-680 · When an athlete has lowered their own carb rate, what does the during-run band show?
  Recommend: The band stays the engine's, and the screen stops flagging their own rate as low.
  Why pending: open since testing wave 22; a fuelling question for Xuan.
- Ticket kroger-delivery 02 · One item was sent to Lee's real Kroger cart on 09-10.
  Recommend: Lee confirms it arrived, then close the ticket.
  Why pending: a check only Lee can do (not a decision).

## Done

- Decided by Claude from code and past rulings (09-26): mp-512/526 → 430; 524 → 521; 561 → 555; 667 → 417; 614/616 → 280; 600/660/685 → 598; 615/617/618/619 → 495; 654 → 505; 655 → 429; 684 → 609; 689 → 494; 566 → 493. Kept as built, no card (detail): 582 admin with no plan sees no status card, 690 welcome-back line, 527 no prompt padding, 518 adding a saved meal waits for its ingredients, 597 status line stays, 552 sandbox events count on prod (Lee's ruling: the prod webhook stays unfiltered), 576 phone gets the wallet row but never shows dollars (mp-572), 578 test pack hidden, 522 weekly view uses the gateway's charge only (mp-521), 577/548 cache and picker targets are measured as conversation averages per model step. Ticket mealplanning 21: the release gate is the paywall 13 store checks, since Lee won't run the wizard. mp-672 decided, listed under needs building.
- Decided by Claude: mp-682/683 → 675, mp-669 → 244; ticket mealplanning 12 settled by mp-223 (cook day and debrief come as the opener, never as moments).
- Built as described, recorded (checked in code): mp-419 → 022, 425 → 232, 427/547 → 245, 546 → 214, 681/687 → 675, 688 → 678, 692/695 → 244. mp-693 (Disconnect Kroger confirms first) is built UI detail, not a card.
- Obsolete list: dropped (Lee, 2026-09-26).
- mp-421 → mp-223 · mp-424 → mp-232 (Lee, 2026-09-26).

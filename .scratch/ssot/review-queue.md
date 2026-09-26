# Review queue

Built 2026-09-26 during the SSOT overhaul. These are the items still waiting on a decision, taken
from the proposals file (`.scratch/mealplanning/decisions.md`), the record's amended cards, and the
ticket files. None of them is in the SSOT. Lee answers them one at a time with AskUserQuestion,
and each answer becomes an approved card in the right section. Duplicates are merged; the ids
in brackets are the other cards folded into the same question.

## Meal planning

- [ ] mp-419 · Does the memory system as built stand? Vana sees past chats as a short line of what the athlete said, summarises long chats twenty messages at a time, and caps what she knows at about 1,500 tokens.
  Recommend: Yes. It replaces the older "Vana reads back the last chat" cards (mp-020, 023, 277, 288).
  Why pending: it was proposed after the build and would reverse older approved cards.
- [ ] mp-421 · When Vana speaks first, does she go in this order: a live fuelling moment, then the screen underneath, then the personal opener? And does a request for a plan show a button to the planning screen?
  Recommend: Yes to both.
  Why pending: proposed after waves 4-5, never approved.
- [ ] mp-424 · Does the athlete set the plan's start day and a length of 3 to 14 days, with each plan keeping the period it was made for?
  Recommend: Yes.
  Why pending: proposed after wave 4, never approved.
- [ ] mp-425 · With batch cooking on, is a plan three meals per meal type, each cooked in enough servings for a third of the period (3 servings for 7 days, 5 for 14)?
  Recommend: Yes.
  Why pending: proposed after wave 5, never approved.
- [ ] mp-427 · Do admins get a Good/Not good review box on every meal, and does every recipe say where its steps came from in one line?
  Recommend: Yes; typed feedback to Vana keeps going to Wiredash.
  Why pending: proposed after waves 1-2, never approved.
- [ ] mp-546 · When Vana hands the athlete off to a screen, does she write her one sentence first and then stop?
  Recommend: Yes. It saves a model step on every hand-off.
  Why pending: proposed in ai-cost wave 4; reverses mp-015/016.
- [ ] mp-547 · When a complaint also asks a question ("too spicy, is there a milder one?"), does Vana save the feedback and still answer?
  Recommend: Yes; a plain complaint alone ends the turn silently.
  Why pending: proposed in ai-cost wave 4; reverses mp-246.
- [ ] mp-681 · Can the athlete add new meals to an earlier plan?
  Recommend: No. Servings and remove are enough; to add meals, use the plan again and add them to the new draft.
  Why pending: open question from testing wave 22.
- [ ] mp-682 · What does the note on a replaced, never-confirmed draft promise?
  Recommend: Change the words to "You confirmed a different plan for this week. This draft stays here in this conversation."
  Why pending: open question from testing wave 23.
- [ ] mp-683 · In a conversation whose draft was replaced, what does picking a meal do?
  Recommend: It starts a fresh draft for this week in the same conversation.
  Why pending: open question from testing wave 23.
- [ ] mp-687 · Does Previous plans list only confirmed plans, where the athlete can rename, delete, change servings, remove a meal, or use the plan again?
  Recommend: Yes.
  Why pending: proposed after testing wave 22.
- [ ] mp-688 · Does a meal with missing nutrition numbers stay in Browse but say it can't go in a plan?
  Recommend: Yes; every path into a plan refuses it.
  Why pending: proposed after testing wave 24.
- [ ] Ticket mealplanning 12 · Should Vana speak first about a cook day with no check-in, or a finished week with no debrief?
  Recommend: Park it until the fuelling moments have been lived with; it needs its own grill.
  Why pending: ticket marked needs-grilling.

## Paywall

- [ ] mp-512 · Does an account with Pro from a Grant (a code or the grace month) get the same monthly AI budget as a paying one?
  Recommend: Yes, the same budget.
  Why pending: open since paywall wave 1.
- [ ] mp-513 · Are the drafted trial and renewal lines on the paywall final, or does Xuan rewrite them?
  Recommend: Xuan signs them off as they are.
  Why pending: waits on Lee and Xuan's approval of the wording.
- [ ] mp-561 · When an old install's grace-month claim fails, does the app retry it, or does Lee grant it by hand?
  Recommend: The app retries at startup for accounts created before the flip.
  Why pending: open since paywall wave 3.
- [ ] mp-667 · Does signing up on prod ask for the 6-digit code we email? If yes, is it asked before or after the grace month is claimed? [mp-563]
  Recommend: Yes, after the grace month is claimed, so an old install never loses its month.
  Why pending: open since 09-24; email verification is not set up.
- [ ] mp-566 · On a short phone, do the paywall's plan cards stay stacked or sit side by side?
  Recommend: Stacked; the features fade under the ⋯ button.
  Why pending: design call, open since paywall wave 3.
- [ ] mp-590 · For Xuan: does the glass paywall sheet have a grabber, and what top gap and slide-in timing does it use?
  Recommend: Ask Xuan; keep the build as is until she answers.
  Why pending: waits on Xuan.
- [ ] mp-582 · What does an Admin with no plan see on the Subscription screen?
  Recommend: "Admin access", with no Upgrade button.
  Why pending: open since paywall wave 4.
- [ ] mp-600 · When a coach redeems their own code, or an athlete enters a coach's code, does the app refresh straight away so coach mode or the pending request shows at once? [mp-601]
  Recommend: Yes, refresh at once in both cases.
  Why pending: open since paywall wave 6.
- [ ] mp-660 · What does a second code from the same coach do for an athlete already paired or pending with them?
  Recommend: Accept it and say the request is already pending.
  Why pending: open since testing wave 5.
- [ ] mp-685 · When an account is deleted, do the codes it redeemed still count as used?
  Recommend: Yes; a one-use giveaway stays used after the account is deleted.
  Why pending: proposed after testing wave 19.
- [ ] mp-614 · Does every way into the paywall replace the whole app, with no back swipe?
  Recommend: Yes; the only ways out are subscribe, restore, redeem a code, sign out or delete the account.
  Why pending: proposed after paywall wave 7.
- [ ] mp-615 · How does the Subscription screen name a Grant: the server stores its source, or the app guesses from its length? [mp-617]
  Recommend: The server stores the source, so a coach's own 30-day code is no longer called "Grace month".
  Why pending: today the app guesses from the length, which mislabels coach codes.
- [ ] mp-618 · What is "a coach's gift" on the Subscription screen?
  Recommend: The Pro a coach gets from their own code.
  Why pending: open since paywall wave 7.
- [ ] mp-619 · When a Grant outlasts a store subscription, does Manage subscription still show?
  Recommend: Yes; show it whenever any purchase came from a store.
  Why pending: open since paywall wave 7.
- [ ] mp-616 · Once Pro has ended, does the Subscription screen say "Everything you saved is kept for when you subscribe again"?
  Recommend: Yes.
  Why pending: proposed after paywall wave 7.
- [ ] mp-654 · Do the log-meal Analyze button and the Vana launcher keep their own check that opens the paywall, or leave it to the server's refusal?
  Recommend: Keep the app's own check; it is instant and works offline.
  Why pending: open since paywall wave 8.
- [ ] mp-655 · Outside the US, does Pro cost whatever each store converts $24.99 to?
  Recommend: Yes.
  Why pending: proposed after paywall wave 9.
- [ ] mp-684 · Does a renewing subscriber keep Pro for 15 minutes past the period's end, on the server and in an open app, while cancelled plans, trials that won't convert and Grants end on time? [mp-686]
  Recommend: Yes.
  Why pending: proposed after testing waves 19-24.
- [ ] mp-689 · Does Delete Account warn that a store subscription keeps renewing until it is cancelled in the store?
  Recommend: Yes.
  Why pending: proposed after testing wave 24.
- [ ] mp-690 · Does a returning subscriber see "Welcome back to Mealvana Endurance!"?
  Recommend: Yes.
  Why pending: proposed after testing wave 24.
- [ ] mp-656 · Does RevenueCat's Test Store swap to the four new `me_pro_*` products?
  Recommend: Yes, so testing matches what we sell.
  Why pending: open since paywall wave 9.
- [ ] Ticket paywall 13 · The phone run of the store checks on both stores.
  Recommend: Lee runs it before the 10-01 launch.
  Why pending: waiting on Lee (a task, not a decision).

## Shopping list

- [ ] mp-695 · Does the Shopping tab open this week's confirmed plan's list, falling back to the newest hand-made list?
  Recommend: Yes.
  Why pending: proposed after testing wave 20.
- [ ] mp-669 · Can the athlete delete the confirmed plan's own list, and what shows after a delete?
  Recommend: No; it can only be cleared or its items ticked.
  Why pending: open since testing wave 11.
- [ ] mp-692 · Is a plan's list named by its week ("Week of Sep 20"), with Previous lists marking "This week's plan"?
  Recommend: Yes.
  Why pending: proposed after testing wave 24.
- [ ] mp-693 · Does Disconnect Kroger ask for confirmation first?
  Recommend: Yes.
  Why pending: proposed after testing wave 24.
- [ ] Ticket kroger-delivery 02 · One item was sent to Lee's real Kroger cart on 09-10.
  Recommend: Lee confirms it arrived, then close the ticket.
  Why pending: a check only Lee can do (not a decision).

## Cost cutting

- [ ] mp-526 · Does a photo that turns out not to be food count against the athlete's budget?
  Recommend: No, we carry its cost.
  Why pending: open since ai-cost wave 3.
- [ ] mp-527 · Do we pad the meal-logging instructions so they are long enough to be cached?
  Recommend: No; the photo cap already carries the saving.
  Why pending: open since ai-cost wave 3.
- [ ] mp-577 · Is the 80% cache-read target a floor for every turn, or an average over the conversation?
  Recommend: An average over the conversation.
  Why pending: open since ai-cost wave 5.
- [ ] mp-518 · When a saved meal is added, does the turn wait for its ingredient list, or does it build in the background?
  Recommend: Build it in the background and show the dish as one line until it is ready.
  Why pending: open since ai-cost wave 2.
- [ ] mp-597 · When a tap runs without the model, does the status line say "Working on it…" instead of "Vana is thinking"?
  Recommend: Yes.
  Why pending: open since ai-cost wave 6.
- [ ] mp-552 · On prod, does a Sandbox (tester) purchase add a real month's budget?
  Recommend: It adds the month but no top-up packs.
  Why pending: open since ai-cost wave 4.
- [ ] mp-576 · Does the phone never receive the budget in dollars at all, not just never show it?
  Recommend: Yes; the server sends only the share used.
  Why pending: the screen is done; the server side needs a ticket.
- [ ] mp-578 · What is the $0.99 test pack called, or is it hidden?
  Recommend: Hide it from the top-up sheet.
  Why pending: open since ai-cost wave 5.
- [ ] mp-522 · Does the weekly cost report fill in calls the Gateway never priced, using our own price table?
  Recommend: Yes, so the weekly total is whole.
  Why pending: open since ai-cost wave 3.
- [ ] mp-548 · Is the picker saving measured per model step rather than per call?
  Recommend: Per model step (it met the 35,000-token target).
  Why pending: open since ai-cost wave 4.

## Miscellany

- [ ] mp-524 · Can a database job call an alert function, or do both cost alerts move to a scheduled function or a Sentry cron monitor?
  Recommend: Move them to a scheduled function, as the playbook says.
  Why pending: the cron Lee rejected (mp-523) was built anyway.
- [ ] mp-672 · Does a logged meal's type come from the food or from the time it was eaten?
  Recommend: The time first, with the food breaking a tie near a boundary.
  Why pending: open since testing wave 14.
- [ ] mp-680 · When an athlete has lowered their own carb rate, what does the during-run band show?
  Recommend: The band stays the engine's, and the screen stops flagging their own rate as low.
  Why pending: open since testing wave 22; a fuelling question for Xuan.
- [ ] Ticket mealplanning 21 · Does the release gate (sandbox run, playbook P3c) stand, given Lee won't run the wizard?
  Recommend: Replace it with the paywall 13 store checks.
  Why pending: stays on paper until Lee or Xuan rules.

## Approved but not built

These stay approved; no ticket builds them yet.

- mp-255 · The meal library stays on the server; plans and memories sync only when needed.
- mp-540 · Once the free week starts, an athlete with notifications off gets one line asking to turn them on.
- mp-543 · Prod's webhook takes every event type from the cutover.
- mp-544 · A giveaway code tags the account.
- mp-608 · Vana reads batch cooking and coverage from settings and never asks about them while planning.
- mp-620 · After every picker, the chips come from the plan as it stands.

## Obsolete, drop unless you object

- mp-236, 239, 241, 255, 260, 458 (amended cards): each only applies "the newest approval wins"; the overhaul applies that rule directly.
- The 19 drafted folds from the 09-22 clarity pass: the overhaul replaces them.
- mp-321 · the order of the prod Pro cutover: settled by mp-543 and the paywall wave 8-9 prod setup.
- mp-514 · open the paywall or show an error on refusal: settled by paywall ticket 12 (refusals open the paywall) and the no-read-only ruling of 09-23.
- mp-567 · is the free week set up on the store products: a fact to check in paywall ticket 13, not a decision.
- mp-662, 663, 664 · sandbox override, webhook event list, day-five reminder in sandbox: testing process, settled in the terminal (feedback_testing_off_the_ssot).
- mp-422, 423, 426, 428, 516 · formula editor fields, launcher as built, chip wiring, fifteen engineering loose ends, which day notes rewrite: implementation detail; the build stands.
- mp-691, 694, 696 · notification prompts, AI note saved as the meal's note, timeline card merging: outside the new work (Lee's examples d and e).
- Ticket paywall 11, 12, 17 cards (read-only shell): undone by tickets 19-20 after the 09-23 no-read-only ruling.

# Proposed decisions: Meal planning and Vana

Feature: mealplanning
Feature name: Meal planning and Vana
Last extracted: 1dedc493

## mp-032 · Each turn replays at most the last 20 messages, with the episode prepended
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-032.svg
- screen: none (algorithm/data)
- source: spec.md; ticket 03

**Context.** Every turn sends the conversation so far back to the model. A long planning conversation can run to dozens of messages, and replaying all of them costs tokens and time. Each conversation also gets an episode, a one-sentence summary stored as a Memory.

**Question.** How much history a turn carries.

**Decision.** Each turn replays at most the last twenty messages. When the cap bites, the conversation's episode sentence is prepended once so the model still knows how it started.

**Why.** Long conversations must stay fast and coherent without replaying everything.

**What else was considered.** A larger cap, or no cap. Both lost on cost and speed.

**What it touches.** vana-chat replayHistory.

> 2026-09-14 held for review under mp-217 (Lee: "let's do some research on how other chatbots approach this and if they summarize and when and how many messages they keep, etc. while keeping costs los")

## mp-033 · A mid-conversation episode is written in the background when the cap first bites
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-033.svg
- screen: none (algorithm/data)
- source: ticket 03; memory 09-10

**Context.** The prepend above needs an episode to exist. Episodes were only written by the read-back of a finished conversation. So a conversation still open at twenty messages had no episode and the front of it was simply dropped. The prepend had never fired.

**Question.** When to write an episode for a conversation that is still going.

**Decision.** When a conversation crosses twenty messages with no episode, the episode half of the extractor runs after the reply is sent and the next turn picks it up. One Haiku call per conversation.

**Why.** The prepend had never fired because episodes were only written for finished conversations.

**What else was considered.** Write the episode synchronously and delay the reply. It lost because the athlete would wait on a call they cannot see.

**What it touches.** chat.ts replayHistory, extract.ts writeOpenEpisode.

> 2026-09-14 held for review under mp-217 (Lee: "again, is this the best we can do?  is there another way of handling all of this?")

## mp-034 · The open episode reads the opening half of the transcript
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-034.svg
- screen: none (algorithm/data)
- source: ticket 03; memory 09-10

**Context.** The mid-conversation episode has to summarise what the model is about to lose, which is the start of the conversation. Feeding the whole transcript produced a list of recent topics with the opening gone, and the eval failed. There is one call to spend per conversation.

**Question.** Which part of the transcript the episode reads.

**Decision.** The episode is written from the first half of the transcript, with a prompt that asks for names and numbers. Past about forty messages the front is lost again, which the one-call budget accepts.

**Why.** The whole transcript produced a list of recent topics with the opening gone, and the eval failed.

**What else was considered.** Read only the dropped rows, which lost as too thin. Read the whole transcript, which lost the opening.

**What it touches.** extract.ts.

> 2026-09-14 held for review under mp-217 (Lee: "ahh I think this should be rethought alongside everything else")

## mp-035 · The open episode never stamps read-back and never overwrites
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-035.svg
- screen: none (algorithm/data)
- source: ticket 03

**Context.** The read-back of a finished conversation stamps it as read so it is never mined twice. The mid-conversation episode is only half of that job. The margin notes are still owed once the conversation ends. Two writers can also reach the same conversation.

**Question.** How the open episode fits beside the full read-back.

**Decision.** The open episode does not mark the conversation as read back, because margin notes are still owed later. If the read-back or a concurrent turn already wrote an episode, that one stands.

**Why.** One keyed row, one recall mechanism, no lost notes.

**What else was considered.** none recorded

**What it touches.** extract.ts.

> 2026-09-14 held for review under mp-217 (Lee: "again we need to rethink what we're doing here")

## mp-036 · Episode reads take the newest row and there is no unique index yet
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-036.svg
- screen: none (algorithm/data)
- source: ticket 03

**Context.** Two writers can race and each insert an episode row for the same conversation. The read expected exactly one row, errored on two, and the episode was lost for good. A database rule allowing one episode per conversation would close the race. That is a schema change on a table already on dev.

**Question.** Whether to change the schema now or make the read tolerant.

**Decision.** Reads take the newest episode row when there is more than one. A partial unique index would close the race but was left out as a schema change.

**Why.** A single-row read used to error on two rows and lose the episode for good.

**What else was considered.** Add the partial unique index now. It lost as a schema change outside the ticket.

**What it touches.** memory.ts.

> 2026-09-14 held for review under mp-217 (Lee: "again we need to rethink this episode part and what we are doing")

## mp-038 · The context says what they said last, not their schedule
- category: Vana's memory
- status: open
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-038.svg
- screen: none (algorithm/data)
- source: memory 09-11; commit 1dedc493

**Context.** The context block has a MEMORIES section. Episodes were listed there beside the margin notes. An episode is a summary of a conversation, so the opener read it back as "last time we planned Tuesday's ride and Thursday's swim". That is a schedule, not a memory of the person.

**Question.** How the context presents past conversations.

**Decision.** The context gains a LAST TALKS line holding what the athlete said in recent conversations. The MEMORIES block holds only non-episode notes.

**Why.** Episodes in the memories block read as a schedule read-out instead of a memory of the person.

**What else was considered.** none recorded

**What it touches.** context.ts.

> 2026-09-14 held for review under mp-217 (Lee: "again, we need to discuss this episode thing again")

## mp-210 · What context each Vana entry point gets
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-002
- image: none
- caption:
- screen: Vana chat, events page, coach formula feedback
- source: Lee on the page 2026-09-13, amending mp-002

**Context.** Vana is reached from several places: the sheet over any screen, the Plan tab, the full-screen chat, a formula's coach feedback, and the events page. Today the sheet and Plan tab hand her the Doll plus a one-line Situation naming the screen. The formula and events entry points were built earlier and hand her something different, or less. The question is what each entry point owes her.

**Question.** Vana has different entry points. Coach formulas will have different conversations to meal planning to general chat. Each entry point needs different context. The formulas conversation needs formula context, and the events page needs the upcoming events. We have not figured this out enough and need to think it through. All contexts should have the Voodoo Doll of the given user.

**Why.** Without a rule per entry point, each screen invents its own context and Vana knows different things depending on where she was opened.

**What it touches.** Situation resolver, context builder, coach formula feedback, events page, sheet.

> 2026-09-15 answered by mp-273

## mp-211 · Which entry points continue a conversation and which start a new one
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-003
- image: none
- caption:
- screen: Vana chat, Vana sheet, Plan tab
- source: Lee on the page 2026-09-13, amending mp-003

**Context.** Vana can be reached from the sheet over any screen, the Plan tab's note, the New meal plan button, the full-screen chat, and the history list. Today the sheet continues one conversation per day, and New meal plan opens a fresh planning conversation. The rules for the other entry points were never written down together.

**Question.** We need to figure out conversation histories. When we press New meal plan, or ask a question cold by pressing a button somewhere, the expectation is that this is a new conversation and not an existing one. We should still be able to list and see prior questions we have asked.

**Why.** If two entry points disagree about whether they continue or start fresh, the athlete lands in a conversation they did not expect.

**What it touches.** Ambient conversation controller, chat route, history list, opener.

> 2026-09-15 answered by mp-275

## mp-215 · Is sending the whole context every turn wasteful
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-019
- image: none
- caption:
- screen: none (algorithm/data)
- source: Lee on the page 2026-09-13, rejecting mp-019

**Context.** The model keeps nothing between calls. Every turn is a fresh request that carries the persona, the athlete context block, and the recent history, so the model reads the context again each time. That is how every chat model works, including the one behind this page. Provider prompt caching can make a repeated prefix much cheaper without changing what is sent. The alternative is to leave the context out and fetch pieces by tool when the model asks, which saves tokens but makes Vana forget things unless she remembers to ask.

**Question.** Do we send the entire context each time? Is this not wasteful? Does Claude not remember this context within a conversation?

**Why.** The decision on cost per turn depends on whether the repeated block can be cached and on how often a turn actually needs it.

**What it touches.** vana-chat context builder, model call options.

> 2026-09-15 answered by mp-276

## mp-216 · How long the opener waits for the read-back
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-009
- image: none
- caption:
- screen: none (algorithm/data)
- source: Lee on the page 2026-09-13, rejecting mp-009

**Context.** When a conversation opens, the previous one is read back in the background to pull out new notes. The opener wants those notes. The shipped rule waited up to 3.5 seconds, then went ahead with the athlete's last words in place of the notes. Lee rejected the fixed wait as too deterministic and asked for a revisit.

**Question.** This is too deterministic. Why are we doing this? We need to revisit it.

**Why.** The opener is the first thing the athlete reads. A wrong wait either delays it or makes it forget last time.

**What it touches.** Opener path in vana-chat, read-back extraction.

> 2026-09-15 answered by mp-278

## mp-217 · How Vana remembers, within and across conversations
- category: Vana's memory
- kind: question
- status: answered
- linked: mp-032
- image: none
- caption:
- screen: none (algorithm/data)
- source: Lee on the page 2026-09-14, on mp-009, mp-026, mp-032 to mp-036, mp-038

**Context.** The model remembers nothing between turns. Every turn is a fresh request carrying the persona, the athlete context, and whatever history the app chooses to resend. Everything that looks like memory is plumbing the app built: a 20-message replay window, a one-sentence episode written mid-conversation and again at the end, a read-back of the previous conversation when the next one opens, a 3.5 second wait for that read-back, and a LAST TALKS line in the context. Seven decisions describe those pieces: mp-009 (rejected), mp-026 (rejected), and mp-032 to mp-036 and mp-038, now held. Lee reviewed them together and asked for a rethink and research before any of them is treated as settled.

**Question.** Do we need previous-conversation extraction like this? We need to remove plumbing like this if it exists. If there is a new conversation, we should have summarised the earlier one sometime before that. Research how other chatbots approach this: whether they summarise, when, how many messages they keep, and how they keep costs low. Is this the best we can do, or is there another way of handling all of this?

**Why.** These pieces decide what Vana knows on any given turn and what each turn costs. A wrong strategy either makes her forget or makes every turn expensive.

**What it touches.** vana-chat history replay, extract.ts, the episode row, the opener path, the context builder. Research: docs/research/conversation-memory-strategies.md (2026-09-14).

> 2026-09-15 answered by mp-277

## mp-267 · What moving from freemium to a trial requires
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-266
- image: none
- caption:
- screen: Paywall
- source: Lee on the page 2026-09-14, on mp-052

**Context.** The app sells AI credit bundles and a Pro subscription, with meal planning behind Pro and general chat costing a credit for free users. Lee is replacing that with a seven-day trial of the whole app followed by purchase. The store products, the RevenueCat offering, the gate flag and the entitlements table were all built for free and Pro. Lee added on 2026-09-14: the app-side entitlements table goes away under the trial model, and meal planning does not ship until the trial exists.

**Question.** We need to discuss what we need to do in order to move away from a freemium to a purchase model. What are the store products and introductory offers, how does RevenueCat run the trial, what can an expired trial still open, what happens to the credits system, and what happens to accounts that exist today?

**Why.** Every paywall decision on this page was written for free and Pro. Until this is answered the three Pro cards cannot be approved as written.

**What it touches.** Store products, RevenueCat offering, entitlements table, gate flag, credits system, Pro screen, mp-254 to mp-256.

> 2026-09-14 opened from Lee's amendment of mp-052
> 2026-09-14 context extended from Lee's verdicts on mp-250 and mp-255
> 2026-09-15 answered by mp-279

## mp-287 · What the coach rule is, once the paywall document arrives
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-286
- image: none
- caption:
- screen: none (algorithm/data)
- source: grill 2026-09-15

**Context.** mp-286 gives coaches nothing special for now. Lee has a rule for coaches in mind that depends on a paywall document Xuan is providing.

**Question.** We have something to say about coaches, but that will rely on a paywall document that Xuan will provide. What do coaches pay, and what does the paywall say to them?

**Why.** Coaches bring athletes in; whether the gate stands between a coach and their athletes decides how the app is sold to teams.

**What it touches.** Coach registration, the app gate, the paywall, mp-286.

> 2026-09-15 opened in the grill, waiting on Xuan's paywall document

## mp-300 · Ticket 22: Meal icons come off the tiles
- category: Tickets
- status: proposed
- ticket: 22
- depends: mp-145
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: Plan tiles, where the icons come off
- screen: Plan tab
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the build drew a classified icon on every meal tile that had no photo. mp-145 keeps the classifier and its stored key and rules the icons off. First of eleven follow-on tickets (22 to 32) cut on 2026-09-15 for the approved rulings the build does not yet match; this one has no blockers.

**Question.** Is removing the drawn icons its own small ticket, first in the follow-on set?

**Decision.** A meal with no photo shows a plain placeholder on the Meals tab, the plan tiles, the plan bar and the review sheet. The 23-key classifier and the stored icon key on library, saved and plan meals stay exactly as they are. The glyph set and the icon tile widget are deleted.

**Why.** It is a removal with goldens to prove it, small enough to go first, and it touches the review sheet that 29 and 30 rebuild, so it goes ahead of them.

**What else was considered.** Folding it into the cooking-period ticket; it lost as unrelated work in a large ticket.

**What it touches.** lib/features/meal_planning/presentation/widgets/meal_card.dart, lib/features/meal_planning/presentation/widgets/plan_tile.dart, lib/features/meal_planning/presentation/widgets/plan_bar.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart, lib/features/meal_planning/presentation/widgets/meal_icon_glyphs.dart

**Details.** 
- [ ] No tile, card, plan bar row or review sheet row draws an icon; a missing photo shows the plain placeholder.
- [ ] The classifier, the icon key and its copy on add and swap are untouched (existing tests still pass).
- [ ] The glyph file and the icon tile widget are removed; goldens for the plan tile and the meal card are regenerated.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, f84827b9

## mp-301 · Ticket 23: The launcher is an allow-list of three screens
- category: Tickets
- status: proposed
- ticket: 23
- depends: mp-264
- image: docs/ssot/decisions/images/mealplanning/timeline-launcher.png
- caption: The launcher on the Timeline, one of three screens
- screen: Launcher
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the launcher rule was built as a deny-list: an auth-and-paywall exclusion list plus thirty flow-screen patterns, with route-name workarounds on three pushed screens. mp-264 replaces that with an allow-list of three routes. Second of the follow-on set; no blockers.

**Question.** Is replacing the deny-list with the three-route allow-list one ticket?

**Decision.** The launcher appears on the main tabs screen, the meal-planning screen and coach formulas, and nowhere else. Any page pushed over one of those hides it without naming itself. The flow-pattern list, the gate-prefix list and the three route-settings workarounds are deleted.

**Why.** One rule file and its test, plus three deletions; it can run in the first wave beside anything.

**What else was considered.** Keeping the deny-list and adding coach formulas; rejected by mp-264.

**What it touches.** lib/features/meal_planning/domain/vana_launcher_rule.dart, test/features/meal_planning/domain/vana_launcher_rule_test.dart, lib/shared/screens/food_detail_screen.dart, lib/features/events/presentation/screens/event_form_screen.dart

**Details.** 
- [ ] The rule is an allow-list of the three routes; every other route, and any route pushed over one of the three, returns no launcher (rule tests).
- [ ] The flow-pattern list, the gate-prefix list and the RouteSettings workarounds are gone (the build-meal screen's workaround included; that file is otherwise untouched).
- [ ] Simulator: launcher on the Timeline, the Food tab and the formula library; none on a pushed form.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture reused from docs/ssot/decisions/images/mealplanning/timeline-launcher.png

## mp-302 · Ticket 24: Testers switch the dev buttons off in Settings
- category: Tickets
- status: proposed
- ticket: 24
- depends: mp-271
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption: Settings, where the dev switch goes
- screen: Settings
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and on the simulator the dev accessibility and wrench buttons cover the launcher. mp-271 rules a per-tester switch in Settings, dev mode only. Third of the follow-on set; no blockers.

**Question.** Is the dev-mode switch its own small ticket?

**Decision.** In a dev build, Settings shows a switch that turns the accessibility and wrench buttons off and on for that tester on that device. It defaults to on, is remembered across launches, and is absent from release builds. No build-time flag.

**Why.** It is one persisted flag read by two widgets, and it unblocks every simulator capture that the launcher sits under.

**What else was considered.** A build flag; rejected by mp-271.

**What it touches.** lib/features/settings/presentation/screens/settings_screen.dart, lib/shared/widgets/root_app_widget.dart, lib/shared/widgets/environment_indicator.dart, test/features/settings

**Details.** 
- [ ] A dev-only switch in Settings, default on, persisted per device (controller test through the real notifier).
- [ ] Off hides the accessibility tools and the wrench; on restores them without a restart.
- [ ] Release builds show no switch and no buttons, as today.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, 43496fed

## mp-303 · Ticket 25: An admin can review any meal
- category: Tickets
- status: proposed
- ticket: 25
- depends: mp-144
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption: Meal detail, where the admin box goes under the thumbs
- screen: Meal detail
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the meal library's quality is judged by nobody in the app. mp-144 clause 3 gives a signed-in admin a comment box on every meal page; the rest of mp-144 is built. The app has no admin role today. Fourth of the follow-on set; no blockers.

**Question.** Is the admin comment box, with the smallest admin role that can carry it, one ticket?

**Decision.** A signed-in admin opens any meal and sees a comment box under the thumbs: is this a good recipe, and why. Each comment lands in a review table with the meal, the admin and the date, for the team to read. Athletes never see the box. Admin is a boolean on the user record, set by hand in the database, read by the server for the insert policy and by the client to show the box; there is no admin UI to grant it.

**Why.** It is the last clause of mp-144 and the only one unbuilt; the hand-set flag is the least role machinery that still keeps athletes out.

**What else was considered.** Reusing the tester device flag (per device, not per person); a full roles table (more than the box needs).

**What it touches.** supabase/migrations/20260916120000_meal_reviews_and_admin_flag.sql, lib/features/meal_planning/presentation/screens/meal_detail_screen.dart, lib/features/meal_planning/application/meal_detail_controller.dart, lib/features/meal_planning/data/meal_review_repository.dart, test/features/meal_planning/application/meal_detail_controller_test.dart

**Details.** 
- [ ] Migration: an is_admin boolean on users (default false) and a meal_reviews table whose insert policy requires it.
- [ ] The box shows only when the signed-in user is an admin; a review writes one row (controller test through the real notifier).
- [ ] The dev account used for captures is set admin by hand and the simulator shows the box; a second dev account does not.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, 43496fed

## mp-304 · Ticket 26: Typed feedback reaches the same inbox as a shaken report
- category: Tickets
- status: proposed
- ticket: 26
- depends: mp-245, mp-248
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-304.svg
- screen: none (algorithm/data)
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and feedback she saves goes to a table the team must remember to read while shaken reports go to Wiredash. mp-245 clause 6 says the feedback tool also files a Wiredash entry. The server has no Wiredash client today, and Wiredash may offer no server-side ingest. Fifth of the follow-on set; no blockers.

**Question.** Is bridging typed feedback into Wiredash one ticket, with a stop if no ingest path exists?

**Decision.** A complaint typed to Vana appears in the same Wiredash inbox as a shaken report, with the athlete's words, the sentiment and the conversation id. The ticket's first step finds the ingest path (a Wiredash server API, or the client filing silently when it receives the feedback-saved part); if neither exists, the ticket stops and puts the question on the page instead of building a substitute.

**Why.** One inbox is the whole point of mp-245; the guard keeps an agent from inventing a second feedback system.

**What else was considered.** A scheduled export from the feedback table into Wiredash; deferred until the ingest question is answered.

**What it touches.** supabase/functions/_shared/vana/tools.ts, supabase/functions/tests/vana/feedback_ack.test.ts, lib/features/feedback/data/feedback_repository.dart, lib/shared/widgets/shake_to_report.dart

**Details.** 
- [ ] The ingest path is found and named in the ticket, or the ticket stops with an open question on the page.
- [ ] A saved feedback row produces one Wiredash entry carrying words, sentiment and conversation id (seam test with a fake client).
- [ ] The feedback-saved acknowledgement is unchanged for the athlete.

> 2026-09-15 proposed from the ticket breakdown

## mp-305 · Ticket 27: One sheet height, and hand-offs instead of doing it in the sheet
- category: Tickets
- status: proposed
- ticket: 27
- blocked: 15, 26
- depends: mp-265, mp-061
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the sheet was built with three heights, auto sizing and custom drag thresholds. mp-265 rules one height and turns every deterministic action into a hand-off button to the app's own screen. Sixth of the follow-on set; it follows 15 because both edit the sheet's host.

**Question.** Is the one-height sheet plus the hand-off part one ticket, blocked by 15?

**Decision.** The sheet opens at one standard height and its contents scroll; the close button or a plain drag down dismisses it; nothing grows on send or resizes while Vana streams; full screen happens only from its button. When the athlete asks for something the app has a screen for, Vana answers with a hand-off button (meal plan to the meal-planning page, fuelling a workout to new activity, planning an event to the event screen, carb loading to the picks) instead of doing it in the sheet; the button is a new part in the wire contract that the app renders.

**Why.** The height change and the hand-off part are the two halves of "the sheet is a bigger view of nothing": one demo shows both.

**What else was considered.** Keeping auto height for one-line openers; rejected by mp-265.

**What it touches.** lib/shared/widgets/kyle_design/navigation/vana_sheet.dart, lib/features/meal_planning/presentation/widgets/vana_companion.dart, lib/features/meal_planning/presentation/widgets/vana_part_renderer.dart, supabase/functions/_shared/vana/contracts.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/tests/vana/contract.test.ts, docs/ssot/spec/design/components/vana-sheet.md

**Details.** 
- [ ] One height, no auto or three-quarter state, no custom thresholds; goldens regenerated and the component spec updated with its version.
- [ ] A hand-off part in the contract (target screen, label, entity id) rendered as a button that navigates; the frozen fixtures carry it (contract test).
- [ ] The persona names the four hand-offs and the eval shows a meal-plan request in the sheet answered with the button, not a picker.
- [ ] Simulator: ask for a plan from the sheet, tap the button, land on the meal-planning page.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png

## mp-306 · Ticket 28: The general opener reads the screen underneath
- category: Tickets
- status: proposed
- ticket: 28
- blocked: 15, 20
- depends: mp-268, mp-008
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the general opener reads only a workout moment and otherwise says a fixed line, while the empty chat still shows three example chips. mp-268 rules that the opener reads the screen underneath and falls back to the personal opener, with no example chips. Seventh of the follow-on set; it follows 15 because the opener path is rewritten there.

**Question.** Is the screen-aware general opener one ticket, blocked by 15?

**Decision.** An athlete opens the sheet on the event screen and Vana's first line is about that event; on a screen that says nothing useful, she says the most relevant personal thing she holds. The general opener reads the resolved Situation before anything else; the example chips are removed from the empty state; offline, rate limit and out-of-trial keep their one visible outcome each.

**Why.** It is the one opener rule not yet built, and it lands on the opener path 15 leaves behind.

**What else was considered.** Keeping the chips as a fallback; rejected by mp-268.

**What it touches.** supabase/functions/_shared/vana/moment.ts, supabase/functions/tests/vana/moment.test.ts, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart

**Details.** 
- [ ] The general opener with a Situation naming an event, a meal or a session opens on it; with a bare route it falls back to the personal opener (server seam).
- [ ] The three example chips are gone from the empty state (golden).
- [ ] Simulator: open the sheet on an event and hear about the event.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture reused from test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png

## mp-307 · Ticket 29: Week start and period length are settings
- category: Tickets
- status: proposed
- ticket: 29
- blocked: 15, 22
- depends: mp-269
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-307.svg
- screen: none (algorithm/data)
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the plan week starts on Sunday by a hardcoded offset, with cook days at fixed offsets from it. mp-269 makes the start day and the period length settings. Eighth of the follow-on set; it follows 15 (the opener file) and 22 (the review sheet).

**Question.** Are the two settings and every reader of them one ticket?

**Decision.** An athlete sets their week to start on Monday and their period to ten days; the Plan tab, coverage, the review sheet and the check-in opener all follow, and cook days derive from the settings rather than fixed offsets. Sunday and seven days stay the defaults. The two settings are keyed Vana settings like batch cooking, editable in Vana settings.

**Why.** Every reader must move at once or the tab and the opener disagree; the cooking-period ticket (30) needs the period length to exist first.

**What else was considered.** Week start alone; it lost because the period length is what 30 counts against.

**What it touches.** lib/features/meal_planning/domain/vana_setting.dart, lib/features/meal_planning/presentation/screens/vana_settings_screen.dart, lib/features/meal_planning/application/vana_settings_controller.dart, lib/features/meal_planning/domain/plan_coverage.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart, lib/features/meal_planning/presentation/widgets/week_card.dart, supabase/functions/_shared/vana/env.ts, supabase/functions/_shared/vana/opener.ts, supabase/functions/_shared/vana/plan-math.ts, test/features/meal_planning/application/vana_settings_controller_test.dart

**Details.** 
- [ ] Two keyed settings, week start and period days, with defaults Sunday and 7, editable in Vana settings (controller test).
- [ ] weekStartFor and the cook-day offsets read the settings; a Monday start moves cook, top-up and fresh days accordingly (server seam).
- [ ] Coverage, the review sheet and the week card read the period length (widget tests).
- [ ] Simulator: change the start day and see the Plan tab's week move.

> 2026-09-15 proposed from the ticket breakdown

## mp-308 · Ticket 30: A plan fills a cooking period, not fourteen slots
- category: Tickets
- status: proposed
- ticket: 30
- blocked: 15, 22, 26, 27, 29
- depends: mp-231, mp-232
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption: The Plan tab, counting against a period
- screen: Plan tab
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the plan walk is a fixed order of meal types with fixed servings against seven or fourteen slots. mp-231 rules a cooking period, servings that scale to cover it, a walk over only the types the athlete plans, per-day planning for non-batch athletes, and a one-tap draft from last time. Ninth of the follow-on set; it follows 29 (the period length) and 27 (the persona).

**Question.** Is the cooking-period model one ticket, blocked by the settings and the persona work?

**Decision.** An athlete who batches picks a few meals and the servings scale so the batch covers their period; coverage counts servings against the period; one who does not batch plans per day; the walk covers only the meal types they plan, in any order; one tap drafts the period from what they ate last time; Draft it for me stays deterministic and the model only presents it.

**Why.** It is the largest follow-on and the one most tied to the prototype's shape; it cannot start until the period length exists.

**What else was considered.** Splitting batch and per-day into two tickets; they lost because coverage is one function.

**What it touches.** supabase/functions/_shared/vana/plan-math.ts, supabase/functions/_shared/vana/plan.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/tests/vana/doll.test.ts, lib/features/meal_planning/domain/plan_coverage.dart, lib/features/meal_planning/application/plan_coverage_service.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart

**Details.** 
- [ ] Coverage counts servings against the period from the settings; batch mode scales servings to cover it; per-day mode counts days (server and client seams agree on fixtures).
- [ ] The walk visits only the types the athlete plans, in the order they choose (server seam).
- [ ] "Same as last time" drafts the period from the previous confirmed plan deterministically (server seam).
- [ ] Simulator: a ten-day period in batch mode shows servings scaled and coverage against ten days.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, f84827b9

## mp-309 · Ticket 31: A turn names its chips, and Show more opens the library
- category: Tickets
- status: proposed
- ticket: 31
- blocked: 15, 26, 27, 30
- depends: mp-272, mp-230
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption: The chat, where the chips sit under a picker
- screen: Vana chat
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and the chips under a picker are only the app's fixed set; there is no Show more. mp-272 lets a turn name two to four chip labels the app draws, and mp-230 asks for a Show more sheet over the same search. Tenth of the follow-on set; it follows 27 because both extend the wire contract and the renderer.

**Question.** Are the model-named chips and the Show more sheet one ticket, blocked by 27?

**Decision.** When Vana's turn names the choices it expects next, those labels appear as the chips under the picker, drawn by the app; when it names none, the app's own set applies; tapping any chip sends its label. Show more under a picker raises a sheet with many more meals from the same search.

**Why.** Both are picker affordances on the same part and share the renderer; together they are one demo.

**What else was considered.** Letting the model draw chips; rejected by mp-272.

**What it touches.** supabase/functions/_shared/vana/contracts.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts, lib/features/meal_planning/presentation/widgets/picker_chips.dart, lib/features/meal_planning/presentation/widgets/meal_picker_carousel.dart, lib/features/meal_planning/presentation/widgets/vana_part_renderer.dart, lib/features/meal_planning/presentation/widgets/meal_catalog_browser.dart

**Details.** 
- [ ] The picker part carries an optional chips list of two to four strings; more or fewer is clamped or dropped (contract test with the frozen fixtures).
- [ ] Named chips replace the app set; absent or empty falls back to it; a tap sends the label (widget test).
- [ ] Show more raises a sheet over the same search with many more meals; the tick adds, the tile opens detail.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, 43496fed

## mp-310 · Ticket 32: Every recipe says where its steps came from
- category: Tickets
- status: proposed
- ticket: 32
- blocked: 25
- depends: mp-146
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption: Meal detail, where the origin label sits
- screen: Meal detail
- source: tickets mealplanning 2026-09-15

**Context.** Vana does not know the person she is talking to, and a recipe's origin is recorded on every row but only the AI-generated badge survived a cleanup. mp-146 rules a badge per origin and an "as published by X" link for verbatim steps. Eleventh and last of the follow-on set; it follows 25 because both edit the meal detail screen.

**Question.** Is restoring the origin badges and the publisher link one ticket, blocked by 25?

**Decision.** Every recipe's steps carry a label by origin: verbatim steps read "as published by X" with a link to the original, an alternate source names it, a simple assembly says so, and AI-generated steps keep the sparkle with its tooltip. Macros stay as they were.

**Why.** The data exists; this is the last unbuilt half of an approved card, and it sits on the screen 25 just touched.

**What else was considered.** none recorded

**What it touches.** lib/features/meal_planning/presentation/screens/meal_detail_screen.dart, lib/features/meal_planning/domain/directions_origin.dart

**Details.** 
- [ ] Four origins, four labels; verbatim carries the publisher name and link (widget test per origin).
- [ ] The sparkle tooltip is unchanged for AI-generated steps.
- [ ] Golden of the detail screen per origin.

> 2026-09-15 proposed from the ticket breakdown
> 2026-09-15 picture captured at 1.26.0+1, 43496fed

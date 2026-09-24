# Proposed decisions: Meal planning and Vana

Feature: mealplanning
Feature name: Meal planning and Vana
Last extracted: 1dedc493

## mp-210 · What does Vana get told from each place she is opened?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-002
- image: none
- caption:
- screen: Vana chat, events page, coach formula feedback
- source: Lee on the page 2026-09-13, amending mp-002

**Context.** Vana is reached from several places: the sheet over any screen, the Plan tab, the full-screen chat, a formula's coach feedback, and the events page. Today the sheet and Plan tab hand her the Doll plus a one-line Situation naming the screen. The formula and events entry points were built earlier and hand her something different, or less. The question is what each entry point owes her.

**Question.** What should Vana be told about the athlete from each place she is opened, given that every place should carry the Voodoo Doll?

**Why.** Without a rule per entry point, each screen invents its own context and Vana knows different things depending on where she was opened.

**What it touches.** Situation resolver, context builder, coach formula feedback, events page, sheet.

**Details.** Lee asked: "Vana has different entry points. Coach formulas will have different conversations to meal planning to general chat. Each entry point needs different context. The formulas conversation needs formula context, and the events page needs the upcoming events. We have not figured this out enough and need to think it through. All contexts should have the Voodoo Doll of the given user."

> 2026-09-15 answered by mp-273
> 2026-09-23 clarity pass (question, details)

## mp-211 · Which ways into Vana continue a conversation, and which start a new one?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-003
- image: none
- caption:
- screen: Vana chat, Vana sheet, Plan tab
- source: Lee on the page 2026-09-13, amending mp-003

**Context.** Vana can be reached from the sheet over any screen, the Plan tab's note, the New meal plan button, the full-screen chat, and the history list. Today the sheet continues one conversation per day, and New meal plan opens a fresh planning conversation. The rules for the other entry points were never written down together.

**Question.** Which ways into Vana start a new conversation, and how does the athlete find the old ones?

**Why.** If two entry points disagree about whether they continue or start fresh, the athlete lands in a conversation they did not expect.

**What it touches.** Ambient conversation controller, chat route, history list, opener.

**Details.** Lee asked: "We need to figure out conversation histories. When we press New meal plan, or ask a question cold by pressing a button somewhere, the expectation is that this is a new conversation and not an existing one. We should still be able to list and see prior questions we have asked."

> 2026-09-15 answered by mp-275
> 2026-09-23 clarity pass (question, details)

## mp-215 · Is sending the whole context every turn wasteful?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-019
- image: none
- caption:
- screen: none (algorithm/data)
- source: Lee on the page 2026-09-13, rejecting mp-019

**Context.** The model keeps nothing between calls. Every turn is a fresh request that carries the persona, the athlete context block, and the recent history, so the model reads the context again each time. That is how every chat model works, including the one behind this page. Provider prompt caching can make a repeated prefix much cheaper without changing what is sent. The alternative is to leave the context out and fetch pieces by tool when the model asks, which saves tokens but makes Vana forget things unless she remembers to ask.

**Question.** Do we send the whole context every turn, and is that wasteful?

**Why.** The decision on cost per turn depends on whether the repeated block can be cached and on how often a turn actually needs it.

**What it touches.** vana-chat context builder, model call options.

**Details.** Lee asked: "Do we send the entire context each time? Is this not wasteful? Does Claude not remember this context within a conversation?"

> 2026-09-15 answered by mp-276
> 2026-09-23 clarity pass (question, details)

## mp-216 · Should the opener wait for the last conversation to be read back?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-009
- image: none
- caption:
- screen: none (algorithm/data)
- source: Lee on the page 2026-09-13, rejecting mp-009

**Context.** When a conversation opens, the previous one is read back in the background to pull out new notes. The opener wants those notes. The shipped rule waited up to 3.5 seconds, then went ahead with the athlete's last words in place of the notes. Lee rejected the fixed wait as too deterministic and asked for a revisit.

**Question.** Why does the opener wait a fixed 3.5 seconds for the read-back, and should it wait at all?

**Why.** The opener is the first thing the athlete reads. A wrong wait either delays it or makes it forget last time.

**What it touches.** Opener path in vana-chat, read-back extraction.

**Details.** Lee asked: "This is too deterministic. Why are we doing this? We need to revisit it."

> 2026-09-15 answered by mp-278
> 2026-09-23 clarity pass (question, details)

## mp-217 · How should Vana remember, within and across conversations?
- category: Vana's memory
- kind: question
- status: answered
- linked: mp-032
- image: none
- caption:
- screen: none (algorithm/data)
- source: Lee on the page 2026-09-14, on mp-009, mp-026, mp-032 to mp-036, mp-038

**Context.** The model remembers nothing between turns, so everything that looks like memory is machinery the app built: a 20-message replay window, an Episode written mid-conversation and again at the end, a read-back of the previous conversation when the next one opens, a 3.5 second wait for that read-back, and a LAST TALKS line in the context block. Seven cards describe those pieces (mp-009 and mp-026 rejected, mp-032 to mp-036 and mp-038 held). Lee reviewed them together and asked for a rethink and research before any is treated as settled. His words: "Do we need previous-conversation extraction like this? We need to remove plumbing like this if it exists. If there is a new conversation, we should have summarised the earlier one sometime before that. Research how other chatbots approach this: whether they summarise, when, how many messages they keep, and how they keep costs low. Is this the best we can do, or is there another way of handling all of this?"

**Question.** What is the best way for Vana to remember, inside a conversation and from one to the next, without machinery like the read-back on open?

**Why.** These pieces decide what Vana knows on any given turn and what each turn costs. A wrong strategy either makes her forget or makes every turn expensive.

**What it touches.** vana-chat history replay, extract.ts, the episode row, the opener path, the context builder. Research: docs/research/conversation-memory-strategies.md (2026-09-14).

> 2026-09-15 answered by mp-277
> 2026-09-23 clarity pass (question, context)

## mp-267 · What moving from freemium to a trial requires
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-266
- image: none
- caption:
- screen: Paywall
- source: Lee on the page 2026-09-14, on mp-052

**Context.** The app sold AI credit packs and a Pro subscription: meal planning needed Pro, and general chat cost a free user one credit. Lee is replacing that with a seven-day Trial of the whole app, then purchase. The store products, the RevenueCat Offering, the app's switch for the Gate and the server's table of who holds Pro were all built for free and Pro. Lee added on 2026-09-14: that server table goes away under the trial model, and meal planning does not ship until the trial exists.

**Question.** We need to discuss what we need to do in order to move away from a freemium to a purchase model. What are the store products and introductory offers, how does RevenueCat run the trial, what can an expired trial still open, what happens to the credits system, and what happens to accounts that exist today?

**Why.** Every paywall decision on this page was written for free and Pro. Until this is answered the three Pro cards cannot be approved as written.

**What it touches.** Store products, RevenueCat offering, entitlements table, gate flag, credits system, Pro screen, mp-254 to mp-256.

> 2026-09-14 opened from Lee's amendment of mp-052
> 2026-09-14 context extended from Lee's verdicts on mp-250 and mp-255
> 2026-09-15 answered by mp-279
> 2026-09-23 clarity pass (context)

## mp-287 · What the coach rule is, once the paywall document arrives
- category: Pro and paywall
- kind: question
- status: answered
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
> 2026-09-20 answered by mp-429

## mp-315 · Must changes made outside Vana reach her at once?
- category: Vana's memory
- kind: question
- status: answered
- linked: mp-311
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 13

**Context.** Vana's context block is stored, and mp-311 rebuilds it when one of her tools changes something. Some things the block reads change without a Vana tool: the home location saved on the app's own screen, a thumbs vote on a Meal (the LIKES line), and edits to the athlete's profile. After any of them the block stays as it was until the next tool change or the next day.

**Question.** When a home location, a thumbs vote or a profile edit is made outside Vana, must her context block update at once, or is the next change through Vana or the next day enough?

**Why.** Each path added to the invalidation set is a query on a write path that today knows nothing about Vana.

**What it touches.** The home-location write in the app, meal feedback, the users row, mp-311.

> 2026-09-15 opened in wave 1 ticket 13
> 2026-09-20 answered by mp-419
> 2026-09-23 clarity pass (question, context)

## mp-316 · Should a new conversation read the tools and persona from the cache?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-311
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 13

**Context.** Vana's calls use the prompt cache. In its automatic setting the cache marker sits at the end of the prompt, so the first turn of a new conversation reads nothing from the cache: no earlier call ended the same way. The tools and persona are the same for every athlete, so a second marker right after them would let every new conversation read them from the cache.

**Question.** Should the first turn of a new conversation read the tools and persona from the prompt cache, at the cost of one more cache marker?

**Why.** The first turn is the biggest call of a conversation (dev: 10886 input tokens on turn one against about 6000 after).

**What it touches.** vana-chat prompt assembly, the call log.

> 2026-09-15 opened in wave 1 ticket 13
> 2026-09-20 answered by mp-420
> 2026-09-23 clarity pass (question, context)

## mp-431 · How testers get in on a production release build
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-318
- image: none
- caption:
- screen: Paywall
- source: Lee in the terminal 2026-09-21

**Context.** mp-318 lets a tester in through a free TestFlight subscription. That is known to work on dev builds. A production release build handed to testers sells the production products, which Apple had not yet reviewed when last checked (08-13), and a tester who installs from the App Store pays real money. Recommendation (2026-09-21, Lee asked on mp-336 whether this is the easiest route): yes. On TestFlight a subscription costs nothing; the tester taps Subscribe, confirms with their Apple ID and is never charged. It needs no tester list, which was the constraint.

**Question.** When a production release build goes to testers, do they subscribe free in TestFlight as on dev, and what happens to a tester on the App Store build?

**Why.** Lee on 2026-09-21: the tester pool will change and grow, he does not hold their email addresses, and he wants no per-tester work.

**What it touches.** The production products in App Store Connect, RevenueCat's production project, the release checklist.

> 2026-09-21 opened by Lee in the terminal
> 2026-09-23 answered by mp-610

## mp-320 · Which AI calls the server's Pro check covers
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-296
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** Ticket 18 checked every Vana call against the server's record of who holds Pro. That check had four callers, all Vana functions. The functions that spend AI credits (meal describe, meal photo, the coach chat) checked only the wallet, not Pro.

**Question.** Does an AI call that spends bought credits also need Pro, or are bought credits permission enough?

**Why.** A Lapsed account with credits left could still spend them. Whether that is a feature or a hole decides whether ticket 20 adds the check.

**What it touches.** The credit-debiting functions, the server gate, ticket 20.

> 2026-09-15 opened in wave 1 ticket 18
> 2026-09-20 answered by mp-430
> 2026-09-23 clarity pass (question, context, why)

## mp-321 · In what order does production get the new Pro table, webhook and offers?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-319
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-321.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** Ticket 18 changed dev only: a new table of who holds Pro, a new webhook, a RevenueCat connection that sends every event type, and the Trial offers in the stores. Production still has the old table, the old webhook, a connection that sends three event types, and no Trial offers. mp-543 already puts the new webhook and every event type in the cutover step. The webhook takes events from both environments, so once the new table exists a production event is handled correctly; before that, the old webhook keeps writing the old columns.

**Question.** Do the Trial offers go to the stores first, and then at the cutover the new table, then the new webhook with every event type, or does everything go in one step at the cutover?

**Why.** The deploy playbook puts database changes before functions, and the offers can go first because nothing reads them until a purchase.

**What it touches.** The cutover runbook, production RevenueCat, the production store listings.

> 2026-09-15 opened in wave 1 ticket 18
> 2026-09-23 clarity pass (question, context, why)

## mp-322 · Who runs the checks a wave cannot run on a simulator
- category: Process and scope
- kind: question
- status: answered
- linked: mp-296
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** Two of the wave's criteria need a hand on a device: a sandbox purchase on the dev app (ticket 18; a simulator cannot sign into a sandbox App Store account, and a StoreKit-configuration purchase never reaches RevenueCat) and a second dev account seeing no review box (ticket 25; the agent proved it with the policy test and a widget test instead of signing the simulator into another account). Both tickets were merged with those lines unticked.

**Question.** Does a check only a person with a phone can run keep a ticket open, and where is it recorded?

**Why.** The wave rule says an unfinished criterion fails the ticket. Applied literally, ticket 18 and 25 could never pass, and tickets 19, 20, 21, 28 and 32 wait on them.

**What it touches.** The wave rule in the implement skill, tickets 18 and 25.

> 2026-09-15 opened in wave 1
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question)

## mp-324 · Should plan rows show the meal's photo?
- category: Plan tab
- kind: question
- status: answered
- linked: mp-323
- image: none
- caption:
- screen: Plan tab
- source: wave mealplanning 1 ticket 22

**Context.** The Plan tab, the plan bar and the review sheet show a plan's meals with no picture, because a plan meal stores only its name, meal type and icon. With the icons gone, every meal there shows the placeholder, not only meals without a photo. The Meals tab, which reads the library, shows each Meal's picture.

**Question.** Should a plan's meal rows show the Meal's picture, or stay a plain box?

**Why.** Carrying the picture means the plan meal row grows picture fields and the add and swap paths copy them, the same shape as the icon key today.

**What it touches.** Plan tab tiles, the plan bar, the review sheet, the plan meal row.

> 2026-09-15 opened in wave 1 ticket 22
> 2026-09-17 answered by mp-418
> 2026-09-23 clarity pass (question, context)

## mp-325 · Which specs the wave left describing the old behaviour
- category: Design system
- kind: question
- status: answered
- linked: mp-323
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 tickets 22 and 23

**Context.** Two specs under docs/ssot/spec now describe what the build no longer does. The mosaic component spec (meal-image-mosaic.md v1.1, MIM-9) and the widget's header comment describe an icon state that ticket 22 removed. The Vana sheet spec's "Where the launcher does not appear" describes the flow-screen and exclusion lists ticket 23 deleted. Both files are QA-owned and were not edited.

**Question.** Who updates the mosaic spec (clause MIM-9) and the launcher section in the QA repo, and does the placeholder get a design spec of its own?

**Why.** The next design sync would report the widgets as drifting from their specs.

**What it touches.** docs/ssot/spec/design/components/meal-image-mosaic.md, the Vana sheet spec, the QA repo.

> 2026-09-15 opened in wave 1
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question)

## mp-328 · Where the Dev build card sits on Settings
- category: Design system
- kind: question
- status: answered
- linked: mp-327
- image: none
- caption:
- screen: Settings
- source: wave mealplanning 1 ticket 24

**Context.** The floating dev buttons sit over every screen. When Settings is scrolled to the bottom they cover the right edge of the new switch; its left half is still tappable.

**Question.** Should the Dev build card sit higher on Settings, or the buttons leave room for it?

**Why.** The switch that hides the buttons is the one control they overlap.

**What it touches.** Settings, the dev buttons.

> 2026-09-15 opened in wave 1 ticket 24
> 2026-09-20 answered by mp-428

## mp-330 · How the team reads meal reviews, and when production gets them
- category: Meals tab and library
- kind: question
- status: answered
- linked: mp-329
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 25

**Context.** Admins can leave a review on any meal (mp-329), and it lands in a table only admins can read, through the database. Nothing in the app or elsewhere lists the reviews, and the app version column is empty. Production has neither the table nor the admin flag, and someone must set the flag by hand for the team's production accounts.

**Question.** Does the team need a screen or an export to read meal reviews, should each review carry the app version, and which release takes reviews to production?

**Why.** A table nobody reads collects nothing useful.

**What it touches.** meal_reviews, the cutover runbook, the team's production accounts.

> 2026-09-15 opened in wave 1 ticket 25
> 2026-09-20 answered by mp-427
> 2026-09-23 clarity pass (question, context)

## mp-332 · Is reaching into Wiredash's internal code acceptable, and how does the inbox tell typed feedback apart?
- category: Feedback loop
- kind: question
- status: answered
- linked: mp-331
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 26

**Context.** The app files feedback typed to Vana into Wiredash, the team's bug-report inbox, by reaching into the Wiredash package's internal code with its version pinned, so every upgrade needs the filer re-checked. Typed entries carry extra details but no label, so the inbox cannot filter them. Like shaken reports, they follow the build: a debug build files them as dev.

**Question.** Can the app keep filing through Wiredash's internal code with the version pinned, or should Wiredash be asked for a public way, and which label should typed feedback carry so the inbox can filter it?

**Why.** A silent break on upgrade would drop typed feedback without anyone noticing.

**What it touches.** The feedback filer, the Wiredash console, the pubspec.

> 2026-09-15 opened in wave 1 ticket 26
> 2026-09-20 answered by mp-427
> 2026-09-23 clarity pass (question, context)

## mp-334 · What should the conversation list preview show?
- category: Vana's memory
- kind: question
- status: answered
- linked: mp-333
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 14

**Context.** The conversation list shows a one-line preview of each chat, read from the chat's summary field. Under mp-333 that field now holds the long-chat summary, which starts "Through message 20: …", and it is empty for a chat under thirty messages, since the Episode no longer fills it. So a short chat's preview is blank and a long one shows the internal lead-in text.

**Question.** Should each row of the conversation list preview the chat's Episode sentence, and may the internal "Through message N" text ever show on screen?

**Why.** Today a short conversation's preview goes blank and a long one shows the lead-in string.

**What it touches.** The conversation list screen and its repository read.

> 2026-09-15 opened in wave 2 ticket 14
> 2026-09-20 answered by mp-419
> 2026-09-23 clarity pass (question, context)

## mp-337 · What the web build does behind the one gate
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-335
- image: none
- caption:
- screen: Paywall
- source: wave mealplanning 2 ticket 19

**Context.** The web build has no RevenueCat key, so under the one gate every web user, coaches included, meets the paywall with no store to buy from. Nothing was bypassed, as mp-286 asks; the coach portal is therefore unusable on the web until a rule exists.

**Question.** Does the web build get a RevenueCat web key, a coach grant, or stay closed until Xuan's paywall document?

**Why.** The web coach test login and every coach on the web are locked out today.

**What it touches.** The web build, the coach portal, the gate.

> 2026-09-15 opened in wave 2 ticket 19
> 2026-09-21 answered by mp-335

## mp-338 · How test accounts get past the Gate
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-335
- image: none
- caption:
- screen: Paywall
- source: wave mealplanning 2 ticket 19

**Context.** With the tester shortcut gone, a debug build opens on the paywall for any account that does not hold Pro in RevenueCat. The dev account held none, so the wave gave it a Grant of Pro in RevenueCat to 15 September 2027, which can be taken back, so the dev simulator can reach the screens behind the Gate. The server's dev Entitlement rows were also empty until the wave's agents inserted two by hand, for the eval user and the dev account.

**Question.** Is a Grant in RevenueCat the standing way every test account gets in, and who holds the list of Grants?

**Why.** Every dev account and every tester on TestFlight is locked out until someone grants or buys.

**What it touches.** RevenueCat customers, the dev entitlement table, the dev simulator login script.

> 2026-09-15 opened in wave 2 ticket 19
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question, context)

## mp-339 · Who writes the internal-device flag now
- category: Data, sync and backend
- kind: question
- status: answered
- linked: mp-335
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 19

**Context.** The app no longer writes `users.is_internal`; the gate stopped reading it and the tester grant that set it is gone. The analytics module on the server still reads the column to exclude internal devices from Mixpanel.

**Question.** Does the internal-device flag need a new writer so Mixpanel keeps excluding the team, or does the flag retire?

**Why.** Without a writer, new internal devices count as athletes in analytics.

**What it touches.** The users row, the analytics edge module, Settings' internal-device flag.

> 2026-09-15 opened in wave 2 ticket 19
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question)

## mp-343 · Whether the free monthly credits stop
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-341
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 20

**Context.** Every wallet still receives 20 free credits a month (50 on dev) from the old free tier. They never expire, and they arrive whether the account subscribes or not. Under mp-266 there is no free tier; the only monthly amount is the subscriber's, now the Monthly budget.

**Question.** Do the free monthly credits stop now, and what happens to the free credits already in wallets?

**Why.** Two monthly amounts blur what the subscriber's one is, and the free one never expires.

**What it touches.** `ensure-credits`, the client's monthly stamp, the wallet SQL.

> 2026-09-15 opened in wave 2 ticket 20
> 2026-09-20 answered by mp-430
> 2026-09-23 clarity pass (question, context, why)

## mp-344 · What a transfer or a plan change does to the Monthly budget
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-341
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 20

**Context.** A RevenueCat transfer moves an account's Pro to another account; the wallet's Monthly budget and bought Top-ups stay with the old account, as bought packs always did. A switch between the monthly and annual plan adds nothing by itself; the next month's budget comes at the usual refill.

**Question.** Should the Monthly budget follow a transfer, and should a plan change start a new month of budget at once?

**Why.** Both are rare, and both can leave a subscriber for up to a month with a wallet that does not match whether they hold Pro.

**What it touches.** The webhook, the wallet roll.

> 2026-09-15 opened in wave 2 ticket 20
> 2026-09-20 answered by mp-430
> 2026-09-23 clarity pass (question, context, why)

## mp-346 · The recipe origin wording, the doubled link and the overflow on narrow phones
- category: Recipes and cooking
- kind: question
- status: answered
- linked: mp-345
- image: none
- caption:
- screen: Meal detail
- source: wave mealplanning 2 ticket 32

**Context.** Each recipe now says under Directions where its steps came from (mp-345). The build wrote two of the wordings itself: "Steps from X" for steps from another source, and a sentence for an assembly. A recipe with published steps now links the original twice, from the new line and from the older "See the original recipe" row. That row already ran 47 px past the edge on a 320-wide screen and 7 px on a 360-wide one before the build, outside the ticket.

**Question.** Are "Steps from X" and the assembly sentence the right wording, should a published recipe keep both links to the original, and is the overflow on narrow phones fixed now?

**Why.** Copy is Xuan's to rule; two links to one page and an overflow on small phones are visible to athletes.

**What it touches.** The meal detail screen, the content defaults.

> 2026-09-15 opened in wave 2 ticket 32
> 2026-09-20 answered by mp-427
> 2026-09-23 clarity pass (question, context)

## mp-349 · Does a day's conversation get one episode, or one per close?
- category: Vana's memory
- kind: question
- status: answered
- linked: mp-288
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 3 ticket 15

**Context.** The Vana sheet keeps one conversation for the whole day. The first close writes its Episode, and mp-288 says a later close writes nothing. So an athlete who talks in the morning, closes the sheet and talks again at night has an Episode of the morning only, and the next morning's opener never hears about the evening.

**Question.** When an athlete talks again after closing the sheet, should the next close write a new Episode, or does the first one stand?

**Why.** Evening planning is the ticket's own example, and today it would not reach the next morning's opener.

**What it touches.** extract.ts claim, the ambient conversation controller, mp-288 clause 3.

> 2026-09-15 opened in wave 3 ticket 15
> 2026-09-20 answered by mp-419
> 2026-09-23 clarity pass (question, context)

## mp-350 · Should leaving the full-screen chat mark the conversation idle?
- category: The sheet and launcher
- kind: question
- status: answered
- linked: mp-288
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 3 ticket 15

**Context.** When a conversation goes idle, the app tells the server, which then writes its Episode. The sheet does this when it closes, and the app when it goes to the background. The full-screen chat's New conversation button and leaving the chat send nothing, so those conversations get their Episode only when the app goes to the background.

**Question.** Should New conversation and leaving the full-screen chat also mark the conversation idle?

**Why.** A conversation left in the chat screen while the app stays open has no episode for the next opener.

**What it touches.** vana_chat_screen.dart, the chat controller.

> 2026-09-15 opened in wave 3 ticket 15
> 2026-09-20 answered by mp-423
> 2026-09-23 clarity pass (question, context)

## mp-351 · Should the "Remembered" card show for notes Vana saves on her own?
- category: Vana's memory
- kind: question
- status: answered
- linked: mp-277
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 3 ticket 15

**Context.** When the model saves a note it shows a "Remembered: …" card in the sheet. The sharpened remember rule (mp-277 clause 2) makes self-initiated saves more frequent, so the card appears more often.

**Question.** Should the "Remembered" card show for every save, or only when the athlete asked Vana to remember?

**Why.** It is the athlete-visible cost of saving things as they are said.

**What it touches.** Vana sheet, persona remember rule.

> 2026-09-15 opened in wave 3 ticket 15
> 2026-09-20 answered by mp-419
> 2026-09-23 clarity pass (question)

## mp-352 · Does picking up last time in an offer count?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-278
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 3 ticket 15

**Context.** On the device the next opener picked up the previous conversation in one of its offers ("Ready for Saturday's dinner (Ingrid's visit)"), not in its sentence.

**Question.** Is an offer chip that names last time enough, or should the opener's prose say it?

**Why.** The ticket's check was "the opener mentions last time", and this reads it loosely.

**What it touches.** opener prompt, Vana sheet.

> 2026-09-15 opened in wave 3 ticket 15
> 2026-09-20 answered by mp-421

## mp-353 · How strict is the opener's start-time check?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-278
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 3 ticket 15

**Context.** An automated test of the opener fails it when the reply has not started within 3.5 seconds (3,500 ms). The eval script, run against the server, measured the opener starting in 2,863 ms (about 2.9 seconds), almost all of it spent building the Context block, so a slow cold start could fail the test. As written, the test proves the old 3.5-second wait is gone, not that the opener starts at once.

**Question.** Should the limit be looser, or should the context build get faster so the limit can be tighter?

**Why.** A flaky eval gets ignored.

**What it touches.** scripts/vana-eval/personalization.ts, context build.

> 2026-09-15 opened in wave 3 ticket 15
> 2026-09-20 answered by mp-420
> 2026-09-23 clarity pass (context)

## mp-354 · How Restore is tested when a store won't resubscribe outside the app
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-289
- image: none
- caption:
- screen: Paywall
- source: wave mealplanning 3 ticket 21

**Context.** The sandbox wizard is a script that walks a person through a test purchase step by step (ticket 21, not merged this wave). It tests Restore purchases by resubscribing in the store's own settings after the trial ends, then tapping Restore purchases. Some stores’ Sandbox modes may offer no way to resubscribe outside the app.

**Question.** If a store has no way to resubscribe outside the app, how is Restore purchases proven: with a second Mealvana account on the same device (which also tests a transfer), or another way?

**Why.** Without it the last step of mp-289 cannot go green on that store.

**What it touches.** scripts/sandbox-trial-wizard.sh step 8, the release gate.

> 2026-09-15 opened in wave 3 ticket 21
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question, context)

## mp-355 · How fresh a green sandbox run must be for a release
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-270
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 3 ticket 21

**Context.** The sandbox wizard's README proposes a freshness rule: a passing run's log counts when its commit is in the release candidate's history and nothing since touched the paywall, the Gate, the webhook or the Monthly budget.

**Question.** Does a passing sandbox run count for a release when its commit is in the release's history and nothing since touched the paywall, or must the run be on the release candidate itself?

**Why.** The release gate in the deploy playbook is only as strong as this rule.

**What it touches.** docs/release/sandbox-trial-runs/README.md, playbook §8 P3c.

> 2026-09-15 opened in wave 3 ticket 21
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question, context, why)

## mp-356 · The release doc still plans a dark launch
- category: Process and scope
- kind: question
- status: answered
- linked: mp-270
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 3 ticket 21

**Context.** The release doc (docs/implement_mealplanning/07-verification-release.md) still plans, in step 3, to ship meal planning hidden behind a switch and turn it on later, a dark launch. mp-270 rules out a dark launch and any gate switch as the release plan.

**Question.** Should the release doc's step 3 be rewritten for the trial-and-purchase release, and who owns the doc now?

**Why.** Someone following the doc would release against the record.

**What it touches.** docs/implement_mealplanning/07-verification-release.md.

> 2026-09-15 opened in wave 3 ticket 21
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question, context)

## mp-357 · Something other than the webhook wrote an entitlement row on DEV
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-296
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 3 ticket 21

**Context.** One of the dev server's Entitlement rows has the period type 'eval' (user 37129f7e…, written 2026-09-15 19:05 UTC). The webhook never writes that value, and it is meant to be the only writer of those rows.

**Question.** What wrote it (an eval script, a test fixture, a hand edit), and should the table refuse any writer but the webhook?

**Why.** The server's Gate reads these rows, so a stray writer can let an account in or shut it out.

**What it touches.** user_entitlements on DEV, whatever wrote the row.

> 2026-09-15 opened in wave 3 ticket 21
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question, context, why)

## mp-367 · Should the Plan tab open on the plan rather than the personal opener?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-268
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 28

**Context.** Today the sheet opens on the screen underneath only for event, meal and session screens. On the Plan tab with a plan in view, such as a draft for the week of the 7th, it uses the personal opener instead.

**Question.** Should the Plan tab with a plan in view open on that plan?

**Why.** It is the screen an athlete is most often on when they open the sheet.

**What it touches.** The general opener, the Plan tab.

> 2026-09-15 opened in wave 4 ticket 28
> 2026-09-20 answered by mp-421
> 2026-09-23 clarity pass (context)

## mp-368 · Should a live moment outrank the screen underneath?
- category: Moments: Vana speaks first
- kind: question
- status: answered
- linked: mp-268
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 28

**Context.** The opener takes a moment that resolves before the screen underneath. mp-268 says the general conversation "opens with a line that reads the screen underneath".

**Question.** When an athlete opens the sheet on an event screen while a moment is live, which should Vana speak to?

**Why.** They are two different readings of what "reads the screen" means, and only one can be first.

**What it touches.** The general opener, moments.

> 2026-09-15 opened in wave 4 ticket 28
> 2026-09-20 answered by mp-421

## mp-369 · Should the full-screen general chat open on the screen underneath too?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-268
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 4 ticket 28

**Context.** The example chips were removed from the full-screen general chat's empty state, but that screen never asks for an opener; only the sheet does. It now opens on an empty state with no line at all.

**Question.** Should the full-screen general chat ask for an opener the way the sheet does?

**Why.** An empty screen with no chips and no line says nothing.

**What it touches.** The full-screen Vana chat.

> 2026-09-15 opened in wave 4 ticket 28
> 2026-09-20 answered by mp-421

## mp-370 · Should Vana's instructions name the lines about the screen?
- category: Situation awareness
- kind: question
- status: answered
- linked: mp-273
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 16

**Context.** Vana's standing instructions (her persona) tell her what the Situation note is. Under it the server adds a few lines about what is on screen, such as an EVENTS AHEAD list or the day's plan, and nothing tells her what those lines are. She reads them as background either way.

**Question.** Should Vana's standing instructions name the lines about the screen in view, the way they name the Situation?

**Why.** What the prompt does not name, the model interprets.

**What it touches.** The persona, the in-view section.

> 2026-09-15 opened in wave 4 ticket 16
> 2026-09-20 answered by mp-422
> 2026-09-23 clarity pass (question, context)

## mp-371 · Should the Plan tab tell Vana about the day or the week?
- category: Situation awareness
- kind: question
- status: answered
- linked: mp-273
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 16

**Context.** When Vana is opened from the Plan tab, the server adds a few lines about it: the day's note and meals, and also every meal of the week with its servings left, because the tab shows the week. mp-273 says these lines stay short and never dump the whole record.

**Question.** Should the lines about the Plan tab cover only the day on screen, or the whole week?

**Why.** It is the longest section, and the cap is the only thing holding it down.

**What it touches.** The in-view section, the Plan tab.

> 2026-09-15 opened in wave 4 ticket 16
> 2026-09-20 answered by mp-422
> 2026-09-23 clarity pass (question, context)

## mp-372 · Two new conversations in a row share one screen
- category: The sheet and launcher
- kind: question
- status: answered
- linked: mp-275
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 4 ticket 16

**Context.** Every new conversation shares one internal key, which is what keeps the launcher opening on today's conversation. So pressing the plus button inside a new conversation opens a second screen showing the first one's messages. This was true before ticket 16 as well.

**Question.** Should each new conversation get its own key, and can an athlete actually hit this?

**Why.** mp-275 clause 2 says the plus button starts a new conversation, and here the second press does not.

**What it touches.** The full-screen chat's key, the ambient conversation controller.

> 2026-09-15 opened in wave 4 ticket 16
> 2026-09-20 answered by mp-423
> 2026-09-23 clarity pass (question, context)

## mp-373 · Carb loading lands on the event screen, not on the picks
- category: The sheet and launcher
- kind: question
- status: answered
- linked: mp-265
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 4 ticket 27

**Context.** mp-265 clause 4 sends a carb-loading Hand-off to the carb-loading picks. That screen opens only from an event already on screen and has no address of its own, so the hand-off lands on the event screen, where the carb-loading action lives.

**Question.** Should the picks get their own address that takes an event, so the hand-off opens them directly?

**Why.** As built, the carb-loading hand-off and the event hand-off do the same thing.

**What it touches.** The carb-loading picks, the router, the hand-off targets.

> 2026-09-15 opened in wave 4 ticket 27
> 2026-09-20 answered by mp-423
> 2026-09-23 clarity pass (question, context)

## mp-374 · What a hand-off with no entity should do
- category: The sheet and launcher
- kind: question
- status: answered
- linked: mp-265
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 4 ticket 27

**Context.** When Vana cannot name the event, "plan an event" lands on the blank new-event form and carb loading lands on the events list.

**Question.** Is a blank form or a bare list the right landing, or should Vana be required to name the entity before she offers the button?

**Why.** A button that lands nowhere in particular is worse than a sentence.

**What it touches.** The hand-off tool, the events screens.

> 2026-09-15 opened in wave 4 ticket 27
> 2026-09-20 answered by mp-423

## mp-375 · Does the fuelling hand-off edit the workout or add one?
- category: The sheet and launcher
- kind: question
- status: answered
- linked: mp-265
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 27

**Context.** The fuelling hand-off passes the workout's id to the new-activity screen, which prefills from an existing activity. Nobody has watched what saving there does.

**Question.** Does that screen edit the workout Vana named, or create a second one beside it?

**Why.** A duplicated workout would quietly double an athlete's week.

**What it touches.** The new-activity screen, the fuelling hand-off.

> 2026-09-15 opened in wave 4 ticket 27
> 2026-09-20 answered by mp-423

## mp-376 · Which status chip a hand-off turn shows
- category: The sheet and launcher
- kind: question
- status: answered
- linked: mp-265
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 27

**Context.** A turn answered with a hand-off button is treated as an update, so it shows the ordinary chip rather than the one that marks something to do.

**Question.** Is a hand-off an update, or a to-do until they tap it?

**Why.** The chip is how the sheet says whether anything is waiting on the athlete.

**What it touches.** The Vana sheet's status chip.

> 2026-09-15 opened in wave 4 ticket 27
> 2026-09-20 answered by mp-423

## mp-377 · Should the opener's "Start a meal plan" reply be the hand-off itself?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-268
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 27

**Context.** The general opener still offers "Start a meal plan" as a quick reply. Tapping it now produces a hand-off button, so the athlete taps twice to get to the same screen.

**Question.** Should the opener offer that reply at all, or should it be the hand-off itself?

**Why.** Two taps for one intent.

**What it touches.** The general opener, the Vana sheet's quick replies.

> 2026-09-15 opened in wave 4 ticket 27
> 2026-09-20 answered by mp-421
> 2026-09-23 clarity pass

## mp-378 · What happens to the plan when the start day changes mid-period
- category: Plan tab
- kind: question
- status: answered
- linked: mp-269
- image: none
- caption:
- screen: Plan tab
- source: wave mealplanning 4 ticket 29

**Context.** Changing the start day moves which week the Plan tab binds to. A draft built on the old week stops being this week's plan and the tab shows an empty week.

**Question.** Should the active plan's week move with the setting, should the old plan stay visible until it ends, or is an empty new week right?

**Why.** An athlete who changes a setting should not appear to lose a plan.

**What it touches.** The Plan tab, the plan's stored week start.

> 2026-09-15 opened in wave 4 ticket 29
> 2026-09-20 answered by mp-424

## mp-379 · Should plan periods longer than a week overlap?
- category: Plan tab
- kind: question
- status: answered
- linked: mp-269
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 29

**Context.** Plan periods start once a week, whatever their length. So a ten-day period that begins on a Monday overlaps the next one, which starts the following Monday, by three days.

**Question.** Should each plan period start the day after the last one ends, and if so, what fixes the first start?

**Why.** Counting meals against a period that overlaps the next one double-counts the shared days.

**What it touches.** The plan maths, the next meal-planning ticket.

> 2026-09-15 opened in wave 4 ticket 29
> 2026-09-20 answered by mp-424
> 2026-09-23 clarity pass (question, context)

## mp-380 · Should a plan carry the period it was built for?
- category: Plan tab
- kind: question
- status: answered
- linked: mp-269
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 29

**Context.** A plan stores no period of its own; every screen reads the athlete's current setting. Changing the setting therefore re-reads old plans under the new period. Storing it is a schema change, and none was written or applied.

**Question.** Should a plan record the period it was built for?

**Why.** Otherwise last month's plan is described by this month's setting.

**What it touches.** The meal plans table, coverage, the review sheet.

> 2026-09-15 opened in wave 4 ticket 29
> 2026-09-20 answered by mp-424

## mp-381 · Should the reminder name the athlete's own days?
- category: Plan tab
- kind: question
- status: answered
- linked: mp-269
- image: none
- caption:
- screen: Vana settings
- source: wave mealplanning 4 ticket 29

**Context.** The reminders row still reads "The night before cook day and Sunday evening", whatever the athlete's start day is.

**Question.** Should the reminder text name the athlete's own days?

**Why.** mp-269 clause 3 has every surface read the settings, and this one still speaks for Sunday.

**What it touches.** Vana settings, the reminder copy.

> 2026-09-15 opened in wave 4 ticket 29
> 2026-09-20 answered by mp-424
> 2026-09-23 clarity pass (question)

## mp-382 · Can Vana change the two new settings in conversation?
- category: Plan tab
- kind: question
- status: answered
- linked: mp-269
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 29

**Context.** Vana's settings tool can change only four older settings. The start day and the period length can be changed on the settings screen alone.

**Question.** Should Vana be able to set them mid-conversation when an athlete says "my week starts Monday"?

**Why.** Every other setting she can hear, she can save.

**What it touches.** The setting tool, Vana settings.

> 2026-09-15 opened in wave 4 ticket 29
> 2026-09-20 answered by mp-424
> 2026-09-23 clarity pass (context)

## mp-383 · A design spec was edited in the app repo
- category: Design system
- kind: question
- status: answered
- linked: mp-265
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 4 ticket 27

**Context.** The sheet's component spec was raised to v2 in this repo, marked app-authored and awaiting Xuan, because the sheet changed. The rule here says the design specs are a verbatim mirror of the QA repo and are never edited in this repo, with only the decision records carved out. The design sync that the rule asks for after such a change has not been run.

**Question.** Is an app-authored spec revision awaiting ratification the accepted practice, and who runs the design sync?

**Why.** The spec and the widget now disagree with the QA repo, and a blind mirror sync would delete the revision.

**What it touches.** The sheet's component spec, the QA mirror, the design sync.

> 2026-09-15 opened in wave 4 ticket 27
> 2026-09-20 answered by mp-428

## mp-384 · The opener's own example sits on a screen the launcher never reaches
- category: The sheet and launcher
- kind: question
- status: answered
- linked: mp-268
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 28

**Context.** mp-268 illustrates the general opener with "I see you are planning an event", and ticket 28's own check was to open the sheet on an event and hear about that event. mp-264 puts the launcher on exactly three screens: the main tabs, the meal-planning screen and the formula library, and anything opened over them hides it. The event screen is none of those, so on a device there is no way to open the sheet there: the check could not be run. The server side is built and tested; an event, meal or session screen does produce an opener about the thing in view when a Situation naming it arrives.

**Question.** Should the launcher widen to the screens whose Situation the opener can already speak for (the event, meal and session screens), or should mp-268's example be rewritten to the screens the launcher actually reaches?

**Why.** As it stands the opener's best behaviour is unreachable by hand, and the ticket carries a check nobody can perform.

**What it touches.** The launcher's allow-list, the general opener, the event, meal and session screens.

> 2026-09-15 opened in wave 4 ticket 28
> 2026-09-20 answered by mp-421
> 2026-09-23 clarity pass (context)

## mp-393 · Vana's carb total disagreed with the editor's
- category: Situation awareness
- kind: question
- status: answered
- linked: mp-274
- image: none
- caption:
- screen: Formula editor
- source: wave mealplanning 5 ticket 17

**Context.** On the simulator, a saved formula was edited from two bagels to two and a half without saving. The editor's strip read 133g carbs. Ask Vana opened a new conversation whose opener offered "Adjust this bagel formula", so the draft reached her, but asked for the total she answered "Does 142g carbs work for you, or adjust it?".

**Question.** Why do the two totals differ, and which one should the athlete see?

**Why.** The point of the draft on the wire is that Vana sees what is on screen; two totals for one screen undoes that.

**What it touches.** situation.ts, the formula editor's macro strip.

> 2026-09-16 opened in wave 5 ticket 17
> 2026-09-20 answered by mp-422
> 2026-09-23 clarity pass (question)

## mp-394 · Should the editor's conversation open on the formula?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-268
- image: none
- caption:
- screen: Formula editor
- source: wave mealplanning 5 ticket 17

**Context.** Ask Vana from the editor opens a new general conversation, so she greets with the general opener and offers chips, one of which names the formula.

**Question.** Should the editor's entry open on the formula itself, the way the sheet opens on the screen underneath?

**Why.** The athlete pressed a button on a formula; the first line could say so.

**What it touches.** The general opener, the formula editor's entry.

> 2026-09-16 opened in wave 5 ticket 17
> 2026-09-20 answered by mp-421

## mp-395 · The stored coach insight is never refreshed again
- category: Process and scope
- kind: question
- status: answered
- linked: mp-209
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 17

**Context.** The insight panel is gone and nothing writes a new insight, but the columns, their readers and the flag that used to gate the feature are still in the code and on the rows.

**Question.** Should the old coach-insight columns and the code that reads them be removed, or left as an old record?

**Why.** A column nothing writes still shows old text to whoever reads it.

**What it touches.** The formulas repository, the insight columns, the old feature flag.

> 2026-09-16 opened in wave 5 ticket 17
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question)

## mp-396 · Is a 40-character cap on the formula's name enough?
- category: Situation awareness
- kind: question
- status: answered
- linked: mp-274
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 17

**Context.** When the athlete asks Vana from the formula editor, the formula's name travels with the message. It is the only free text the app ever sends, capped at 40 characters and otherwise sent as typed.

**Question.** Is a 40-character cap enough for the formula name Vana is sent, or should the name be cleaned up further first?

**Why.** mp-043 keeps free text off the wire; this is its one exception.

**What it touches.** situation.ts, the draft on the wire.

> 2026-09-16 opened in wave 5 ticket 17
> 2026-09-20 answered by mp-422
> 2026-09-23 clarity pass (question, context)

## mp-397 · Can the athlete choose their meal types in Vana settings?
- category: Plan tab
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: Vana settings
- source: wave mealplanning 5 ticket 30

**Context.** mp-231 clause 1 says a plan covers only the meal types the athlete plans, in their order (the code calls this list the walk). Vana can save that list in conversation, but the settings screen has no control for it.

**Question.** Does Vana settings get a meal-type picker, as its own ticket?

**Why.** A setting only a conversation can change is invisible to most people.

**What it touches.** Vana settings, the walk setting.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425
> 2026-09-23 clarity pass (question, context)

## mp-398 · Should "every meal" count four slots a day?
- category: Plan tab
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** Plan coverage counts more meal types only when the athlete has chosen their meal types. An athlete who told Vana they plan "every meal" still has only lunch and dinner counted, with breakfast and snacks left to their macro targets.

**Question.** Should "every meal" count four meals a day?

**Why.** It is the one place the old scope and the new walk disagree.

**What it touches.** Coverage on both sides, the review sheet.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425
> 2026-09-23 clarity pass (question, context)

## mp-399 · Without batch cooking, a meal counts one night, whatever the servings
- category: Plan tab
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** Without batch cooking, a meal covers one night however many servings it makes, so an athlete cooking two servings for a partner reads as one night covered.

**Question.** Should two servings cooked without batch cooking count as two nights covered?

**Why.** It decides what the review sheet tells a couple who cook together.

**What it touches.** Coverage on both sides, the review sheet.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425
> 2026-09-23 clarity pass (question, context)

## mp-400 · The one-tap draft has no tap yet
- category: The planning conversation
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 5 ticket 30

**Context.** mp-231 says one tap drafts the Plan period from what the athlete ate last time. The server can already do it, but no button sends it: today the athlete has to ask Vana in words.

**Question.** Where does the tap live: a quick reply, a button on the Plan tab, or the plan bar?

**Why.** The decision says one tap, and there is not one.

**What it touches.** The Plan tab, the Vana sheet, the one-tap draft.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425
> 2026-09-23 clarity pass (question, context)

## mp-401 · Suggestions do not yet favour meals the athlete liked or cooked
- category: Meals tab and library
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** An approved rule (mp-231, clause 5) opens with "suggestions give the highest weight to meals the athlete has liked or already cooked". The ticket that built the one-tap Draft left the suggestion ranking untouched, and its acceptance criteria never named it.

**Question.** Should Vana's suggestions start favouring meals the athlete liked or cooked now, and under which ticket?

**Why.** Half a clause of an approved decision is unbuilt and nothing tracks it.

**What it touches.** The meal search ranking.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425
> 2026-09-23 clarity pass (question, context)

## mp-402 · The staples check still assumes fourteen meals
- category: Plan tab
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** When Vana checks whether the athlete's Staples fill the plan and has no plan coverage to read, she still assumes fourteen meals, the fixed number ticket 30 exists to remove.

**Question.** Should that check use the athlete's period, or say nothing when it has no coverage?

**Why.** It is the last fourteen left in the planning path.

**What it touches.** The planning tools, the staples diagnosis.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425
> 2026-09-23 clarity pass (question, context)

## mp-403 · A draft with only a sub-phase, duration or activity reads as empty
- category: Situation awareness
- kind: question
- status: answered
- linked: mp-274
- image: none
- caption:
- screen: Formula editor
- source: wave mealplanning 5 ticket 17

**Context.** The server tells Vana a formula draft is empty when it has no name, no phase and no foods, even when the athlete has already chosen a sub-phase, a duration or an activity. Vana is told there is nothing in it, while the screen shows those choices.

**Question.** Should Vana describe such a draft by what is set, rather than call it empty?

**Why.** It is the first thing an athlete sets, and Vana is told it is not there.

**What it touches.** situation.ts, the formula editor's conversation.

> 2026-09-16 opened in wave 5 ticket 17
> 2026-09-20 answered by mp-422
> 2026-09-23 clarity pass (question, context)

## mp-404 · The shared coverage test hands over the answer instead of testing it
- category: Plan tab
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** The server and the app both read one shared test file so their plan coverage agrees. For athletes who never chose meal types, the file hands the app the list the server worked out, so the working-out itself, the part most likely to drift apart, is never compared between the two.

**Question.** Should the shared test file carry only the inputs, so each side works out the meal types itself?

**Why.** A shared fixture that hands over the answer proves less than it looks.

**What it touches.** The coverage fixture, both coverage seams.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425
> 2026-09-23 clarity pass (question, context)

## mp-405 · A fuelling conformance test is red before this wave
- category: Process and scope
- kind: question
- status: answered
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 5 ticket 30

**Context.** One test in the fuelling conformance suite fails. On the create-workout screen, the fuelling window stepper held at its limit should show the caption "Capped: session in …" and shows "1 h — early start" instead. It fails the same way at this wave's starting commit, so this wave did not cause it, and it sits beside the two failures already known to come from the test machine.

**Question.** Is the caption rule wrong or the test out of date, and who fixes it?

**Why.** A red test nobody owns trains everyone to read red as normal.

**What it touches.** The fuelling window authority, the create-flow conformance test.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question, context)

## mp-410 · Do the meals behind Show more count as shown?
- category: The planning conversation
- kind: question
- status: answered
- image: none
- caption:
- screen: none (contract)
- source: wave mealplanning 6 ticket 31
- linked: mp-230

**Context.** mp-230 says Other options never offers a meal already shown in the conversation. A Meal picker shows a few meals, and Show more opens a sheet with up to 24 more from the same search. Those 24 are not marked shown, because the server cannot tell whether the sheet was opened, and marking 24 meals per picker would use up later suggestions fast. So an athlete who read the sheet may be offered one of its meals again.

**Question.** Do the meals behind Show more count as shown: always, only once the sheet is opened, or never?

**Why.** It is a one-line change either way, and only a device pass will say which feels wrong.

**What it touches.** tools.ts.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-426
> 2026-09-23 clarity pass (question, context)

## mp-411 · Show more holds at most 24 meals and is hidden when nothing is left
- category: The planning conversation
- kind: question
- status: answered
- image: none
- caption:
- screen: vana-sheet
- source: wave mealplanning 6 ticket 31
- linked: mp-230

**Context.** mp-230 says a Meal picker always has Show more and fixes no count for it. The build holds at most 24 meals behind it, and when a filtered search leaves none, it does not draw the chip at all.

**Question.** Is a cap of 24 meals acceptable, and when nothing is left behind Show more, should the chip still show and say so, or be hidden?

**Why.** The review read the clause as unconditional; the build read an empty sheet as not a door.

**What it touches.** tools.ts, picker_chips.dart, vana_part_renderer.dart.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-426
> 2026-09-23 clarity pass (question, context)

## mp-412 · A tick in the Show more sheet does not reach the picker's meals
- category: The planning conversation
- kind: question
- status: answered
- image: none
- caption:
- screen: vana-sheet
- source: wave mealplanning 6 ticket 31
- linked: mp-230

**Context.** The Show more sheet copies the list of picked meals when it opens. A meal ticked in the sheet goes into the Draft, but the picker behind it does not mark it picked until Vana's next message arrives. A meal ticked on the picker while the sheet is open shows unticked in the sheet.

**Question.** Should the picker and the sheet share one live list of picked meals, or is catching up on Vana's next message enough?

**Why.** mp-230 clause 3 gives picked tiles a swap circle; across the two surfaces that is only half honoured.

**What it touches.** picker_more_sheet.dart, vana_part_renderer.dart.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-426
> 2026-09-23 clarity pass (question, context)

## mp-413 · The persona text is edited here and not in the prototype
- category: Process and scope
- kind: question
- status: answered
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 6 ticket 31

**Context.** The file that holds Vana's persona text (persona.ts) says its text is copied word for word from the prototype and must be edited in both places. Wave 6 edited it here only; the prototype repo was outside the agent's working copy.

**Question.** Is the prototype's copy of Vana's persona text still a source of truth, or can the note go?

**Why.** A note that says "edit both" and is obeyed by nobody is a trap.

**What it touches.** persona.ts.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question, context)

## mp-414 · The Meal picker's Show more sheet is a plain modal, not a glass sheet
- category: Design system
- kind: question
- status: answered
- image: none
- caption:
- screen: vana-sheet
- source: wave mealplanning 6 ticket 31

**Context.** The Vana sheet spec says every sheet summoned over the app takes the glass-sheet material and its dimming. The Meal picker's Show more sheet shows meal cards and the Add button on the app's plain modal, and names no material from the design tokens.

**Question.** Does the Show more sheet take the glass-sheet material, or is a summoned list sheet exempt?

**Why.** The standards review flagged it as a check for design-sync, not a breach of the current text.

**What it touches.** picker_more_sheet.dart, the vana-sheet spec.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question, context)

## mp-415 · A cloned wave simulator lands on the paywall
- category: Process and scope
- kind: question
- status: answered
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 6 ticket 31

**Context.** The ticket's device check claimed a pool simulator, built and launched the branch on it, and sat on the Pro paywall: a freshly cloned simulator has no StoreKit receipt, Restore purchases finds nothing, and the debug wrench does not get past it. Meal-planning surfaces were unreachable, so the check was not run. Both halves of the ticket also arrive on the wire from vana-chat, which no wave deploys.

**Question.** How does a wave agent get past the paywall on a fresh simulator: copy the dev simulator's purchase, add a dev-only bypass, or check Pro screens on the dev simulator after the wave?

**Why.** Every remaining meal-planning ticket sits behind the paywall.

**What it touches.** sync.mjs simulator claim, the dev paywall gate.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-428
> 2026-09-23 clarity pass (question)

## mp-419 · The memory build after mp-277 stands, and its four open questions are answered
- category: Vana's memory
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-419.svg
- screen: none (algorithm/data)
- source: spec.md; ticket 03; memory 09-10; memory 09-11; commit 1dedc493; wave mealplanning 1 ticket 13; wave mealplanning 2 ticket 14; wave mealplanning 3 ticket 15
- work: pending
- linked: mp-315; mp-334; mp-349; mp-351

**Context.** On 14 September Lee held six memory cards and asked for a rethink. On 15 September he approved mp-277 (history in chunks, notes saved as they are said, an Episode when a conversation goes idle), and tickets 13 to 15 built it. This card replaces the six held cards, ratifies what the tickets built, and answers the four questions the build left open. Approving this changes mp-020, mp-023, mp-277 and mp-288: Vana's context block is kept and rebuilt only after a change made through Vana or on a new day, so a thumbs vote or profile edit made outside Vana no longer reaches her on the very next turn, and a conversation that gains messages gets its Episode written again rather than once.

**Question.** Is the memory build that followed mp-277 right, and how are its four open questions answered?

**Decision.** Yes. What tickets 13 to 15 built stands, and the five held cards mp-277 replaced are retired: past conversations reach Vana as a LAST TALKS line of what the athlete said, long chats are summarised twenty messages at a time, the server answers an idle signal at once and writes the summary in the background, and the context block is capped at 1,500 estimated tokens. The four answers: the conversation list previews each chat with its one-sentence Episode, never the internal "Through message 20..." text; a chat that gains messages after its Episode is summarised again at the next close; a home location, a thumbs vote or a profile edit made outside Vana waits for the next change made through Vana or the next day; and the "Remembered" card shows only when the athlete asked Vana to remember. Example: an athlete plans on the morning of 8 October, closes the sheet, and talks again that night; at the second close the conversation is summarised again, so its one Episode covers the evening too.

**Why.** One card instead of fourteen. Clauses 4, 6 and 9 are the only new work; the rest is already in the code and on dev.

**What else was considered.** Ruling each of the fourteen cards separately.

**What it touches.** vana-chat history and summary, the context block, the conversation list, the Remembered card.

**Details.** Precisely:
1. The five held cards about the 20-message replay and the mid-conversation episode are retired. mp-277 replaced them. (mp-032 to mp-036) [no work]
2. Past conversations reach Vana as a LAST TALKS line: what the athlete said, not a read-out of their schedule. Memories hold only notes. (mp-038) [built]
3. A long conversation is summarised in chunks of twenty messages and the summary is kept on the conversation. (mp-333) [built]
4. The conversation list previews each conversation with its one-sentence summary. The internal "Through message 20…" text never shows on screen. (mp-334) [to build]
5. When the app says a conversation is idle, the server answers at once and writes the summary in the background. A repeat signal writes nothing. (mp-347) [built]
6. If a conversation gains messages after its summary was written, the next close summarises it again. One summary per conversation, always the latest. (mp-349) [to build]
7. Only a change the athlete makes through Vana, or a new day, rebuilds the cached context. Notes the server writes for itself do not. A home location, a thumb or a profile edit made outside Vana waits for the next of those. (mp-313, mp-315) [built]
8. The context block is capped at 1,500 estimated tokens, and a test fails if it grows past that. (mp-314) [built]
9. The "Remembered" card shows only when the athlete asked Vana to remember something. Notes she saves on her own stay silent, as mp-027 already says. (mp-351) [to build]

Summary boundaries are fixed multiples of twenty so the cached prefix changes once per chunk. Context budget constant CONTEXT_BLOCK_TOKEN_BUDGET = 1500, estimated as characters / 4. Idle is answered 202 and never charged a credit.

> 2026-09-20 folded from mp-032, mp-033, mp-034, mp-035, mp-036, mp-038, mp-313, mp-314, mp-333, mp-347; answers mp-315, mp-334, mp-349, mp-351
> 2026-09-22 rewritten in plain words (question, decision, details)
> 2026-09-23 clarity pass (context, decision)
> 2026-09-23 clarity pass (context)

## mp-421 · Vana opens on a live moment first, then the screen underneath, then the personal opener
- category: Vana's voice and openers
- status: proposed
- image: none
- noshot: a test image: its words render as blocks
- svg2: docs/ssot/decisions/images/mealplanning/mp-421-2.svg
- screen: Vana sheet
- source: wave mealplanning 4 ticket 27; wave mealplanning 4 ticket 28
- work: pending
- linked: mp-352; mp-367; mp-368; mp-369; mp-377; mp-384; mp-394

**Context.** mp-268 says the general conversation opens on the screen underneath. Ticket 28 built it and left seven questions about which screen, which order and which chips. On 09-16 you also ruled that Vana drafts every opener herself and never picks from templates. Approving this changes mp-268 (the general conversation opens on the screen underneath): a live moment now comes before the screen underneath.

**Question.** What does Vana open on in each place, and what happens when the athlete asks for a plan?

**Decision.** Vana speaks first to a live moment (a fuelling window around a session), then to the screen underneath, then with the personal opener. A request for a plan is handed off, which means Vana shows a button that opens the meal-planning screen, and any constraint the athlete gave goes along; when an opener offers a meal plan, that offer is itself the button. The Plan tab with a plan in view opens on that plan, Ask Vana from the formula editor opens on the formula, and the full-screen chat asks for an opener the way the sheet does. Example: an athlete types "quick dinners this week"; Vana treats it as a plan request and hands off to the meal-planning screen with "quick dinners" carried along.

**Why.** Each answer follows a ruling you already made: the screen underneath (mp-268), three launcher screens (mp-264), hand-offs for every flow the app owns (mp-265).

**What else was considered.** Widening the launcher to event, meal and session screens (clause 8). Letting the screen underneath outrank a live moment (clause 1).

**What it touches.** The opener path in vana-chat, the sheet, the full-screen chat, the Plan tab, the formula editor.

**Details.** Precisely:
1. The order is: a live moment (a fuelling window) first, then the screen underneath, then the personal opener. (mp-364, mp-368) [built]
2. A request for a plan is a plan request even with a constraint ("quick dinners this week"). Vana hands off to the meal-planning screen and the constraint goes with it. (mp-363) [built]
3. When the opener offers to start a meal plan, that offer is the hand-off button itself. No chip that then produces a button. (mp-377) [to build]
4. The Plan tab with a plan in view opens on that plan. (mp-367) [to build]
5. Ask Vana from the formula editor opens on the formula. (mp-394) [to build]
6. The full-screen chat asks for an opener the same way the sheet does, instead of opening empty. (mp-369) [to build]
7. Picking up last time in an offer chip counts. The opener's sentence does not have to say it as well. (mp-352) [no work]
8. The launcher stays on its three screens (mp-264). mp-268's example of opening on an event is reached through the hand-off, not by putting the launcher on the event screen. (mp-384) [no work]

"The screen says something useful" is decided by resolving the Situation with and without the entity id: a different sentence means the athlete's own row was read. The opener logs which of the three paths fired.

> 2026-09-20 folded from mp-363, mp-364; answers mp-352, mp-367, mp-368, mp-369, mp-377, mp-384, mp-394
> 2026-09-22 rewritten in plain words (question, decision, details)
> 2026-09-23 clarity pass (context)
> 2026-09-23 screenshot removed: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png (a test image: its words render as blocks)

## mp-422 · Vana repeats the formula editor's carb total, and the editor sends its draft as fixed fields
- category: Situation awareness
- status: proposed
- image: none
- noshot: an empty new formula, not a draft
- svg2: docs/ssot/decisions/images/mealplanning/mp-422-2.svg
- screen: Formula editor, Plan tab
- source: wave mealplanning 5 ticket 17
- work: pending
- linked: mp-370; mp-371; mp-393; mp-396; mp-403

**Context.** mp-273 gives every entry point the same athlete context plus one short section for what is on screen. mp-274 lets the formula editor send its unsaved draft. Tickets 16 and 17 built both. On the simulator Vana said 142 g of carbs for a draft the editor showed as 133 g.

**Question.** What do the formula editor and the Plan tab tell Vana, and whose carb total does she use?

**Decision.** The formula editor sends its unsaved draft as a fixed set of fields with foods as ids, and the server looks the names up in the athlete's own foods. Vana is handed the editor's own carb total and repeats it, never adding it up herself, and a draft that only has its sub-phase, duration or activity set is described by those, not called empty. The Plan tab tells her about the day on screen plus one line on the week's servings left, and her standing instructions name that part of her notes in one sentence. Example: on the simulator the editor showed 133 g of carbs for an edited bagel formula and Vana said 142 g; once this is built she says 133 g.

**Why.** Clause 3 is a bug an athlete would see. Fuelling numbers never come from the model (mp-005), so the fix is to hand her the app's number.

**What else was considered.** Letting Vana compute totals from the quantities. Sending the whole week in the Plan tab section.

**What it touches.** The Situation resolver, the formula editor, the Plan tab section, the persona.

**Details.** Precisely:
1. The formula editor sends its draft as fixed fields only: phase, sub-phase, durations, activities, component ids with quantities, and a name of at most 40 characters. A draft from any other screen is dropped without an error. (mp-385, mp-396) [built]
2. The server looks the component names up from the athlete's own foods. The app sends ids, never names. (mp-385) [built]
3. The formula section carries the editor's own carb total. Vana repeats that number and never adds it up herself, so the two can never disagree. (mp-386, mp-393) [to build]
4. A draft that has a scope (a sub-phase, a duration or an activity) is described by that scope, not called empty. (mp-403) [to build]
5. The Plan tab's section speaks for the day on screen, plus one line on the week's servings left. (mp-371) [to build]
6. The persona names the in-view section in one sentence, the way it names the Situation. (mp-370) [to build]

> 2026-09-20 folded from mp-385, mp-386; answers mp-370, mp-371, mp-393, mp-396, mp-403
> 2026-09-21 picture captured at 1.27.0+3, 18e21789
> 2026-09-22 rewritten in plain words (question, decision, details)
> 2026-09-23 clarity pass (decision)
> 2026-09-23 screenshot removed: docs/ssot/decisions/images/mealplanning/formula-editor.png (an empty new formula, not a draft)

## mp-423 · The launcher, the sheet and Vana's hand-offs stand as built, with three gaps to close
- category: The sheet and launcher
- status: proposed
- image: none
- noshot: the launcher is hidden under two dev buttons
- svg2: docs/ssot/decisions/images/mealplanning/mp-423-2.svg
- screen: Vana sheet
- source: wave mealplanning 1 ticket 23; wave mealplanning 3 ticket 15; wave mealplanning 4 ticket 16; wave mealplanning 4 ticket 27; wave mealplanning 5 ticket 17
- work: pending
- linked: mp-350; mp-372; mp-373; mp-374; mp-375; mp-376

**Context.** mp-264 put the launcher on three screens, mp-265 gave the sheet one height and made every job the app has a screen for into a button to that screen, and mp-275 said which ways in continue the day's conversation. Tickets 15, 16, 17, 23 and 27 built them. This card confirms the build and answers six questions it raised.

**Question.** Does the build of the launcher, the sheet and Vana's hand-offs stand, and what is left?

**Decision.** Yes, as built, with three things still to build. The launcher shows on the main tabs, the meal-planning screen and the formula library, and the sheet takes three quarters of the screen. Vana offers a Hand-off only when she can name what it is for: with no event named she asks which one, a carb-loading hand-off opens that event's carb-loading picks, and a fuelling hand-off edits the workout she named instead of adding a second one. Example: an athlete asks about carb loading without naming an event, so Vana asks which event first; once it is named, her button opens the carb-loading picks for that event.

**Why.** Clauses 1 to 3 and 7 are in the code. Clauses 4 to 6 finish the hand-off so it never lands somewhere useless.

**What else was considered.** Landing on a blank form when no entity is named. Keeping carb loading on the event screen.

**What it touches.** The launcher rule, the sheet, the hand-off part, the ambient conversation controller, the carb-loading picks, the new-activity screen.

**Details.** Precisely:
1. The launcher shows on the main tabs, the meal-planning screen and the formula library, and hides whenever anything is pushed or popped over them. No screen has to name itself. (mp-326) [built]
2. The sheet is three quarters of the screen. It closes by the platform's own rule, a drag past half or a flick. The grabber is only a handle. (mp-361) [built]
3. A hand-off is a button Vana offers, labelled in the athlete's own words (60 characters at most), that opens the screen that owns the job: meal plan, new activity, event. It works in the full-screen chat too. (mp-362) [built]
4. Vana offers a hand-off only when she can name the thing. With no event named she asks which one, instead of landing on a blank form or a bare list. (mp-374) [to build]
5. A carb-loading hand-off opens the carb-loading picks for that event directly. (mp-373) [to build]
6. A fuelling hand-off edits the workout Vana named and never creates a second one. This gets checked on the simulator. (mp-375) [to build]
7. One controller decides which conversation is "today's". New meal plan, the plus button and Ask Vana in the formula editor each start a new conversation and never move that pointer. (mp-360, mp-387, mp-372) [built]
8. The app tells the server a conversation is idle when the sheet closes, the app goes to the background, a new conversation starts, or the athlete leaves the full-screen chat. At most once per opening. (mp-348, mp-350) [built, except leaving the full-screen chat]
9. Closed as already done: two new conversations sharing one screen was fixed on 09-16 (761d4d6f), and the status chip question is gone because you had the chip deleted on 09-16. (mp-372, mp-376) [no work]

Launcher rule test walks every route the router declares. Hand-off targets: meal plan -> meal-planning page, fuelling -> new-activity screen, event and carb loading -> event screen (today).

> 2026-09-20 folded from mp-326, mp-348, mp-360, mp-361, mp-362, mp-387; answers mp-350, mp-372, mp-373, mp-374, mp-375, mp-376
> 2026-09-22 rewritten in plain words (question, context, decision, details)
> 2026-09-23 clarity pass (question, decision)
> 2026-09-23 screenshot removed: docs/ssot/decisions/images/mealplanning/timeline-launcher.png (the launcher is hidden under two dev buttons)

## mp-424 · Each plan keeps the period it was made for, and periods follow one another
- category: Plan tab
- status: proposed
- image: none
- noshot: the top of Settings, which shows none of this
- svg2: docs/ssot/decisions/images/mealplanning/mp-424-2.svg
- screen: Vana settings
- source: wave mealplanning 4 ticket 29; wave mealplanning 4 ticket 16
- work: pending
- linked: mp-378; mp-379; mp-380; mp-381; mp-382

**Context.** You approved mp-269: the week's start day and the period's length are the athlete's settings. Ticket 29 built them. Seven days from Sunday was the only shape the code knew, so a ten-day period raised five questions.

**Question.** How does a plan period behave when it is not seven days from Sunday?

**Decision.** The athlete sets the start day and a length of 3 to 14 days in Vana settings, and everything that works out a week or a cook day uses them. Periods run one after another with no overlap, and each plan records the period it was made for, so changing a setting never changes a plan already made; a new start day applies from the next period. Reminders name the athlete's own days, and Vana can change both settings when asked in chat. Example: on ten-day periods starting Sunday 4 October, the first runs to 13 October and the next starts 14 October; if the athlete switches to a Monday start on 18 October, the plan for 14 to 23 October stays as it is and Monday applies from the period after.

**Why.** Clauses 3 to 5 are one fix: once a plan carries its own period, overlap and mid-period changes stop being problems.

**What else was considered.** Keeping a weekly cadence with overlapping periods. Moving the current plan when the start day changes.

**What it touches.** Vana settings, the Plan tab, the plan row (one new column), coverage, reminders, Vana's settings tool.

**Details.** Precisely:
1. The two settings sit in Vana settings: a popup of the seven days and a stepper from 3 to 14 days. Cooking labels use the athlete's own day ("Cook Monday"). (mp-366, mp-365) [built]
2. Every place that works out a week or a cook day reads the athlete's period, never the Sunday default. (mp-358) [built]
3. Periods follow each other with no overlap. A ten-day period is followed by the next ten-day period, starting where the last one ended. (mp-379) [to build]
4. A plan records the period it was built for, so changing the setting never re-reads an old plan. (mp-380) [to build]
5. Changing the start day mid-period leaves the current plan alone until it ends. The new setting applies from the next period. (mp-378) [to build]
6. The reminder text names the athlete's own days. (mp-381) [to build]
7. Vana can change both settings in conversation ("my week starts Monday"). (mp-382) [to build]

Length limited to 3 to 14 days: below three the three cooking sessions collapse onto one day. The period length travels on the coverage wire and the week part.

> 2026-09-20 folded from mp-365, mp-366, mp-358; answers mp-378, mp-379, mp-380, mp-381, mp-382
> 2026-09-22 rewritten in plain words (question, decision, details)
> 2026-09-23 screenshot removed: docs/ssot/decisions/images/mealplanning/settings.png (the top of Settings, which shows none of this)

## mp-425 · A batch is three meals per meal type, each sized to a third of the period
- category: Plan tab
- status: proposed
- image: none
- noshot: an empty Plan tab that shows none of this
- svg2: docs/ssot/decisions/images/mealplanning/mp-425-2.svg
- screen: Plan tab
- source: wave mealplanning 5 ticket 30
- work: pending
- linked: mp-397; mp-398; mp-399; mp-400; mp-401; mp-402; mp-404

**Context.** You approved mp-231: a plan fills a cooking period, not fourteen fixed slots. Ticket 30 built it and left seven questions.

**Question.** How is a plan sized to its period?

**Decision.** With batch cooking on, the athlete cooks three meals per meal type, and each makes the period's days divided by three, rounded up, in servings: 3 for 7 days, 4 for 10, 5 for 14; without batch cooking, each pick is one serving. Plan coverage counts the period's days times the meal types the athlete plans, and anyone who never chose keeps lunch and dinner. "Same as last time" copies last period's meals at the servings they were cooked at, from a button on an empty Plan tab or from Vana's planning opener. Example: a 10-day period with lunch and dinner is counted as 20 meals, and three lunches and three dinners at 4 servings each give 24 servings.

**Why.** Clauses 1, 2, 5 and 9 are built. The rest finish mp-231 where ticket 30 stopped.

**What else was considered.** Rescaling copied meals to the new period (invented numbers). Defaulting every pick to four servings.

**What it touches.** The Plan tab, coverage on both sides, the planning conversation, Vana settings, suggestion ranking.

**Details.** Precisely:
1. A batch is three meals per meal type. Servings are the period divided by three, rounded up: 7 days gives 3, 10 gives 4, 14 gives 5. A per-day planner gets one serving per pick. (mp-389) [built]
2. Coverage counts the period's days times the meal types the athlete plans. Someone who never chose keeps lunch and dinner, so existing plans' numbers do not move. (mp-390) [built]
3. Choosing "every meal" counts four slots a day. (mp-398) [to build]
4. A per-day planner cooking two servings covers two nights, not one. (mp-399) [to build]
5. "Same as last time" copies last period's meals at the servings they were cooked at and never doubles a meal already in the draft. (mp-391) [built]
6. Its tap is a button on the Plan tab's empty week, and Vana offers it in the planning opener. (mp-400) [to build]
7. Suggestions rank liked and already-cooked meals first, as mp-231 says. This gets its own ticket. (mp-401) [to build]
8. Vana settings gets a meal-type picker, so the athlete can choose what they plan without asking Vana. (mp-397) [to build]
9. A plan with no cooking mode on it means batch, in the app and on the server. (mp-392) [built]
10. Where coverage is unknown the staples check says nothing, instead of assuming fourteen slots. The shared test fixture carries the inputs so both sides work the answer out themselves. (mp-402, mp-404) [to build]

> 2026-09-20 folded from mp-389, mp-390, mp-391, mp-392; answers mp-397, mp-398, mp-399, mp-400, mp-401, mp-402, mp-404
> 2026-09-21 picture captured at 1.27.0+3, 18e21789
> 2026-09-22 rewritten in plain words (question, decision, details)
> 2026-09-23 clarity pass (question, decision)
> 2026-09-23 screenshot removed: docs/ssot/decisions/images/mealplanning/plan-tab.png (an empty Plan tab that shows none of this)

## mp-426 · Named chips replace only the two reply chips, and Show more holds up to 24 more meals
- category: The planning conversation
- status: proposed
- image: none
- noshot: a test image: its words render as blocks
- svg2: docs/ssot/decisions/images/mealplanning/mp-426-2.svg
- screen: Planning conversation
- source: wave mealplanning 6 ticket 31
- work: pending
- linked: mp-410; mp-411; mp-412

**Context.** You approved mp-272 (a turn may name the chips it expects next) and mp-230 (Show more opens many more options from the same search). Ticket 31 built both. Approving this narrows mp-272 and mp-230: Vana's named chips replace only the two reply chips, and Show more holds at most 24 meals and is not drawn when none are left, where mp-230 fixed no count and always showed it.

**Question.** Which chips can a turn name, and what sits behind Show more?

**Decision.** Chips Vana names replace only "I like these" and "Other options"; the other chips and the filters stay, and a turn with no picker names none. The server and the app both cut her list to two to four chips, and a broken list falls back to the app's own. Show more opens the rest of the same search, up to 24 more meals with no new search, and is not drawn when nothing is left; those meals count as shown only if the athlete opened the sheet, and a tick in the sheet shows on the picker's meals at once, and the other way round. Example: an athlete never opens Show more, so the up to 24 meals behind it are not counted as shown and Other options can still offer them later.

**Why.** Clauses 1 to 3 are built. Clause 6 is the one an athlete would notice.

**What else was considered.** Marking all 24 meals as shown whether or not the sheet was opened, which starves later suggestions.

**What it touches.** The picker part, the Show more sheet, the planning conversation.

**Details.** Precisely:
1. A turn's named chips replace only the two reply chips ("I like these", "Other options"). The doors and filters stay. Chips belong to a picker, so a turn without a picker names none. (mp-406, mp-409) [built]
2. Both the server and the app trim the list to two to four chips. A broken list means the app shows its own set. (mp-408) [built]
3. Show more opens the rest of the same search, up to 24 more meals, with no new query. (mp-407) [built]
4. Meals behind Show more count as shown only if the athlete opened the sheet. (mp-410) [to build]
5. When nothing is left behind Show more, the chip is not drawn. 24 is enough. (mp-411) [no work]
6. A tick in the Show more sheet shows on the tiles behind it at once, and the other way round. (mp-412) [to build]

> 2026-09-20 folded from mp-406, mp-407, mp-408, mp-409; answers mp-410, mp-411, mp-412
> 2026-09-22 rewritten in plain words (question, decision, details)
> 2026-09-23 clarity pass (context)
> 2026-09-23 screenshot removed: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png (a test image: its words render as blocks)

## mp-427 · Admins review meals, every recipe names where its steps came from, and feedback to Vana goes to Wiredash
- category: Meals tab and library
- status: proposed
- image: none
- noshot: shows no origin line
- svg2: docs/ssot/decisions/images/mealplanning/mp-427-2.svg
- screen: Meal detail
- source: wave mealplanning 1 ticket 25; wave mealplanning 2 ticket 32; wave mealplanning 1 ticket 26
- work: pending
- linked: mp-330; mp-346; mp-332

**Context.** Three approved features were built on dev: the admin review box on every meal (mp-144, clause 3), the line saying where a recipe's steps came from (mp-146), and feedback typed to Vana reaching Wiredash (mp-245, clause 6). Tickets 25, 26 and 32 built them, and each left one question (mp-330, mp-346, mp-332), which this card answers. It changes no approved card.

**Question.** How are admin meal reviews, the recipe origin line and typed feedback to Wiredash finished?

**Decision.** Admins get a review box on every meal (Good recipe or Not good, a reason, Send) that says sent only once the server has it, and the team reads the reviews in the database, each stamped with the app version. Every recipe says in one line under Directions where its steps came from, and that line is its only link to the original, so the older "See the original recipe" row goes. Feedback typed to Vana lands in Wiredash, the team's bug-report inbox, beside reports sent by shaking the phone and labelled "vana-chat"; Wiredash has no public way to do this, so the app uses its internal code with the version pinned. Example: an admin marks Egg & Veggie Scramble Not good, gives a reason and taps Send; the box says sent once the server has the review, and the review carries the app version.

**Why.** All three are small and already on dev.

**What else was considered.** Building a review screen now. Keeping both links to the original recipe.

**What it touches.** Meal detail, the meal_reviews table, the recipe screen, Vana's feedback tool, Wiredash.

**Details.** Precisely:
1. An admin sees a review box on every meal: Good recipe or Not good, a reason, Send. Reviews wait for the server before saying sent. Only admins can read them. (mp-329) [built]
2. The team reads reviews in the database for now. Each row gets the app version. No screen until there are enough reviews to need one. The table goes to production with the cutover. (mp-330) [to build: the version stamp]
3. A recipe says where its steps came from in one line under Directions: "As published by X" with a link, "Steps from X", or "A simple assembly, no recipe needed". AI-written steps keep the sparkle. (mp-345) [built]
4. A published recipe links the original once, from the new label. The older "See the original recipe" row goes, which also removes the overflow on narrow phones. (mp-346) [to build]
5. Feedback typed to Vana is filed to the same Wiredash inbox as a shaken report, from the device, with the label "vana-chat" so the inbox can filter it. (mp-331, mp-332) [built, except the label]
6. Wiredash has no public way to file an entry without its screen, so the app uses the SDK's internals with the version pinned. Ask Wiredash for a public call. Every Wiredash upgrade re-checks the filer. (mp-332) [no work]

Review migration 20260916120000 on dev. Reason capped at 2,000 characters. Wiredash metadata: source vana_chat, sentiment, about, conversation id, user id and email.

> 2026-09-20 folded from mp-329, mp-345, mp-331; answers mp-330, mp-346, mp-332
> 2026-09-22 rewritten in plain words (question, context, decision, details)
> 2026-09-23 clarity pass (question, context, decision)
> 2026-09-23 screenshot removed: docs/ssot/decisions/images/mealplanning/meal-detail.png (shows no origin line)

## mp-428 · Fifteen engineering questions are closed together, none of them a product ruling
- category: Process and scope
- status: proposed
- image: none
- noshot: the top of Settings, which shows none of this
- svg: docs/ssot/decisions/images/mealplanning/mp-428-2.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 24; wave mealplanning 5 ticket 17
- work: pending
- linked: mp-322; mp-325; mp-328; mp-339; mp-354; mp-355; mp-356; mp-357; mp-383; mp-395; mp-405; mp-413; mp-414; mp-415; mp-338

**Context.** Build agents are told to raise anything they are unsure of. Fifteen of those questions are about process, tests and tidying, not the product. You said on 09-16 not to park things for your decision, so each gets an answer here. Tick any clause you disagree with.

**Question.** Can the engineering loose ends the build agents raised be closed in one go?

**Decision.** Yes. Fifteen questions the build agents raised about process, tests and tidying are answered together in twelve clauses, and you tick any clause you disagree with. Only one changes what an athlete sees: the Show more sheet gets the same glass look as every other sheet that slides up. The rest settle where the dev-tools switch sits, which checks only a person with a phone can run, how team accounts get past the paywall, and what gets removed, deleted or rewritten. Example: the fuelling conformance test that turned red and green with no code change depends on the time, so it gets a fixed clock.

**Why.** None of these changes what an athlete sees, except the glass sheet. They were making the page look heavier than it is.

**What else was considered.** Ruling each separately.

**What it touches.** Settings, the release doc, the dev entitlement table, the design specs list for Xuan, the conformance suite, persona.ts.

**Details.** Precisely:
1. The dev-tools switch sits in a "Dev build" card on Settings, remembered per device. The card moves up so the floating buttons do not cover it. (mp-327, mp-328) [built, except the move]
2. The coach-insight panel is gone and nothing writes insights any more. The old columns and their readers are removed with the production cutover. (mp-388, mp-395) [to build]
3. A check only a person with a phone can do (a sandbox purchase, a second account) does not fail a ticket. The ticket closes on its tests and the check goes on your simulator and device list. (mp-322) [no work]
4. You declined the sandbox wizard on 09-16. Purchase and Restore are checked by hand on TestFlight before a release (mp-336). The two wizard questions are closed. (mp-354, mp-355) [no work]
5. Team accounts get in through the admin flag you approved (mp-416). An account that also needs Vana's server calls gets a promotional grant in RevenueCat, and the RevenueCat dashboard is the list. This also lets a wave simulator past the paywall. (mp-338, mp-415) [no work]
6. The odd entitlement row on dev was written by hand by a build agent for the test user. It is deleted, and agents are told the webhook is the only writer. (mp-357) [to build]
7. The internal-device flag is written again by the tester switch (meal photos, 09-16), so Mixpanel keeps excluding the team. (mp-339) [no work]
8. The release doc still describes a dark launch behind a flag. It is rewritten to the trial-and-purchase release. (mp-356) [to build]
9. Design specs the app changed (the sheet, the launcher section, the meal mosaic) are written app-side as "proposed, awaiting Xuan", which is the rule you set on 09-11. Xuan is sent the list. (mp-325, mp-383) [to build: the list]
10. The Show more sheet takes the glass-sheet material like every other summoned sheet. (mp-414) [to build]
11. The persona is edited in this repo only. The note about keeping the prototype in step is deleted. (mp-413) [to build]
12. The fuelling conformance test that goes red and green without a code change is time-dependent. It gets a fixed clock. (mp-405) [to build]

Dev-tools key dev.tools_visible. The eval entitlement row: user 37129f7e, period_type "eval", written 2026-09-15 19:05Z.

> 2026-09-20 folded from mp-327, mp-388; answers mp-322, mp-325, mp-328, mp-339, mp-354, mp-355, mp-356, mp-357, mp-383, mp-395, mp-405, mp-413, mp-414, mp-415, mp-338
> 2026-09-22 rewritten in plain words (decision, details)
> 2026-09-23 clarity pass (decision)
> 2026-09-23 screenshot removed: docs/ssot/decisions/images/mealplanning/settings.png (the top of Settings, which shows none of this)
> 2026-09-22 the same drawing was attached twice; the second copy removed

## mp-510 · How a Grant reaches the dev server
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-454
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-510.svg
- screen: none (algorithm/data)
- source: wave paywall 1 ticket 01

**Context.** Ticket 01's last check was a Grant on a dev account showing up in its dev row. RevenueCat logs every Grant as a real (production) event, and dev's RevenueCat connection took test (sandbox) events only, so the Grant (2026-09-21, a throwaway dev account) went to the production webhook, which ignored it. Dev and production share one RevenueCat project. The new webhook is on dev with its secret key set; it simply never hears about Grants.

**Question.** Should dev's RevenueCat connection take events from every environment, so real purchases also reach dev and match no user there, or should Grants be tested another way?

**Why.** Until one way is chosen, no Grant (a coach's, Legacy grace, a giveaway) can be tried on dev end to end, and tickets 06, 07 and 09 all grant.

**What it touches.** RevenueCat's dev webhook integration, tickets 06, 07, 09.

> 2026-09-21 opened in wave 1 ticket 01
> 2026-09-22 answered by mp-533
> 2026-09-23 clarity pass (question, context, why)

## mp-511 · Should the dev Test Store sell the new products?
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-452
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-511.svg
- screen: Paywall
- source: wave paywall 1 ticket 03

**Context.** The dev app on the simulator buys through RevenueCat's Test Store, a pretend store for testing. It holds only the old products, at $9.95 a month and $69.00 a year, in the regular `default` Offering, and nothing in `founding`. So the simulator shows the old prices, cannot show the Founding Month prices, and ticket 03's check of the new prices could not pass. mp-452 clause 4 says the old products leave every Offering.

**Question.** Should the Test Store's two Offerings get the new products, with the old ones taken out, or stay as they are?

**Why.** Until it changes, no simulator check of the paywall's prices or of the Founding Month switch can pass, and every paywall ticket after 03 has one.

**What it touches.** RevenueCat Test Store app, `default` and `founding` offerings, tickets 14 to 18.

> 2026-09-21 opened in wave 1 ticket 03
> 2026-09-23 clarity pass (question, context, why)
> 2026-09-23 answered by mp-610

## mp-512 · Does an account on a Grant get the Monthly budget?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-454
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-512.svg
- screen: none (algorithm/data)
- source: wave paywall 1 ticket 01

**Context.** The webhook adds the monthly budget only on a first purchase or a renewal. A Grant (a coach's 30 days, Legacy grace, a hand Grant) arrives as a promotional event, so a granted account can use Vana but gets no monthly budget. What it can do with Vana then depends on Top-ups it bought before.

**Question.** Should an account that holds Pro through a Grant get the Monthly budget like a paying one, or only what it bought?

**Why.** Legacy grace goes to every account that exists at the flip (mp-429 clause 5), so this decides what those accounts can do with Vana in their first month.

**What it touches.** revenuecat-webhook, the credit wallet, the ai-cost monthly budget (mp-430).

> 2026-09-21 opened in wave 1 ticket 01
> 2026-09-23 clarity pass (question, context, why)

## mp-513 · Is the drafted trial and renewal wording right?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-453
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-513.svg
- screen: Paywall
- source: wave paywall 1 ticket 03

**Context.** mp-453 fixes what the paywall must say, not the words. Ticket 03 drafted the words: the Trial line ("{days} days free … Nothing is charged during the free week"), the renewal line ("Cancel at least 24 hours before it renews…") and the link labels. The Trial line takes its number of days from the store but says "week" in fixed words.

**Question.** Do Lee and Xuan approve the drafted Trial and renewal lines on the paywall as they are, or rewrite them?

**Why.** These lines sit beside the purchase button and go to store review.

**What it touches.** Content defaults `paywall.trial_terms`, `plans_terms`, `renewal_terms`, `founding_line`, the link labels.

> 2026-09-21 opened in wave 1 ticket 03
> 2026-09-23 clarity pass (question, context, why)

## mp-514 · Open the paywall or show an error when AI is refused?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-505
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-514.svg
- screen: none (algorithm/data)
- source: wave paywall 1 ticket 02

**Context.** The five AI functions now refuse an account without Pro with a 'Pro required' answer (mp-505). Only Vana reads that answer. Meal describe and meal photo show "The AI service returned an error. Please try again.", the coach insight and the old chat treat it as a server error, and the photo tool as a different refusal.

**Question.** When the server refuses an AI call because the account has no Pro, should the screen open the paywall (or say the plan has ended) instead of a generic error?

**Why.** A Lapsed athlete can still reach these buttons in the read-only app (mp-429 clause 6), and a "try again" error invites them to retry forever.

**What it touches.** Meal AI service, AI coach client, the old chat repository, the meal photo repository, tickets 11 and 17.

> 2026-09-21 opened in wave 1 ticket 02
> 2026-09-23 clarity pass (question, context, why)

## mp-516 · Only the days a plan change touches get a new note
- category: Plan tab
- status: proposed
- image: none
- noshot: an empty Plan tab that shows none of this
- svg2: docs/ssot/decisions/images/mealplanning/mp-516-2.svg
- screen: Plan tab
- source: wave ai-cost 2 ticket 13
- linked: mp-432

**Context.** The Plan tab shows a Day note from Vana for each of seven days. Until ticket 13, any plan change marked all seven stale and the next open rewrote them all; on the dev backend athletes averaged 3.6 rewrites a day, 13 at the peak. The ticket asked for a rewrite of only the days an edit touched and did not say what "touched" means.

**Question.** Which changes to a plan rewrite which days' notes?

**Decision.** A day's note is rewritten only when something it was written from changes: that day's meals, its workouts or its macro target. A day with no meals assigned is rewritten whenever a meal joins or leaves the plan, because its note may name any meal in the plan; confirming a draft or switching batch cooking rewrites all seven, and marking a meal eaten rewrites none. Opening the Plan tab on an unchanged plan calls no model. Example: swapping Thursday's dinner for another meal rewrites Thursday's note and the notes of days with nothing assigned, and leaves every other day's note alone.

**Why.** The saving comes from writing fewer notes, and a note is only wrong when what it was written from has changed.

**What else was considered.** Rewriting an unassigned day only when a meal is removed, not on a servings change: cheaper, and left as it is until someone rules. Asking the model for all seven and storing only the changed ones, which saves nothing.

**What it touches.** The day-notes module and endpoint, the Plan tab's refresh, one new column and one claim table on meal plans.

**Details.** Precisely:
1. A day's note is rewritten when that day's assigned meals, its workouts or its macro target change. Other days keep their notes.
2. A day with nothing assigned is rewritten when any meal joins or leaves the plan, because its note may name any meal in the plan.
3. Confirming a draft, or switching batch cooking, rewrites all seven.
4. Marking a meal as eaten rewrites nothing.
5. The note for a day with assigned meals is now written from those meals, not from the whole plan.
6. Opening the Plan tab on an unchanged plan calls no model, and two requests at once share one call.

An edit made while notes are being written is picked up on the next open. A request that loses the claim waits up to 25 seconds for the winner's notes, then shows the stored ones. The dev count after the change is owed after a day of use (ticket 13).

> 2026-09-21 proposed from wave 2 of ai-cost
> 2026-09-21 picture captured at 1.27.0+3, 0e20c2f0
> 2026-09-22 rewritten in plain words (question, decision, details)
> 2026-09-23 clarity pass (context)
> 2026-09-23 screenshot removed: docs/ssot/decisions/images/mealplanning/plan-tab.png (an empty Plan tab that shows none of this)

## mp-518 · Should adding a saved meal wait for its ingredient list?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-465
- source: wave ai-cost 2 ticket 14
- svg: docs/ssot/decisions/images/mealplanning/mp-518.svg

**Context.** When Vana adds a saved meal that has no ingredient list yet to a plan, her turn waits while a second model writes that list, because the shopping list she returns is built from it. mp-465 says no helper model is called from inside a Vana turn, and this is the one place that already breaks it. It predates the cost work and was left as it is.

**Question.** Keep waiting for the ingredient list inside the turn, or build it in the background and show the dish as one line until it is ready?

**Why.** Moving it keeps mp-465's rule whole but changes what the athlete sees right after the add.

**What it touches.** Vana's add-meal tool, the saved-meal ingredient job, the shopping list.

> 2026-09-21 opened from wave 2 of ai-cost
> 2026-09-23 clarity pass (question, context, why)

## mp-520 · Should the Entitlement row keep the store product id?
- category: Cutting costs
- kind: question
- status: answered
- linked: mp-519
- source: wave ai-cost 3 ticket 05
- svg: docs/ssot/decisions/images/mealplanning/mp-520.svg

**Context.** mp-519 counts a paid subscriber as annual when their access runs more than 45 days past a call, and monthly otherwise. That is right today, because every annual subscriber is early in their year and a monthly one never runs past about 31 days. From about September 2027, an annual subscriber in the last 45 days of their year will be counted as monthly. Storing the store's product id would make the label exact, but mp-285 cut the Entitlement row to two fields.

**Question.** Keep the 45-day label, or store the product id on the Entitlement row, which reopens mp-285's two-field rule?

**Why.** Left alone, the cost-per-plan figure drifts a little each autumn; fixing it adds a third field to the paywall's table.

**What it touches.** `user_entitlements`, the RevenueCat webhook, `vana_plan_label`.

> 2026-09-22 opened from wave 3 of ai-cost
> 2026-09-23 clarity pass (question, context, why)
> 2026-09-23 answered by mp-609

## mp-522 · Should the budget's price table fill in calls the Gateway never priced?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-521
- source: wave ai-cost 3 ticket 05
- svg: docs/ssot/decisions/images/mealplanning/mp-522.svg

**Context.** mp-521 counts a call's cost as the Gateway's own charge; when the Gateway reports none, the weekly view shows how many calls were priced beside how many there were. mp-436 gives the monthly budget a price table for that same case: it prices the tokens from one table. Ticket 09 builds that table.

**Question.** Price those calls from the budget's price table so the weekly cost is whole, or keep showing priced calls beside all calls?

**Why.** It decides whether Lee reads one cost number or a number with a count beside it, and whether the call log and the wallet can ever disagree.

**What it touches.** log.ts, the weekly view, ticket 09's price table.

> 2026-09-22 opened from wave 3 of ai-cost
> 2026-09-23 clarity pass (question, context, why)

## mp-524 · Amend the playbook, or move the two alerts?
- category: Data, sync and backend
- kind: question
- status: open
- linked: mp-523
- source: wave ai-cost 3 ticket 05
- svg: docs/ssot/decisions/images/mealplanning/mp-524.svg

**Context.** The deploy playbook (docs/deployment/supabase-deploy-playbook.md §5) says no scheduled database job, trigger or stored procedure calls an edge function, because such calls get lost. The raw-retention alert that landed on 2026-09-20 does exactly that: a scheduled database job (pg_cron) posts to a function whose address and token sit in the database's secret store (Vault). mp-523's daily cost alert is built the same way, and the wave's standards review flagged the clash.

**Question.** Does the playbook allow a database job to call an alert function, or do both alerts move to a scheduled function or a Sentry cron monitor?

**Why.** Two live jobs contradict a written rule, so the rule or the jobs must change before production gets either.

**What it touches.** The playbook, the two alert migrations, the two alert functions.

> 2026-09-22 opened from wave 3 of ai-cost
> 2026-09-23 clarity pass (question, context, why)

## mp-526 · Does a photo that is not food draw the athlete's budget?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-525
- source: wave ai-cost 3 ticket 08
- svg: docs/ssot/decisions/images/mealplanning/mp-526.svg

**Context.** When an athlete logs a photo or description that is not food, the app shows one warning line and no macros (mp-525). The model still ran, so we paid for a Sonnet call, and the build kept the call log row and took the cost from the wallet. No card rules on it.

**Question.** Charge a not-food answer to the athlete's monthly budget, or carry its cost ourselves?

**Why.** Charging for a refusal may read badly; not charging invites the loop the budget exists to stop.

**What it touches.** describe-meal, analyze-meal-photo, the wallet debit.

> 2026-09-22 opened from wave 3 of ai-cost
> 2026-09-23 clarity pass (question, context)

## mp-527 · Should the meal-logging instructions grow long enough to be cached?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-525
- source: wave ai-cost 3 ticket 08
- svg: docs/ssot/decisions/images/mealplanning/mp-527.svg

**Context.** mp-525 marks each meal-logging call's fixed instructions to be kept in the prompt cache for an hour. Each set is about 600 tokens, and Anthropic caches nothing shorter than about 1,024, so on dev nothing was ever read from the cache. The marker costs nothing; this ticket's saving came from capping photos at 1,000 px.

**Question.** Pad the instructions past the cache minimum with a fixed rubric or worked examples, or leave them and let the photo cap carry the saving?

**Why.** About 400 tokens of padding cost more on every miss than they save on a hit unless most calls hit, so the hit rate should be measured first.

**What it touches.** `_shared/meal_analysis/prompt.ts`.

> 2026-09-22 opened from wave 3 of ai-cost
> 2026-09-23 clarity pass (question, context, why)

## mp-529 · Should the purchase ask for notification permission?
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-456
- image: none
- caption:
- screen: none (a local notification)
- source: wave paywall 2 ticket 04

**Context.** The day-five reminder is scheduled only when the athlete has allowed notifications, and nothing in the purchase asks. An athlete who never allowed them gets no reminder. mp-429 §10 lists the reminder among the things never cut.

**Question.** Should starting the free week ask for notification permission, or should the reminder rely on whatever was granted before?

**Why.** Without an ask, the reminder only reaches athletes who happened to allow notifications earlier.

**What it touches.** The purchase flow on the paywall, `notification_service.dart`.

> 2026-09-22 opened in wave 2 ticket 04
> 2026-09-22 answered by mp-540

## mp-531 · The exact flip time
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-455
- image: none
- caption:
- screen: none (a script Lee runs on flip day)
- source: wave paywall 2 ticket 06

**Context.** The grace script takes the flip as an exact time with a zone, and ticket 09's claim for old anonymous installs needs the same instant as a fixed value. mp-429 says the paywall goes live 1 October.

**Question.** Is the flip 1 October at 00:00, and in which time zone?

**Why.** Accounts created that day fall on one side or the other, and the script and the claim must agree.

**What it touches.** `scripts/grace-grant.mjs`, ticket 09's claim function.

> 2026-09-22 opened in wave 2 ticket 06
> 2026-09-22 answered by mp-541

## mp-532 · Should the prod grace run leave out test and demo accounts?
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-455
- image: none
- caption:
- screen: none (a script Lee runs on flip day)
- source: wave paywall 2 ticket 06

**Context.** The grace run, the script Lee runs at the flip to give Legacy grace, selects every registered account created before the flip. On production that includes the team's own test and demo accounts.

**Question.** Should the team's own test and demo accounts be left out of the production grace run, and if so, by what rule?

**Why.** They would carry the founding-member mark and a 30-day Grant into the numbers.

**What it touches.** `_shared/grace` selection.

> 2026-09-22 opened in wave 2 ticket 06
> 2026-09-22 answered by mp-542
> 2026-09-23 clarity pass (question, context, why)

## mp-534 · The prod webhook hears only purchases and renewals
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-454
- image: none
- caption:
- screen: none (RevenueCat configuration)
- source: wave paywall 2 ticket 06

**Context.** While changing dev's RevenueCat connection, the wave read both connections to our server. Production's sends three event types: first purchase, renewal and one-off purchase. The webhook's own notes say a copy that hears only purchases and renewals never closes a row. Dev's sends all eleven.

**Question.** When should production's RevenueCat connection start sending every event type: in ticket 05, or before it?

**Why.** Without cancellation and expiration events, production's Entitlement rows stay open after access ends.

**What it touches.** RevenueCat integration `whintgraa6c9e50e5` (prod), ticket 05.

> 2026-09-22 opened in wave 2 ticket 06
> 2026-09-22 answered by mp-543
> 2026-09-23 clarity pass (question, context, why)

## mp-536 · Should a giveaway code leave a mark for reporting?
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-458
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave paywall 2 ticket 07

**Context.** Coach and influencer Codes record themselves on the RevenueCat customer, so RevenueCat and our reports can tell where an athlete came from. A giveaway Code grants 365 days of Pro and records nothing.

**Question.** Should a giveaway Code also be recorded on the account, as coach and influencer Codes are?

**Why.** Without it, a giveaway winner cannot be told apart from any other promotional grant in the reports.

**What it touches.** `redeem-code`.

> 2026-09-22 opened in wave 2 ticket 07
> 2026-09-22 answered by mp-544
> 2026-09-23 clarity pass (question, context)

## mp-539 · Close and ⋯ are placeholders on a paywall that must not close
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-493
- image: none
- caption:
- screen: Paywall
- source: wave paywall 2 ticket 14

**Context.** Ticket 14 shows close and ⋯ with the second page, as mp-493 §1 says. They do nothing yet: their behaviour is tickets 16 and 17. They also show on the onboarding paywall, which mp-493 §5 says has no close button. mp-493 §7 ships the paywall in the 25 September store build.

**Question.** If tickets 16 and 17 are not in the 25 September build, should the placeholders be hidden for it, or should the build wait for them?

**Why.** Apple would review a close button that does nothing on a paywall that cannot be closed.

**What it touches.** `paywall_screen.dart`, tickets 16 and 17, the 25 September store build.

> 2026-09-22 opened in wave 2 ticket 14
> 2026-09-22 answered by mp-545

## mp-546 · Vana says its sentence, then hands off
- category: Vana's voice and openers
- status: proposed
- image: none
- noshot: an empty chat that shows none of this
- svg2: docs/ssot/decisions/images/mealplanning/mp-546-2.svg
- screen: Vana chat
- source: wave ai-cost 4 ticket 06

**Context.** A hand-off used to take two model steps: the tool call, then a second step for the closing sentence. Ticket 06 ends the turn the moment Vana asks a choice, hands off, or saves feedback silently, so nothing runs after the call. The persona and the tool's description now tell Vana to say its one sentence first and call handOff after it. Approving this leaves a gap with mp-015 and mp-016: they drop text written before a tool call from the saved conversation and exempt only a choice question, so the sentence before a hand-off is not exempted and would be gone after a reload.

**Question.** When Vana hands the athlete off to a screen, where does its one sentence go?

**Decision.** Before the hand-off, which here means the button Vana shows that opens one of the app's own screens. Vana writes its one sentence, then calls the hand-off, and the turn ends there; nothing is said after the call. Example: an athlete asks for next week's meals; Vana writes one sentence and shows the button to the meal-planning screen, and the reply takes one model step instead of the two a hand-off used to take.

**Why.** The call ends the turn; a sentence after it would never be written, and a second step to write it is what the ticket removes.

**What else was considered.** Keeping a second step for the sentence after the hand-off; rejected, it is the cost the ticket cuts.

**What it touches.** Vana chat, the persona and the handOff tool description on the server.

**Details.** Precisely:
1. Vana writes its one sentence, then calls the hand-off, and the turn ends there.
2. Nothing is said after the call.

> 2026-09-22 proposed in wave 4 ticket 06
> 2026-09-22 picture captured at 1.27.0+3, b7682f1b
> 2026-09-22 rewritten in plain words (question, decision, details)
> 2026-09-23 clarity pass (context)
> 2026-09-23 screenshot removed: docs/ssot/decisions/images/mealplanning/vana-chat.png (an empty chat that shows none of this)

## mp-547 · A complaint that asks a question still gets an answer
- category: Vana's voice and openers
- status: proposed
- image: none
- noshot: an empty chat that shows none of this
- svg2: docs/ssot/decisions/images/mealplanning/mp-547-2.svg
- screen: Vana chat
- source: wave ai-cost 4 ticket 06

**Context.** Saving feedback ends the turn now, so a complaint costs one model step. The feedback tool already knows whether it should stay silent (a plain complaint) or answer (a complaint with a question in it). Approving this narrows mp-246 (Vana says nothing more after saving feedback): that rule now holds only for a plain complaint with no question in it.

**Question.** When the athlete's message is both a complaint and a question, does Vana answer?

**Decision.** Yes. Saving feedback ends Vana's turn only when the feedback was the silent kind, a plain complaint. A complaint with a question in it keeps the step in which Vana answers. Example: an athlete writes "that curry was too spicy"; Vana saves it and the turn ends. Another writes "that curry was too spicy, is there a milder one?"; Vana saves it and then answers the question.

**Why.** The spec ends the turn when Vana "saves feedback silently"; a question left unanswered would read as Vana ignoring the athlete.

**What else was considered.** Ending every turn on saved feedback; rejected, it would drop the answer.

**What it touches.** Vana chat, the stop rule in the chat module.

**Details.** Precisely:
1. The turn ends on saved feedback only when the feedback was the silent kind.
2. A complaint with a question in it keeps the step that answers it.

> 2026-09-22 proposed in wave 4 ticket 06
> 2026-09-22 picture captured at 1.27.0+3, b7682f1b
> 2026-09-22 rewritten in plain words (question, decision, details)
> 2026-09-23 clarity pass (context)
> 2026-09-23 screenshot removed: docs/ssot/decisions/images/mealplanning/vana-chat.png (an empty chat that shows none of this)

## mp-548 · Which token count shows the picker work is done: per call or per model step?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-471
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-548.svg
- screen: none (algorithm/data)
- source: wave ai-cost 4 ticket 06

**Context.** Ticket 06 expected the fourth planning turn to fall from about 72,000 input tokens to under 35,000. On dev the whole call went from 91,026 to 49,662, and each model step, one call to the model inside the turn, from 45,000 to 16,000; the new turn ran three steps (a setting, the meal picker, the sentence), which the target did not assume. The whole six-call conversation fell from 393,000 to 164,000 tokens, $0.227 to $0.098.

**Question.** Track input tokens per call or per model step? Per call missed the 35,000 target; per step beat it.

**Why.** The number decides whether the picker work is done or whether ticket 07's cache work has to carry the rest.

**What it touches.** The ticket's measurement, the cost log, ticket 07.

> 2026-09-22 opened in wave 4 ticket 06
> 2026-09-23 clarity pass (question, context)

## mp-552 · Should a Sandbox purchase on production add real budget?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-474
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-552.svg
- screen: none (the RevenueCat webhook)
- source: wave ai-cost 4 ticket 09

**Context.** The production webhook accepts events from every environment. Testers get past the Gate on a production build with a free TestFlight subscription, which arrives as a Sandbox event (mp-431). So a pack bought in Sandbox on production would add real budget for nothing, because the webhook grants the same whatever the environment.

**Question.** On production, should a Sandbox event grant a smaller tester budget, the month but no packs, or the same as a real purchase?

**Why.** It decides whether a tester can top up for free on the store build, and whether testers get the same month everyone else gets.

**What it touches.** The RevenueCat webhook, the wallet grants, TestFlight testers.

> 2026-09-22 opened in wave 4 ticket 09
> 2026-09-23 clarity pass (question, context)

## mp-561 · Retry a failed grace claim, or grant it by hand?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-554
- image: none
- caption:
- screen: none (grace-claim)
- source: wave paywall 3 ticket 09

**Context.** An install still anonymous at the flip claims its Legacy grace once, right after sign-up (mp-554). If that claim fails, because the phone is offline or RevenueCat is down, nothing tries again. The athlete then sits on the paywall without the 30 days.

**Question.** When an old install's grace claim fails, should the app retry it at startup for an account created before the flip, or does Lee grant the month by hand with `grace-grant.mjs --user`?

**Why.** An old user who lost the grace month to a network blip would be asked to pay.

**What it touches.** grace-claim, app startup.

> 2026-09-22 opened in wave 3 ticket 09
> 2026-09-23 clarity pass (question, context)

## mp-562 · Which paywall an old install sees when its grace claim fails
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-555
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-562.svg
- screen: Paywall
- source: wave paywall 3 ticket 09

**Context.** After sign-up an old install goes into the app and meets the Gate. If its grace claim failed it holds no Pro, so it gets the same paywall a Lapsed account sees today.

**Question.** When an old install's grace claim fails, should it see the Onboarding paywall, as a new account does, or the paywall a Lapsed account sees?

**Why.** From the athlete's side it has just signed up, and the Onboarding paywall is what a new account meets.

**What it touches.** Account screen, router.

> 2026-09-22 opened in wave 3 ticket 09
> 2026-09-23 clarity pass (question, context, why)
> 2026-09-23 answered by mp-280

## mp-563 · With email confirmation on, which comes first: confirming or claiming the grace?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-555
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-563.svg
- screen: none (auth settings)
- source: wave paywall 3 review

**Context.** An old install with no account is sent to sign-up and, once signed up, claims its Legacy grace (mp-555). Supabase, our sign-in service, treats an email sign-up as still anonymous until the address is confirmed. Dev confirms every email automatically and prod does not ask for confirmation yet, so nothing breaks today.

**Question.** When email confirmation is turned on, should the redirect let an unconfirmed email sign-up into the app (A), or should confirmation be asked for only after the Legacy grace is claimed (B)?

**Why.** With confirmation on, the redirect sends the athlete back to sign-up again and the claim is refused.

**What it touches.** Router, grace-claim, auth settings.

> 2026-09-22 opened in wave 3 review
> 2026-09-23 clarity pass (question, context, why)

## mp-564 · Should the app skip background AI calls for a lapsed account?
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-457
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-564.svg
- screen: Plan tab
- source: wave paywall 3 ticket 11

**Context.** Some AI calls run without a tap: the Food tab calls Vana on its own, and moments open with Vana already talking. For a lapsed account the app does not stop these today; only the server refuses them (mp-457 clause 5). Every AI action the athlete taps opens the paywall in the app first.

**Question.** For a lapsed account, should the app stop the AI calls nobody tapped for (A), or keep making them and let the server refuse them (B)?

**Why.** Each refused call is a wasted round trip and may show an error on a read-only screen.

**What it touches.** Meal planning controllers, Vana moments.

> 2026-09-22 opened in wave 3 ticket 11
> 2026-09-23 clarity pass (question, context)
> 2026-09-23 answered by mp-280

## mp-565 · After buying, should the app go on to the AI screen the athlete tried to open?
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-557
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-565.svg
- screen: Paywall
- source: wave paywall 3 ticket 11

**Context.** A lapsed account that opens an AI screen, such as Vana, meets the paywall instead (mp-557). Once they buy, the Gate opens and the app goes to the home screen.

**Question.** After a lapsed athlete buys, should the app open the AI screen they tried to reach (A), or the home screen as today (B)?

**Why.** They asked for Vana; landing on home makes them find it again.

**What it touches.** Router.

> 2026-09-22 opened in wave 3 ticket 11
> 2026-09-23 clarity pass (question, context)
> 2026-09-23 answered by mp-280

## mp-566 · On a short phone, should the plan cards stay stacked or sit side by side?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-559
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-566.svg
- screen: Paywall
- source: wave paywall 3 ticket 15

**Context.** The paywall pins the two plan cards and the Continue button at the bottom, stacked with annual on top (mp-559). With founding prices shown, that tray takes about 40% of a short phone's height. The features scroll under a hard edge beneath the ⋯ button, with no fade. The paywall's design is Xuan's call.

**Question.** On a short phone, should the plan cards stay stacked (A) or sit side by side (B), and should the features fade out under the ⋯ button?

**Why.** The features are the reason to buy; a tall tray hides them.

**What it touches.** Plan card, paywall screen (Xuan's call).

> 2026-09-22 opened in wave 3 ticket 15
> 2026-09-23 clarity pass (question, context)

## mp-567 · Is the free week set up on the dev and prod store products?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-453
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-567.svg
- screen: Paywall
- source: wave paywall 3 ticket 15

**Context.** The plan cards show a trial note when the store offers the customer a free first week, the Trial. On the dev simulator, a new account's cards showed no trial note. Either the store gave that customer no introductory offer, or the offer is not set up on the dev products.

**Question.** Is the free week set up as an introductory offer on the dev products, and on the prod products Apple reviews on 25 September?

**Why.** Apple reviews the paywall with the trial terms on it.

**What it touches.** App Store Connect, RevenueCat offerings.

> 2026-09-22 opened in wave 3 ticket 15
> 2026-09-23 clarity pass (question, context)

## mp-576 · Should the wallet row stop reaching the phone in dollars?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-571
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-576.svg
- screen: none (the wallet transport)
- source: wave ai-cost 5 ticket 10

**Context.** mp-436 says the app is never sent a dollar figure. Since ticket 10 the screen shows none. But the wallet row still reaches the phone in micro-dollars (millionths of a dollar), by the plain read at app open and by the live connection. Closing that needs a database view or a server call that returns only the three shares, outside ticket 10's files.

**Question.** Is "never sent a dollar figure" about the screen, which is done, or about what reaches the phone, which needs a server change and its own ticket?

**Why.** It decides whether cutting costs has one more ticket or none.

**What it touches.** The wallet read and push, `token_wallets`, ensure-credits.

> 2026-09-22 opened in wave 5 ticket 10
> 2026-09-23 clarity pass (question, context)

## mp-577 · Is 80% read from the cache a floor for every turn, or an average over ten?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-570
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-577.svg
- screen: none (the Vana server)
- source: wave ai-cost 5 ticket 07

**Context.** Ticket 07 asked that 80% or more of a planning turn's input be read from the prompt cache over ten turns, and measured 85%. The turn right after the athlete changes the plan reads less, and one of the ten read 79%. History that grows behind a rebuilt Context block cannot sit under a cache marker.

**Question.** Does the 80% target hold for every turn, or for the conversation as a whole?

**Why.** A per-turn floor would need a third cache marker on the conversation history, more work for less than a cent a conversation.

**What it touches.** The Vana server, the eval seam.

> 2026-09-22 opened in wave 5 ticket 07
> 2026-09-23 clarity pass (question, context)

## mp-578 · What should the $0.99 test pack be called?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-475
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-578.svg
- screen: none (the top-up sheet on dev)
- source: wave ai-cost 5 ticket 10

**Context.** The store has a $0.99 pack that exists to test the purchase pipeline. The two real packs are "a quarter of a month" and "a month and a quarter" (mp-430 clause 7). The test pack adds about half a percent of a month, which rounds to nothing as a percentage. The build named it "A sliver of a month of Vana".

**Question.** Keep "A sliver of a month of Vana", choose another name, or hide the pack from the top-up sheet?

**Why.** It shows in the sheet on dev today with that wording.

**What it touches.** The top-up sheet, `ai_credits.pack_sliver` in the content system.

> 2026-09-22 opened in wave 5 ticket 10
> 2026-09-23 clarity pass (question)

## mp-582 · What should an Admin with no plan see on the Subscription screen?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-495
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-582.svg
- screen: Subscription screen
- source: wave paywall 4 ticket 16

**Context.** An Admin is a team account marked by hand; the Gate lets it into the app with no plan (mp-416). The Subscription screen reads only the store, so an Admin with no plan sees "Your plan has ended", "Your data is read-only until you subscribe" and an Upgrade button. That button leads nowhere useful, because the Gate sends an account it lets in away from the paywall.

**Question.** Should an Admin with no plan see its own status, such as "Admin access" (A), the store's status without the Upgrade button (B), or the store's status as today (C)?

**Why.** The ended line tells an Admin something false about their data.

**What it touches.** Subscription screen, `subscription.*` content keys.

> 2026-09-22 opened in wave 4 ticket 16
> 2026-09-23 clarity pass (question, context, why)

## mp-583 · Should a granted plan say where it came from?
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-495
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-583.svg
- screen: Subscription screen
- source: wave paywall 4 ticket 16

**Context.** A Grant is Pro given without a purchase: the Legacy grace, a coach's Code, or the dev account. The Subscription screen shows it as "Subscribed · Ends on September 15, 2027. It won't renew." with no Manage button, since there is no store subscription to manage.

**Question.** Should a Grant say what it is, such as "Gift from your coach" or "Grace month" (A), or is "Subscribed" with its end date enough (B)?

**Why.** "It won't renew" can read as a problem to an athlete who never paid.

**What it touches.** Subscription screen, `subscription.*` content keys.

> 2026-09-22 opened in wave 4 ticket 16
> 2026-09-23 clarity pass (question, context)
> 2026-09-23 answered by mp-558

## mp-584 · After a refused save, should every edit screen stay open and stay quiet?
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-491
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-584.svg
- screen: none (every edit screen)
- source: wave paywall 4 ticket 12

**Context.** For a lapsed account the save is refused before anything is written, and the paywall opens (ticket 12, mp-491). The screen underneath was left as it was, so some screens still close themselves or show "saved" behind the paywall. The sweat profile was fixed in the wave review; the other screens were not checked on a device.

**Question.** When a lapsed athlete's save is refused, should every edit screen stay open and show nothing, leaving the paywall to speak?

**Why.** A "saved" toast for a save that never happened is wrong, and a screen that closes loses what the athlete typed.

**What it touches.** Every edit screen.

> 2026-09-22 opened in wave 4 ticket 12
> 2026-09-23 clarity pass (question, context)
> 2026-09-23 answered by mp-280

## mp-588 · Should the full-screen lapsed paywall get a close button?
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-585
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-588.svg
- screen: Paywall
- source: wave paywall 5 ticket 17

**Context.** A lapsed account that opens the app from cold, or follows a link from outside the app straight to an AI screen, lands on the full-screen paywall with no close (mp-585). To reach its read-only data it must subscribe, restore, or sign out and back in. That is how it behaved before ticket 17.

**Question.** Should the full-screen paywall a lapsed account lands on get a close button that goes to the Plan tab (A), or stay without one (B)?

**Why.** mp-280 and mp-457 promise a lapsed account can still read its own data; this path hides it until they sign out.

**What it touches.** The paywall route, `pro_gate_redirect.dart`, `paywall_screen.dart`.

> 2026-09-22 opened in wave 5 ticket 17
> 2026-09-23 clarity pass (question, context)
> 2026-09-23 answered by mp-280

## mp-589 · Should the plan-ended bar stay in place while the paywall sheet opens?
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-457
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-589.svg
- screen: Paywall
- source: wave paywall 5 ticket 17

**Context.** A lapsed account sees a plan-ended bar, with a Subscribe button, above every screen (mp-457), and the bar hides while the paywall is up. The paywall is now a sheet, so the screen underneath shows. When the bar hides, that screen jumps up by the bar's height as the sheet slides up.

**Question.** When the paywall sheet opens, should the plan-ended bar hide and let the screen jump up (A, today), or stay in place, dimmed with the rest of the app (B)?

**Why.** It is the first motion a lapsed athlete sees after tapping Subscribe.

**What it touches.** `PlanEndedHost`, the plan-ended bar, the paywall sheet.

> 2026-09-22 opened in wave 5 ticket 17
> 2026-09-23 clarity pass (question, context)
> 2026-09-23 answered by mp-280

## mp-590 · Xuan: grabber, top gap and entrance for the glass sheet?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-493
- image: none
- noshot: a test image: its words render as blocks
- svg2: docs/ssot/decisions/images/mealplanning/mp-590-2.svg
- screen: Paywall
- source: wave paywall 5 ticket 17

**Context.** The paywall sheet is built on a shared glass sheet in the Kyle design system (mp-493 clause 6). Ticket 17 wrote its component spec, `docs/ssot/spec/design/components/glass-sheet.md`, as PROPOSED v1 awaiting Xuan. It had to pick defaults: no grabber, full height up to the status bar, and the platform's standard slide-up timing and curve, since the design system has no motion values yet.

**Question.** Should the glass sheet have a grabber, how big a gap should it leave at the top, and what timing and curve should it slide in with?

**Why.** It is the design library's sheet, so whatever Xuan picks applies to every sheet built on it, not only the paywall.

**What it touches.** `docs/ssot/spec/design/components/glass-sheet.md`, `kyle_design/materials/glass_sheet.dart`.

> 2026-09-22 opened in wave 5 ticket 17
> 2026-09-23 picture reused from test/features/subscription/presentation/goldens/paywall_sheet_dark.png
> 2026-09-23 clarity pass (question, context)
> 2026-09-23 screenshot removed: test/features/subscription/presentation/goldens/paywall_sheet_dark.png (a test image: its words render as blocks)

## mp-594 · After a tapped fork answer or "Use these", what comes next?
- category: Cutting costs
- kind: question
- status: answered
- linked: mp-464
- image: none
- screen: Vana chat
- source: wave ai-cost 6 ticket 11

**Context.** When Vana first leaves dinners she asks two questions, batch cooking and coverage, and then shows the next meal picker. A tapped answer now gets no reply from her (mp-464 clause 3), so nothing new appears: the athlete carries on with the chips already on screen (mp-591), or types. "Use these" on the pantry card used to bring a picker built from what they have on hand; now Vana stays quiet until the athlete's next message.

**Question.** Is it fine that nothing new appears after a tapped fork answer or "Use these", or should the app send Vana a turn after them (which costs one)?

**Why.** It decides whether planning can stall after a tap. The device check could not show it, because the server side of ticket 11 is not on dev yet.

**What it touches.** Vana chat, the planning persona (`persona.ts` rules 4 and 9).

> 2026-09-23 opened in wave 6 ticket 11
> 2026-09-23 answered by mp-608

## mp-595 · Should a fixed chip act at once wherever its label appears?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-464
- image: none
- screen: Vana chat
- source: wave ai-cost 6 ticket 11

**Context.** The app knows a fixed chip only by its words. "Batch cook", "Dinners only" and the other fixed labels act at once wherever they show up. Vana's opening question is her own, and she may offer one of those same words as an answer to it.

**Question.** Should the fixed labels act at once only under the question they belong to, and go to Vana anywhere else?

**Why.** Tapped under her opener, such a chip would quietly save a setting and Vana would not answer.

**What it touches.** Vana chat; `vana_fixed_chip.dart`, `chip-labels.ts`.

> 2026-09-23 opened in wave 6 ticket 11

## mp-596 · "Open shopping list" lands on Plan when the Food tab is already open
- category: Cutting costs
- kind: question
- status: open
- linked: mp-464
- image: none
- screen: Food tab
- source: wave ai-cost 6 ticket 11

**Context.** The "Open shopping list" chip goes to Food, Shopping. On the device check the Food tab opened on Plan instead: once the Food tab has been built, it keeps the segment it first opened on. The plan bar's link to the shopping list has the same fault. The fix sits in the tab bar's screen, outside ticket 11.

**Question.** Fix it in a small ticket now, or with the next piece of Food tab work?

**Why.** Opening the list is the chip's only job, and today it opens the wrong segment.

**What it touches.** Food tab; `food_screen.dart`, `tabs_screen.dart`.

> 2026-09-23 opened in wave 6 ticket 11

## mp-597 · Should the status line say Vana is thinking while a tap runs with no model?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-464
- image: none
- screen: Vana chat
- source: wave ai-cost 6 ticket 11

**Context.** While a chip that acts at once is running, the chat shows a status line. For "Use these", the batch cooking answer and the coverage answer it falls back to "Vana is thinking…", and "Use what I have" shows the fridge photo's line, though no model runs and no photo is read.

**Question.** Should these taps show a neutral line such as "Working on it…" instead?

**Why.** mp-464 says Vana has no voice on these taps; the status line still speaks for her.

**What it touches.** Vana chat; `vana_status_copy.dart`, the content system.

> 2026-09-23 opened in wave 6 ticket 11

## mp-600 · Should a coach who redeems their own Code see coach mode at once?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-458
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-600.svg
- screen: none (data sync)
- source: wave paywall 6 ticket 18

**Context.** mp-458 says a coach entering their own Code is marked as a coach and gets 30 days of Pro. The server marks the account as a coach at once, and ticket 18 refreshes Pro at once, so the paywall drops. The app learns that the account is a coach only on its next data sync, so coach mode may not show until then.

**Question.** When a coach redeems their own Code, should the app fetch their coach status straight away so coach mode shows at once (A), or wait for the next sync (B)?

**Why.** A coach who redeems and lands in the app with no coach tools may think the Code only half worked.

**What it touches.** `code_entry_controller.dart`, `coach_service.dart`, the coach mode switch.

> 2026-09-23 opened in wave 6 ticket 18

## mp-601 · Should an athlete's pairing request show as soon as they enter a coach's Code?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-458
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-601.svg
- screen: none (data sync)
- source: wave paywall 6 ticket 18

**Context.** mp-458 says an athlete entering a coach's Code gets a pending pairing with that coach. The server makes the request at once, and the entry says "Your coach will see your request to pair." The athlete's own list of coaches is not reloaded, so the pending request shows there only after the next sync.

**Question.** After an athlete enters a coach's Code, should the app reload their coaches so the pending request shows at once (A), or leave it to the next sync (B)?

**Why.** An athlete who checks for the request right after and finds nothing may enter the Code again, and gets "You've already used that code."

**What it touches.** `code_entry_controller.dart`, the athlete's coach list.

> 2026-09-23 opened in wave 6 ticket 18

## mp-606 · When does a meal type count as planned?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-602
- image: none
- screen: Vana chat
- source: wave ai-cost 7 ticket 12

**Context.** mp-602 moves "I like these" to the next type once the current type has meals. Today one meal of a type counts as covered. On the device check, a dinners-only athlete who had picked 2 of 5 dinners tapped "I like these"; the app sent it to Vana (nothing else to plan), and she offered more dinners, a paid turn each time. With dinners and lunches, one dinner is enough for "I like these" to jump to lunch, where Vana might have kept offering dinners.

**Question.** Should a type count as planned after one meal, or only once it fills the nights the plan covers?

**Why.** It decides whether "I like these" can move on too early, and how many paid turns a dinners-only week costs.

**What it touches.** Vana chat; `chips.ts` (`pickerNextStep`), the plan's coverage.

> 2026-09-23 opened in wave 7 ticket 12

## mp-607 · Should "I like these" still skip Vana in a race week?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-602
- image: none
- screen: Vana chat
- source: wave ai-cost 7 ticket 12

**Context.** Vana has a rule for the night before a race: she proposes a race-eve meal while planning. When "I like these" brings the next picker with no model turn (mp-602), she does not see that moment and cannot make the suggestion then.

**Question.** When a race is in the plan's week, should "I like these" go to Vana instead of bringing the next picker at once?

**Why.** Skipping her saves a turn but could drop the race-eve suggestion for the athletes it matters to most.

**What it touches.** Vana chat; `chips.ts`, the planning persona (`persona.ts` rule 6).

> 2026-09-23 opened in wave 7 ticket 12

## mp-614 · Opening the paywall from inside the app leaves nothing behind it
- category: Pro and paywall
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/paywall-lapsed.png
- caption: A lapsed account on 23 Sep: the full-screen paywall, no close button, the ⋯ menu top right
- screen: Paywall
- source: wave paywall 7 ticket 19

**Context.** Before ticket 19, an AI tap, the Subscription screen's Upgrade button and the Vana launcher pushed the paywall on top of the screen the athlete was on, so a back swipe returned to it. mp-457 makes closed always the full-screen paywall with no close button. The Gate's redirect already sends a closed account to a paywall with nothing under it.

**Question.** When something inside the app opens the paywall, can the athlete swipe back to where they were?

**Decision.** No. Every way into the paywall replaces the whole screen stack, the same as the Gate's redirect, so there is no back swipe and no back button into the app. The only ways out are subscribing, restoring, redeeming a Code, or the ⋯ menu's Sign out and Delete account. Example: an athlete whose trial ended on 8 October taps the Vana launcher on 9 October; the paywall fills the screen and a swipe from the left edge does nothing.

**Why.** A paywall pushed over the app would be a second, closable shape of the paywall, which mp-457 and mp-493 rule out.

**What else was considered.** Pushing a full-screen page on top of the current screen; it leaves the app underneath, one back swipe away.

**What it touches.** Paywall; `open_paywall.dart`, the AI action guard, the Subscription screen's Upgrade, the Vana launcher.

> 2026-09-23 proposed in wave 7 ticket 19
> 2026-09-23 picture reused from docs/ssot/decisions/images/mealplanning/paywall-lapsed.png

## mp-615 · The Subscription screen tells a Grant's source from its length
- category: Pro and paywall
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/subscription.png
- screen: Subscription screen
- source: wave paywall 7 ticket 21

**Context.** mp-558 says a Grant shows where it came from (Legacy grace, a Code, a coach's gift) and its days left. The app reads the account from RevenueCat, the subscription provider, and every Grant there looks the same: one promotional product, a start and an end. The app cannot read the server's record of which Code was used, and RevenueCat's app library does not hand the app the notes the server attaches to a customer.

**Question.** How does the app decide what a Grant is called?

**Decision.** By its length. A Grant of 30 days, give or take a day and a half, is shown as "Grace month"; any other length is shown as "Pro from a code". Under it goes the days left in calendar days, "1 day left" on the day before the end and "Last day today" on the last. Example: a Legacy grace Grant from 1 to 31 October shows "Grace month, 12 days left" on 19 October; a 365-day giveaway Code redeemed on 11 October shows "Pro from a code, 357 days left" on 23 October.

**Why.** The length is the only thing the app can read that differs between them, and it needs no new server work before 1 October.

**What else was considered.** The server's notes on the RevenueCat customer, the app's own copy of the Code it redeemed, and a new server function that answers the source; each needs server or data work the ticket did not have.

**What it touches.** Subscription screen; `grant.dart`, `subscription_service.dart`, the `subscription.*` content keys.

**Details.** A coach's own Code also gives 30 days, so it reads as "Grace month" (mp-617 asks whether to fix that). Days left are counted from today's local date to the end's local date and never go below 0.

> 2026-09-23 proposed in wave 7 ticket 21
> 2026-09-23 picture captured at 1.27.0+3, 36bea725

## mp-616 · An ended plan says the athlete's data is kept, not read-only
- category: Pro and paywall
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/subscription.png
- screen: Subscription screen
- source: wave paywall 7 review

**Context.** The Subscription screen's ended lines said "It ended on {date}. Your data is read-only until you subscribe." mp-280 took read-only mode out: a Lapsed account meets the full-screen paywall and its data is kept as it was.

**Question.** What does the Subscription screen say about the athlete's data once the plan has ended?

**Decision.** "It ended on {date}. Everything you saved is kept for when you subscribe again." With no end date it says only the second sentence. Example: a plan that ended on 8 October reads "It ended on 8 October. Everything you saved is kept for when you subscribe again."

**Why.** "Read-only" describes a mode that no longer exists.

**What else was considered.** Dropping the second sentence; the review kept it because mp-280 promises the data comes back.

**What it touches.** Subscription screen; `subscription.ended_on` and `subscription.ended_no_date` content keys.

> 2026-09-23 proposed in wave 7 review
> 2026-09-23 picture captured at 1.27.0+3, 36bea725

## mp-617 · Should a coach's own Code stop showing as "Grace month"?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-615
- image: none
- screen: Subscription screen
- source: wave paywall 7 ticket 21

**Context.** mp-615 names a Grant by its length, and 30 days reads as "Grace month". A coach entering their own Code also gets 30 days of Pro (mp-458), so their Subscription screen says "Grace month" although they never had the Legacy grace.

**Question.** Should the server mark each Grant's source so the app names it exactly (A), give the Legacy grace a length no Code uses, such as 31 days (B), or leave it (C)?

**Why.** A coach who reads "Grace month" may think their Code did not work. A and B need server work before the 1 October cutover; C needs none.

**What it touches.** Subscription screen; the grace claim and `redeem-code` functions, `grant.dart`.

> 2026-09-23 opened in wave 7 ticket 21

## mp-618 · What is "a coach's gift" on the Subscription screen?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-558
- image: none
- screen: Subscription screen
- source: wave paywall 7 ticket 21

**Context.** mp-558 lists three Grant sources: Legacy grace, a Code and a coach's gift. The glossary counts coach comps as Grants. Nothing in the app or its server gives an athlete Pro on a coach's behalf today, so ticket 21 added no label for it and such a Grant would read as "Pro from a code" or "Grace month".

**Question.** Is a coach's gift the Pro a coach gets from their own Code (A), a Grant we make by hand in RevenueCat for a coach (B), or a feature still to build where a coach gives an athlete Pro (C)?

**Why.** It decides whether the screen needs a third label now, and whether a later ticket is owed.

**What it touches.** Subscription screen, the `subscription.*` content keys.

> 2026-09-23 opened in wave 7 ticket 21

## mp-619 · Should Manage subscription show when a Grant outlasts a store subscription?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-558
- image: none
- screen: Subscription screen
- source: wave paywall 7 review

**Context.** mp-558 says Manage subscription shows whenever Pro came from a real store, running or ended. The app looks at one record, the `pro` entitlement, and RevenueCat fills it from whichever source ends last. So an athlete with a monthly subscription who also redeems a 365-day Code sees the Code and no Manage, and cannot reach the store to cancel the monthly from the app.

**Question.** Should the app look through every purchase the account has made and show Manage whenever any came from a store (A), or keep following the one `pro` record (B)?

**Why.** An athlete paying for a subscription they can't find in the app may ask the store for a refund.

**What it touches.** Subscription screen, the paywall's ⋯ menu; `subscription_service.dart`.

> 2026-09-23 opened in wave 7 review

## mp-653 · When does an idea Finding stop holding the testing loop open?
- category: Process and scope
- kind: question
- status: open
- linked: mp-621
- image: none
- svg: docs/ssot/decisions/images/mealplanning/mp-653.svg
- screen: none (testing-wave process)
- source: wave testing-wave 1 ticket 01

**Context.** A testing-wave agent writes an idea Finding when it sees something that could be better but isn't broken. The loop ends when every Finding is closed or won't-fix, and the spec only closes a Finding when a retest passes. An idea has no retest, so as the harness stands, an idea still waiting at triage keeps the loop running for good.

**Question.** At triage, does an idea become a proposal card on the page and close (A), close as won't-fix unless Lee picks it up (B), or stop counting toward the end of the loop, whatever its status (C)?

**Why.** Without a rule for ideas, the loop can never be declared finished, even with every bug fixed.

**What it touches.** `scripts/testing-wave/findings.mjs` (what counts as finished), the spec's Triage section.

> 2026-09-23 opened in wave 1 ticket 01

## mp-654 · Should the app still stop an unpaid AI tap itself, or leave it to the server?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-457
- image: none
- screen: Log meal
- source: wave paywall 8 ticket 20

**Context.** Ticket 20 took every write check out of the app (mp-457). Two AI checks are left in the app: Analyze on the log-meal and edit-meal screens, and the Vana launcher. When an account without Pro taps one, the app opens the paywall without calling the server. These screens are pushed without the router seeing them, so the Gate cannot redirect them. The server already refuses the same calls for an unpaid account (mp-505).

**Question.** Do the log-meal Analyze button and the Vana launcher keep their own check that opens the paywall, or do they call the server and let its refusal speak?

**Why.** mp-457 says the app has no write check. These two are AI checks, not write checks. Keeping them means an unpaid tap lands on the paywall instead of an error, but it is a second check the ruling did not ask for.

**What it touches.** Log meal, Edit meal, the Vana launcher; `ai_action_guard.dart`, `vana_companion.dart`, `writeAccessProvider` in `pro_gate.dart` (the name would become an AI-access name if it stays).

> 2026-09-23 opened in wave 8 ticket 20

## mp-655 · Outside the US, prices follow each store's own conversion
- category: Pro and paywall
- status: proposed
- image: none
- svg: docs/ssot/decisions/images/mealplanning/mp-655.svg
- screen: none (store setup)
- source: wave paywall 9 ticket 05

**Context.** mp-452 sets the four Pro prices in US dollars: $24.99 and $199.99, and founding $12.49 and $99.99. Both stores sell in about 175 countries. Someone has to decide the price in each of the others. Ticket 05 created the production products on 23 September.

**Question.** What does Pro cost outside the United States?

**Decision.** Whatever each store converts the US price to. On the App Store every other country gets Apple's matched price for the US price. On Google Play every other country is priced from the dollar and euro amounts Play converted, the same way the dev products were set up. Example: the monthly plan is $24.99 in the US and €21.91 wherever Play charges euros; the founding annual is $99.99 and €87.66.

**Why.** It is how the dev products were set up, it needs no price list per country before 1 October, and Apple and Google keep their matched prices current as exchange rates move.

**What else was considered.** Setting a hand-picked price for each country or region. That means a price list someone would have to write and keep up to date.

**What it touches.** The four `_prod` products on the App Store and Google Play; `scripts/store/asc.mjs`, `scripts/store/play.mjs`, `docs/implement_mealplanning/04-entitlement.md`.

**Details.** Play also added its own price for Mongolia, as it did on dev. App Store: the US price point plus Apple's matched prices, 175 territories. Play: a US regional price plus `otherRegionsConfig` in USD and EUR.

> 2026-09-23 proposed in wave 9 ticket 05

## mp-656 · Do the old products leave RevenueCat's Test Store offering too?
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-452
- image: none
- screen: none (store setup)
- source: wave paywall 9 ticket 05

**Context.** mp-452 says the old monthly and annual products leave every offering. Ticket 05 took them out of the production and dev apps' offerings. RevenueCat's Test Store, which debug builds with a `test_` key buy from, still sells the old `mealvana_pro_monthly` and `mealvana_pro_annual` in the `default` offering, and it has no `me_pro_*` products to put in their place.

**Question.** Should the Test Store get the four `me_pro_*` products and drop the old two, or stay as it is?

**Why.** A debug build on the Test Store still shows $9.99 and $69.99 and the old ids, so a test there does not match what the stores sell.

**What it touches.** RevenueCat Test Store app `appa283bb35a2`, the `default` offering.

> 2026-09-23 opened in wave 9 ticket 05

## mp-668 · Does New meal plan archive this week's plan at the tap, or only when the new plan is confirmed?
- category: Plan tab
- kind: question
- status: open
- linked: mp-241
- image: none
- svg: docs/ssot/decisions/images/mealplanning/mp-668.svg
- screen: none (the Plan tab and the new-plan chat both follow from the answer)
- source: wave testing-wave 8 ticket 14

**Context.** mp-241 says two things that pull apart: "the Plan tab keeps the confirmed plan until a new one is confirmed" and "\"New meal plan\" archives the plan it is on and starts a fresh, empty draft." mp-234's example sides with keeping it: an athlete with a confirmed plan starts a new one and "removing a meal from it leaves this week's plan as it was." In wave 8 the dev test account tapped New meal plan at 14:22 UTC on 24 September. The app opened a new conversation and nothing else; the draft appeared only when the first meal was picked, and this week's confirmed plan stayed confirmed and on the Plan tab (Findings 14-001, 14-002). Nothing in the app calls the archive-and-start-a-draft action that exists in code.

**Question.** When an athlete taps New meal plan while this week has a confirmed plan, is that plan archived at the tap with a fresh empty draft made at once (A), or does it stay confirmed and on the Plan tab until the new draft is confirmed, with the draft made at the first pick (B, what the app does today)? And under B, should the empty draft exist from the tap so the plan bar can show "Your plan · 0 meals" as mp-234 says?

**Why.** A matches the New meal plan sentence and gives a clean slate. B means an athlete who backs out of the new chat still has this week's plan and never lands on an empty Plan tab.

**What it touches.** The New meal plan button, `MealPlanController.newPlan()`, the Plan tab, the plan bar in the new chat, and which rows ticket 14's retest expects.

> 2026-09-24 opened in wave 8 ticket 14

## mp-669 · Can the athlete delete the shopping list of this week's confirmed plan?
- category: Shopping list
- kind: question
- status: open
- linked: mp-244
- image: none
- svg: docs/ssot/decisions/images/mealplanning/mp-669.svg
- screen: none (the Shopping tab's Delete list dialog and what the tab shows next both follow from the answer)
- source: wave testing-wave 11 ticket 19

**Context.** mp-244 says the server builds the list when the athlete confirms and rebuilds it after every plan edit, but no decision says whether the athlete may delete it. In wave 11 the dev test account deleted its confirmed plan's list from Food > Shopping > ⋯ > Delete list at 16:53 UTC on 24 September. The dialog was the same one a hand-made list gets ("Delete this list? Everything on it goes with it."). The list and its 15 rows were removed, the plan stayed confirmed with no list, and the Shopping tab then opened an archived draft's 6-item list as if it were current (Findings 19-001, 19-002).

**Question.** Is the confirmed plan's own list deletable? (A) No: it can only be cleared or its items marked as had. (B) Yes, and the dialog says it is the plan's list and that it comes back on the next plan edit. (C) Yes, and a fresh copy is built at once. And after a delete, what should the tab show: nothing, or the most recent other list?

**Why.** A keeps the list mp-244 calls the moment of value, and Kroger and the offline copy never lose it. B and C let an athlete who shops elsewhere clear the tab.

**What it touches.** The Delete list item in the Shopping tab's ⋯ menu and its dialog, `delete_shopping_list` in vana-action, which list the tab opens when the plan has none, and the retest of Finding 19-001.

> 2026-09-24 opened in wave 11 ticket 19

## mp-670 · What does a conversation show once another confirm has archived its Draft?
- category: Plan tab
- kind: question
- status: open
- linked: mp-241
- image: none
- svg: docs/ssot/decisions/images/mealplanning/mp-670.svg
- screen: none (the chat's plan bar and Review sheet both follow from the answer)
- source: wave testing-wave 12 ticket 15

**Context.** mp-241 says confirming a draft archives every other plan for that week, drafts from other conversations included. It does not say what those conversations show afterwards. In wave 12 the dev test account opened its 22 September conversation, whose Draft had been archived when another conversation's plan was confirmed. The plan bar still read "Your plan · 4 meals" with Review plan, each meal could be removed or have its servings changed, and the Review sheet offered a working Confirm plan button. Nothing on screen said the Draft was archived. A conversation whose plan is confirmed does say "Plan confirmed" (Finding 15-001; Finding 16-001 is why tapping that Confirm would not confirm this Draft).

**Question.** When a conversation's Draft has been archived by another confirm, what does the conversation show? (A) The Draft, marked archived and view only, with a line naming the week's confirmed plan. (B) The week's confirmed plan in place of the Draft. (C) Nothing until the athlete picks a meal, which starts a fresh Draft in that conversation. And may the athlete bring the archived Draft back?

**Why.** A keeps the conversation's history true to what happened. B keeps one live plan in view everywhere. C follows "every conversation builds its own Draft" most literally.

**What it touches.** The Vana chat's plan bar and Review plan sheet for a conversation whose plan is archived, `get_plan` and `confirm_plan` in vana-action, and the retests of Findings 15-001 and 16-001.

> 2026-09-24 opened in wave 12 ticket 15

## mp-671 · Does a past week's leftover Draft belong in Previous plans?
- category: Plan tab
- kind: question
- status: open
- linked: mp-241
- image: none
- svg: docs/ssot/decisions/images/mealplanning/mp-671.svg
- screen: none (the Previous plans sheet and the earlier plan view both follow from the answer)
- source: wave testing-wave 12 ticket 17

**Context.** mp-241 archives every other plan for a week when a draft is confirmed, but only the plans that exist at that moment. A Draft started after the confirm, or in a week nobody confirmed again, stays a Draft for good. In wave 12 the dev test account's Previous plans sheet listed such a Draft (week of 13 September, one meal, made after that week's plan was confirmed) as "An earlier plan. View only.", the same as the archived and confirmed plans around it, with nothing marking it as a Draft (Finding 17-002).

**Question.** Should the Previous plans sheet list a past week's leftover Draft? (A) No: it lists only confirmed and archived plans, and a Draft stays reachable from its conversation. (B) Yes, labelled Draft, with a way back to its conversation. (C) Drafts are archived when their week ends, so the sheet only ever sees archived and confirmed plans.

**Why.** A keeps the sheet a history of plans that happened. B lets an athlete finish a Draft they forgot. C removes stray Drafts from every list at once, at the cost of a job that runs at week end.

**What it touches.** `list_plans` in vana-action, the Previous plans sheet's rows and their labels, and the retest of Finding 17-002.

> 2026-09-24 opened in wave 12 ticket 17

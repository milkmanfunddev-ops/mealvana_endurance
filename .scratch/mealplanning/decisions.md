# Proposed decisions: Meal planning and Vana

Feature: mealplanning
Feature name: Meal planning and Vana
Last extracted: 1dedc493

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

## mp-315 · Which writes outside Vana's tools should clear the block
- category: Vana's memory
- kind: question
- status: answered
- linked: mp-311
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 13

**Context.** mp-311 clears the stored block on a tool write. Some writes the block reads from do not go through a Vana tool: the home location saved from the app's own screen (ticket 02), a thumbs vote on a meal (the LIKES line), and edits to the users row. After any of them the block stays as it was until the next tool write or the next day.

**Question.** Does a home location, a thumbs vote or a profile edit made outside Vana need to reach the block at once, or is "next tool write or next day" enough?

**Why.** Each path added to the invalidation set is a query on a write path that today knows nothing about Vana.

**What it touches.** The home-location write in the app, meal feedback, the users row, mp-311.

> 2026-09-15 opened in wave 1 ticket 13
> 2026-09-20 answered by mp-419

## mp-316 · Whether the tools and persona are cached across conversations
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-311
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 13

**Context.** In automatic mode the cache breakpoint sits at the end of the prompt, so a brand-new conversation's first turn reads zero: its prefix ends in a message no earlier call has seen. The tools and persona, identical for every athlete, could be reused across conversations with an explicit breakpoint on the system prompt in addition to automatic mode.

**Question.** Should the first turn of a new conversation read the tools and persona from the cache, at the cost of one explicit breakpoint?

**Why.** The first turn is the biggest call of a conversation (dev: 10886 input tokens on turn one against about 6000 after).

**What it touches.** vana-chat prompt assembly, the call log.

> 2026-09-15 opened in wave 1 ticket 13
> 2026-09-20 answered by mp-420

## mp-431 · How testers get in on a production release build
- category: Pro and paywall
- kind: question
- status: open
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

## mp-320 · Which debiting calls the gate covers
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-296
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** Ticket 18 says every Vana or debiting call is gated on the two fields. The gate has four callers, all Vana functions. The functions that debit AI credits (describe, photo, the coach chat) check the wallet and not the entitlement.

**Question.** Does a credit-debiting call need the entitlement too, or is a paid credit its own permission?

**Why.** A lapsed subscriber with credits left can still spend them today. Whether that is a feature or a hole decides whether ticket 20 adds the check.

**What it touches.** The credit-debiting functions, the server gate, ticket 20.

> 2026-09-15 opened in wave 1 ticket 18
> 2026-09-20 answered by mp-430

## mp-321 · When production gets the two-field table, the wider webhook and the offers
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-319
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 18

**Context.** Ticket 18 changed dev only: the migration, the webhook deploy, the RevenueCat integration's event list and the store offers. Production still has the old table, the old webhook, an integration that delivers three event types and no introductory offers. The webhook is env-unfiltered, so a production event reaching the new handler after the migration would be handled correctly; before it, the old handler keeps writing the old columns.

**Question.** Which release carries the production migration, the webhook deploy, the integration change and the store offers, and in what order?

**Why.** The playbook orders schema before functions; the offers can go first since nothing reads them until a purchase.

**What it touches.** The cutover runbook, production RevenueCat, the production store listings.

> 2026-09-15 opened in wave 1 ticket 18

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

**Question.** Does a criterion only a person on a device can verify count as done when its tests pass, or does it stay open until Lee runs it, and where is that recorded?

**Why.** The wave rule says an unfinished criterion fails the ticket. Applied literally, ticket 18 and 25 could never pass, and tickets 19, 20, 21, 28 and 32 wait on them.

**What it touches.** The wave rule in the implement skill, tickets 18 and 25.

> 2026-09-15 opened in wave 1
> 2026-09-20 answered by mp-428

## mp-324 · Whether plan rows should ever show photos
- category: Plan tab
- kind: question
- status: answered
- linked: mp-323
- image: none
- caption:
- screen: Plan tab
- source: wave mealplanning 1 ticket 22

**Context.** The plan tile, the plan bar and the review sheet carry no image data: a plan meal stores its name, slot and icon key, no picture. With the icons gone, every meal on those surfaces shows the placeholder, not only meals without a photo. The Meals tab, which has the library's picture data, shows mosaics where they exist.

**Question.** Should plan rows carry the meal's picture, or is the plain box the intended look for the plan?

**Why.** Carrying the picture means the plan meal row grows picture fields and the add and swap paths copy them, the same shape as the icon key today.

**What it touches.** Plan tab tiles, the plan bar, the review sheet, the plan meal row.

> 2026-09-15 opened in wave 1 ticket 22
> 2026-09-17 answered by mp-418

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

**Question.** Who amends MIM-9 and the launcher section in the QA repo, and should the placeholder get a design spec of its own?

**Why.** The next design sync would report the widgets as drifting from their specs.

**What it touches.** docs/ssot/spec/design/components/meal-image-mosaic.md, the Vana sheet spec, the QA repo.

> 2026-09-15 opened in wave 1
> 2026-09-20 answered by mp-428

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

## mp-330 · How the team reads reviews, and when production gets the table
- category: Meals tab and library
- kind: question
- status: answered
- linked: mp-329
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 25

**Context.** Reviews land in a table only admins can read, through the database. Nothing in the app or elsewhere lists them. The app version column is empty. Production has neither the flag nor the table, and someone must hand-set the flag for the team's production accounts.

**Question.** Does the team need a read surface for reviews (a screen, an export), should the app version be stamped on each row, and which release carries the migration and the hand-set flags?

**Why.** A table nobody reads collects nothing useful.

**What it touches.** meal_reviews, the cutover runbook, the team's production accounts.

> 2026-09-15 opened in wave 1 ticket 25
> 2026-09-20 answered by mp-427

## mp-332 · Whether the implementation import stands, and how the inbox tells typed feedback apart
- category: Feedback loop
- kind: question
- status: answered
- linked: mp-331
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 26

**Context.** The filer reaches into the Wiredash package's internals and pins its version, so every upgrade needs the filer re-checked. Typed entries carry custom metadata but no console label, and they follow the build's environment (a debug build files as dev) like shaken reports do.

**Question.** Is an internal import with a version pin acceptable here, or should Wiredash be asked for a public headless API? Should typed feedback carry a console label so the inbox can filter it, and which one?

**Why.** A silent break on upgrade would drop typed feedback without anyone noticing.

**What it touches.** The feedback filer, the Wiredash console, the pubspec.

> 2026-09-15 opened in wave 1 ticket 26
> 2026-09-20 answered by mp-427

## mp-334 · What the conversation list shows now the episode does not write the summary
- category: Vana's memory
- kind: question
- status: answered
- linked: mp-333
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 14

**Context.** The conversation list reads `vana_conversations.summary` as each row's preview. Under mp-333 that column is the compaction's, holding "Through message 20: …" text for long conversations and nothing for a conversation under thirty messages, since the episode writer no longer fills it.

**Question.** Should the list preview read the episode sentence instead, and may the "Through message N" form ever show on screen?

**Why.** Today a short conversation's preview goes blank and a long one shows the lead-in string.

**What it touches.** The conversation list screen and its repository read.

> 2026-09-15 opened in wave 2 ticket 14
> 2026-09-20 answered by mp-419

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

## mp-338 · How test accounts hold an entitlement
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-335
- image: none
- caption:
- screen: Paywall
- source: wave mealplanning 2 ticket 19

**Context.** With the tester grant gone, a debug build opens on the paywall for any account without a RevenueCat entitlement. The dev account had none, so the wave granted it the `pro` entitlement in RevenueCat (promotional, until 2027-09-15, revocable) so the dev simulator can reach the screens behind the gate. The server's dev entitlement table also had no rows until the wave's agents inserted two by hand for the eval user and the dev account.

**Question.** Is a RevenueCat promotional grant the standing way every test account gets in, and who holds the list of grants?

**Why.** Every dev account and every tester on TestFlight is locked out until someone grants or buys.

**What it touches.** RevenueCat customers, the dev entitlement table, the dev simulator login script.

> 2026-09-15 opened in wave 2 ticket 19
> 2026-09-20 answered by mp-428

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

**Question.** Does Mixpanel exclusion need another writer for `is_internal`, or does the column retire?

**Why.** Without a writer, new internal devices count as athletes in analytics.

**What it touches.** The users row, the analytics edge module, Settings' internal-device flag.

> 2026-09-15 opened in wave 2 ticket 19
> 2026-09-20 answered by mp-428

## mp-343 · Whether the free monthly grant retires
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-341
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 20

**Context.** Every wallet still receives 20 free credits a month (50 on dev) from the old free tier, non-expiring, subscriber or not. Under mp-266 there is no free tier; the allowance is the subscriber's grant.

**Question.** Does the free monthly grant retire now, and what happens to the free credits already in wallets?

**Why.** Two grants a month blur what the allowance is, and the free one never expires.

**What it touches.** `ensure-credits`, the client's monthly stamp, the wallet SQL.

> 2026-09-15 opened in wave 2 ticket 20
> 2026-09-20 answered by mp-430

## mp-344 · What a transfer or a plan change does to the allowance
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-341
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 2 ticket 20

**Context.** A RevenueCat TRANSFER moves the entitlement row to another user; the wallet's allowance and packs stay with the old one, as packs did before. A PRODUCT_CHANGE between monthly and annual grants nothing itself; the next window comes from the roll.

**Question.** Should the allowance follow a transfer, and should a plan change open a new window at once?

**Why.** Both are rare, and both leave a subscriber with a wallet that does not match their entitlement for up to a month.

**What it touches.** The webhook, the wallet roll.

> 2026-09-15 opened in wave 2 ticket 20
> 2026-09-20 answered by mp-430

## mp-346 · The origin copy, the doubled link and the narrow-width overflow
- category: Recipes and cooking
- kind: question
- status: answered
- linked: mp-345
- image: none
- caption:
- screen: Meal detail
- source: wave mealplanning 2 ticket 32

**Context.** The wave wrote the alternate-source and assembly wording itself. A verbatim row now links the original twice: from the new label and from the existing "See the original recipe" row. That row overflows by 47 px at 320 and 7 px at 360 on the base commit, outside the ticket.

**Question.** Is "Steps from X" the wording for an alternate source and a sentence right for an assembly, does the verbatim row keep both links, and is the overflow fixed now?

**Why.** Copy is Xuan's to rule; two links to one page and an overflow on small phones are visible to athletes.

**What it touches.** The meal detail screen, the content defaults.

> 2026-09-15 opened in wave 2 ticket 32
> 2026-09-20 answered by mp-427

## mp-349 · Does a day's conversation get one episode, or one per close?
- category: Vana's memory
- kind: question
- status: answered
- linked: mp-288
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 3 ticket 15

**Context.** The sheet keeps one conversation for the whole day. The first close writes its episode and stamps the claim, and mp-288 clause 3 says a second signal writes nothing. So an athlete who talks in the morning, closes, and talks again at night gets an episode of the morning only; the client signals again after the sheet reopens, and the server discards it. The code follows the record; the wave's spec review flagged it against the ticket's story (the opener knows what last night established).

**Question.** Should a later close re-extract a conversation that has gained turns since its episode (for example, keyed by message count), or does one episode per day's conversation stand and the client stop re-signalling?

**Why.** Evening planning is the ticket's own example, and today it would not reach the next morning's opener.

**What it touches.** extract.ts claim, the ambient conversation controller, mp-288 clause 3.

> 2026-09-15 opened in wave 3 ticket 15
> 2026-09-20 answered by mp-419

## mp-350 · Should leaving the full-screen chat signal idle?
- category: The sheet and launcher
- kind: question
- status: answered
- linked: mp-288
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 3 ticket 15

**Context.** Idle is sent from the sheet and on app background. The full-screen chat's New conversation button and leaving the chat route send nothing, so those conversations get their episode only when the app goes to the background.

**Question.** Should the full-screen chat's New conversation and leaving the chat screen also signal idle?

**Why.** A conversation left in the chat screen while the app stays open has no episode for the next opener.

**What it touches.** vana_chat_screen.dart, the chat controller.

> 2026-09-15 opened in wave 3 ticket 15
> 2026-09-20 answered by mp-423

## mp-351 · Is the "Remembered" card right now that Vana saves more on her own?
- category: Vana's memory
- kind: question
- status: answered
- linked: mp-277
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 3 ticket 15

**Context.** When the model saves a note it shows a "Remembered: …" card in the sheet. The sharpened remember rule (mp-277 clause 2) makes self-initiated saves more frequent, so the card appears more often.

**Question.** Is the card acceptable for every save, or should saves Vana makes on her own stay silent?

**Why.** It is the athlete-visible cost of saving things as they are said.

**What it touches.** Vana sheet, persona remember rule.

> 2026-09-15 opened in wave 3 ticket 15
> 2026-09-20 answered by mp-419

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

**Context.** The eval fails the opener at 3500 ms to headers. It started in 2863 ms, almost all of it building the context block, so a cold start could trip it; it proves the old wait is gone rather than that the opener starts at once.

**Question.** Should the limit be looser, or should the context build get faster so the limit can be tighter?

**Why.** A flaky eval gets ignored.

**What it touches.** scripts/vana-eval/personalization.ts, context build.

> 2026-09-15 opened in wave 3 ticket 15
> 2026-09-20 answered by mp-420

## mp-354 · How Restore is tested when a store won't resubscribe outside the app
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-289
- image: none
- caption:
- screen: Paywall
- source: wave mealplanning 3 ticket 21

**Context.** The sandbox wizard (ticket 21, not merged this wave) tests Restore by resubscribing in the store's own settings after the trial ends, then tapping Restore purchases. Some sandbox stores may offer no resubscribe outside the app.

**Question.** If a store has no way to resubscribe outside the app, how is Restore proven: a second Mealvana account on the same device (which also exercises the transfer path), or something else?

**Why.** Without it the last step of mp-289 cannot go green on that store.

**What it touches.** scripts/sandbox-trial-wizard.sh step 8, the release gate.

> 2026-09-15 opened in wave 3 ticket 21
> 2026-09-20 answered by mp-428

## mp-355 · How fresh a green sandbox run must be for a release
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-270
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 3 ticket 21

**Context.** The wizard's README proposes that a green log counts when its commit is in the release candidate's history and nothing since touched the paywall, the gate, the webhook or the Allowance.

**Question.** Is that the rule, or must the run be on the release candidate itself?

**Why.** The gate in the deploy playbook is only as strong as its freshness rule.

**What it touches.** docs/release/sandbox-trial-runs/README.md, playbook §8 P3c.

> 2026-09-15 opened in wave 3 ticket 21
> 2026-09-20 answered by mp-428

## mp-356 · The release doc still plans a dark launch
- category: Process and scope
- kind: question
- status: answered
- linked: mp-270
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 3 ticket 21

**Context.** docs/implement_mealplanning/07-verification-release.md step 3 still ships the feature dark behind PRO_GATE_ENABLED. mp-270 says no dark launch and no gate flag as the release plan.

**Question.** Should step 3 be rewritten to the trial-and-purchase release, and who owns that doc now?

**Why.** Someone following the doc would release against the record.

**What it touches.** docs/implement_mealplanning/07-verification-release.md.

> 2026-09-15 opened in wave 3 ticket 21
> 2026-09-20 answered by mp-428

## mp-357 · Something other than the webhook wrote an entitlement row on DEV
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-296
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 3 ticket 21

**Context.** DEV user_entitlements has a row with period_type 'eval' (user 37129f7e…, written 2026-09-15 19:05Z). The RevenueCat webhook never writes that value, and the table is meant to have the webhook as its only writer.

**Question.** What wrote it (an eval script, a test fixture, a hand edit), and should the table refuse writers other than the webhook?

**Why.** The server gates on this cache; a stray writer can grant or deny access.

**What it touches.** user_entitlements on DEV, whatever wrote the row.

> 2026-09-15 opened in wave 3 ticket 21
> 2026-09-20 answered by mp-428

## mp-367 · Should the Plan tab open on the plan rather than the personal opener?
- category: Vana's voice and openers
- kind: question
- status: answered
- linked: mp-268
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 28

**Context.** The screens that open on what is in view are event, meal and session screens. The Plan tab with a plan in view ("the week of the 7th is draft") falls back to the personal opener.

**Question.** Should the Plan tab with a plan in view open on that plan?

**Why.** It is the screen an athlete is most often on when they open the sheet.

**What it touches.** The general opener, the Plan tab.

> 2026-09-15 opened in wave 4 ticket 28
> 2026-09-20 answered by mp-421

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

## mp-370 · Should the persona name the in-view section?
- category: Situation awareness
- kind: question
- status: answered
- linked: mp-273
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 16

**Context.** The persona tells Vana what the Situation note is, but nothing tells her what an EVENTS AHEAD or DAY PLAN line under it is. She reads it as context either way.

**Question.** Should the persona name the section the way it names the Situation?

**Why.** What the prompt does not name, the model interprets.

**What it touches.** The persona, the in-view section.

> 2026-09-15 opened in wave 4 ticket 16
> 2026-09-20 answered by mp-422

## mp-371 · Should the Plan tab's section speak for the day or the week?
- category: Situation awareness
- kind: question
- status: answered
- linked: mp-273
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 16

**Context.** The Plan tab's section carries the day's note and slots and also the week's meals with servings left, because the tab itself shows the week. mp-273 says a section is a few lines, never a dump of the record.

**Question.** Should the section be narrowed to the day on screen, or does the week belong there?

**Why.** It is the longest section, and the cap is the only thing holding it down.

**What it touches.** The in-view section, the Plan tab.

> 2026-09-15 opened in wave 4 ticket 16
> 2026-09-20 answered by mp-422

## mp-372 · Two new conversations in a row share one screen
- category: The sheet and launcher
- kind: question
- status: answered
- linked: mp-275
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 4 ticket 16

**Context.** Every conversation started new shares one controller key, which is what keeps the launcher's pointer still. Pressing the plus button from inside a new conversation therefore pushes a second screen showing the first one's transcript. It was true before this ticket as well.

**Question.** Should a second new conversation get its own key, and is that reachable in practice?

**Why.** mp-275 clause 2 says the plus button starts a new conversation, and here the second press does not.

**What it touches.** The full-screen chat's key, the ambient conversation controller.

> 2026-09-15 opened in wave 4 ticket 16
> 2026-09-20 answered by mp-423

## mp-373 · Carb loading lands on the event screen, not on the picks
- category: The sheet and launcher
- kind: question
- status: answered
- linked: mp-265
- image: none
- caption:
- screen: Vana chat
- source: wave mealplanning 4 ticket 27

**Context.** mp-265 clause 4 sends carb loading to the carb-loading picks. The picks screen takes a loaded event, has no route of its own, and hands a protocol back to whoever opened it, so the hand-off lands on the event screen where the carb-loading action lives.

**Question.** Should the picks become a route that takes an event id, so the hand-off can open them directly?

**Why.** As built, the carb-loading hand-off and the event hand-off do the same thing.

**What it touches.** The carb-loading picks, the router, the hand-off targets.

> 2026-09-15 opened in wave 4 ticket 27
> 2026-09-20 answered by mp-423

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

## mp-377 · The opener still offers a chip the hand-off now answers
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

## mp-379 · Periods longer than a week overlap
- category: Plan tab
- kind: question
- status: answered
- linked: mp-269
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 4 ticket 29

**Context.** Period starts keep a weekly cadence, so a ten-day period beginning Monday is followed by another start the next Monday: the periods overlap by three days. The ticket that fills a cooking period rather than fourteen slots is still ahead.

**Question.** Does the next ticket need chained, non-overlapping periods, and if so what anchors the chain?

**Why.** Counting meals against a period that overlaps the next one double-counts the shared days.

**What it touches.** The plan maths, the next meal-planning ticket.

> 2026-09-15 opened in wave 4 ticket 29
> 2026-09-20 answered by mp-424

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

## mp-381 · The reminder text still names fixed days
- category: Plan tab
- kind: question
- status: answered
- linked: mp-269
- image: none
- caption:
- screen: Vana settings
- source: wave mealplanning 4 ticket 29

**Context.** The reminders row still reads "The night before cook day and Sunday evening", whatever the athlete's start day is.

**Question.** Should it name the athlete's own days?

**Why.** mp-269 clause 3 has every surface read the settings, and this one still speaks for Sunday.

**What it touches.** Vana settings, the reminder copy.

> 2026-09-15 opened in wave 4 ticket 29
> 2026-09-20 answered by mp-424

## mp-382 · Can Vana change the two new settings in conversation?
- category: Plan tab
- kind: question
- status: answered
- linked: mp-269
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 29

**Context.** Vana's setting tool still accepts the four older keys only. The start day and the period length can be changed on the settings screen alone.

**Question.** Should Vana be able to set them mid-conversation when an athlete says "my week starts Monday"?

**Why.** Every other setting she can hear, she can save.

**What it touches.** The setting tool, Vana settings.

> 2026-09-15 opened in wave 4 ticket 29
> 2026-09-20 answered by mp-424

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

**Context.** mp-268 illustrates the general opener with "I see you are planning an event", and ticket 28's own check was to open the sheet on an event and hear about that event. mp-264 puts the launcher on exactly three routes — the main tabs screen, the meal-planning screen and the formula library — and anything pushed over them hides it. The event screen is none of those, so on a device there is no way to open the sheet there: the check could not be run. The server side is built and tested; an event, meal or session screen does produce an opener about the thing in view when a Situation naming it arrives.

**Question.** Should the launcher widen to the screens whose Situation the opener can already speak for (the event, meal and session screens), or should mp-268's example be rewritten to the screens the launcher actually reaches?

**Why.** As it stands the opener's best behaviour is unreachable by hand, and the ticket carries a check nobody can perform.

**What it touches.** The launcher's allow-list, the general opener, the event, meal and session screens.

> 2026-09-15 opened in wave 4 ticket 28
> 2026-09-20 answered by mp-421

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

**Question.** Why the two totals differ, and which one an athlete should be shown — is the section built from different quantities, or is the editor's strip rounding differently?

**Why.** The point of the draft on the wire is that Vana sees what is on screen; two totals for one screen undoes that.

**What it touches.** situation.ts, the formula editor's macro strip.

> 2026-09-16 opened in wave 5 ticket 17
> 2026-09-20 answered by mp-422

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

**Question.** Should the columns and their readers be retired, or do they stay as a fading record?

**Why.** A column nothing writes still shows old text to whoever reads it.

**What it touches.** The formulas repository, the insight columns, the old feature flag.

> 2026-09-16 opened in wave 5 ticket 17
> 2026-09-20 answered by mp-428

## mp-396 · Is a forty-character name cap the right shape?
- category: Situation awareness
- kind: question
- status: answered
- linked: mp-274
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 17

**Context.** The draft's name is the only free text that travels with a message, capped at forty characters and otherwise unshaped, because it is whatever the athlete typed.

**Question.** Is the cap enough, or should the name be shaped further before it reaches the prompt?

**Why.** mp-043 keeps free text off the wire; this is its one exception.

**What it touches.** situation.ts, the draft on the wire.

> 2026-09-16 opened in wave 5 ticket 17
> 2026-09-20 answered by mp-422

## mp-397 · Nothing in the app lets an athlete choose their walk
- category: Plan tab
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: Vana settings
- source: wave mealplanning 5 ticket 30

**Context.** mp-231 clause 1 says the walk covers only the types the athlete plans, in their order. The walk is a keyed setting Vana can write, but the settings screen has no control for it, so it is reachable only through conversation.

**Question.** Does the settings screen get a meal-type picker, and is that its own ticket?

**Why.** A setting only a conversation can change is invisible to most people.

**What it touches.** Vana settings, the walk setting.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425

## mp-398 · Should "every meal" count four slots a day?
- category: Plan tab
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** Coverage widens only when the athlete sets an explicit walk. An athlete whose scope is "every meal" still has lunch and dinner counted, with breakfast and snacks left as macros.

**Question.** Should choosing "every meal" widen the denominator to four slots a day?

**Why.** It is the one place the old scope and the new walk disagree.

**What it touches.** Coverage on both sides, the review sheet.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425

## mp-399 · Per-day coverage counts a night, whatever the servings
- category: Plan tab
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** In per-day mode a meal covers one night however many servings it makes, so an athlete cooking two servings for a partner reads as one night covered.

**Question.** Is that the right reading of "people who do not batch plan per day"?

**Why.** It decides what the review sheet tells a couple who cook together.

**What it touches.** Coverage on both sides, the review sheet.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425

## mp-400 · The one-tap draft has no tap yet
- category: The planning conversation
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: Vana sheet
- source: wave mealplanning 5 ticket 30

**Context.** mp-231 clause 5 says one tap drafts the period from what they ate last time. The server has the tool and the action, but no screen sends it: today it is a sentence to Vana.

**Question.** Where does the tap live — a quick reply, a button on the Plan tab, or the plan bar?

**Why.** The decision says one tap, and there is not one.

**What it touches.** The Plan tab, the Vana sheet, the one-tap draft.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425

## mp-401 · Suggestions do not yet favour what they have cooked
- category: Meals tab and library
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** mp-231 clause 5 opens with "suggestions give the highest weight to meals the athlete has liked or already cooked". The ticket built the one-tap draft but left the suggestion ranking untouched, and its acceptance criteria never named it.

**Question.** Does the ranking change now, and under which ticket?

**Why.** Half a clause of an approved decision is unbuilt and nothing tracks it.

**What it touches.** The meal search ranking.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425

## mp-402 · A staples fallback still assumes fourteen slots
- category: Plan tab
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** The staples diagnosis still falls back to fourteen slots when it has no coverage to read — the fixed number this ticket exists to remove.

**Question.** Should it fall back to the athlete's period, or say nothing when it has no coverage?

**Why.** It is the last fourteen left in the planning path.

**What it touches.** The planning tools, the staples diagnosis.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425

## mp-403 · A scope-only draft reads as empty
- category: Situation awareness
- kind: question
- status: answered
- linked: mp-274
- image: none
- caption:
- screen: Formula editor
- source: wave mealplanning 5 ticket 17

**Context.** The section calls a draft empty when it has no name, no phase and no components, even when the athlete has already chosen a sub-phase, a duration or an activity. Vana is then told there is nothing in it yet, while the screen shows the scope.

**Question.** Should a draft carrying only its scope be described by that scope rather than called empty?

**Why.** It is the first thing an athlete sets, and Vana is told it is not there.

**What it touches.** situation.ts, the formula editor's conversation.

> 2026-09-16 opened in wave 5 ticket 17
> 2026-09-20 answered by mp-422

## mp-404 · The shared coverage fixture does not test the part that must agree
- category: Plan tab
- kind: question
- status: answered
- linked: mp-231
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave mealplanning 5 ticket 30

**Context.** The server and the app now read one fixture so their coverage agrees. For the cases with no explicit walk, the fixture hands the app the list of types the server derives, so the derivation itself — the thing most likely to drift — is compared only in hand-written cases on one side.

**Question.** Should the fixture carry the inputs and let each side derive the walk, so the seam tests the derivation and not the answer?

**Why.** A shared fixture that hands over the answer proves less than it looks.

**What it touches.** The coverage fixture, both coverage seams.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-425

## mp-405 · A fuelling conformance test is red before this wave
- category: Process and scope
- kind: question
- status: answered
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 5 ticket 30

**Context.** The suite carries a failing case in the create-flow fuelling controls: the clamp-bound stepper is expected to carry a "Capped: session in …" caption and shows "1 h — early start" instead. It fails the same way at this wave's base commit, so it is not this wave's doing, and it sits beside the two failures already known to be environmental.

**Question.** Is the caption's precedence wrong, or is the test's expectation out of date — and who owns fixing it?

**Why.** A red test nobody owns trains everyone to read red as normal.

**What it touches.** The fuelling window authority, the create-flow conformance test.

> 2026-09-16 opened in wave 5 ticket 30
> 2026-09-20 answered by mp-428

## mp-410 · Do the meals behind Show more count as shown?
- category: The planning conversation
- kind: question
- status: answered
- image: none
- caption:
- screen: none (contract)
- source: wave mealplanning 6 ticket 31
- linked: mp-230

**Context.** mp-230 clause 5 says "Other options" never repeats a meal already shown in the conversation. The tail behind Show more is not marked shown, because the server cannot know whether the sheet was ever opened, and marking twenty-four meals per picker would starve later suggestions fast. An athlete who read the sheet may see one of its meals offered again.

**Question.** Should the tail count as shown, only when the sheet is opened, or not at all?

**Why.** It is a one-line change either way, and only a device pass will say which feels wrong.

**What it touches.** tools.ts.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-426

## mp-411 · A fixed tail of twenty-four, and no chip when the tail is empty
- category: The planning conversation
- kind: question
- status: answered
- image: none
- caption:
- screen: vana-sheet
- source: wave mealplanning 6 ticket 31
- linked: mp-230

**Context.** mp-230 clause 2 reads Show more as always present and says the count is not fixed. The build carries at most twenty-four meals past the tiles, and when a filtered search leaves nothing past them the chip is not drawn at all.

**Question.** Is a fixed cap acceptable, and should Show more appear over an empty tail (as a door that says so) or vanish?

**Why.** The review read the clause as unconditional; the build read an empty sheet as not a door.

**What it touches.** tools.ts, picker_chips.dart, vana_part_renderer.dart.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-426

## mp-412 · A tick in the More sheet does not reach the picker's swap circles
- category: The planning conversation
- kind: question
- status: answered
- image: none
- caption:
- screen: vana-sheet
- source: wave mealplanning 6 ticket 31
- linked: mp-230

**Context.** The sheet copies the set of picked ids when it opens. A meal ticked in the sheet is added to the draft, but the tiles behind it do not show the swap circle until the next part arrives, and a meal added on the tiles while the sheet is open shows unticked in the sheet.

**Question.** Should the two surfaces share one live picked set, or is a refresh on the next part enough?

**Why.** mp-230 clause 3 gives picked tiles a swap circle; across the two surfaces that is only half honoured.

**What it touches.** picker_more_sheet.dart, vana_part_renderer.dart.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-426

## mp-413 · The persona text is edited here and not in the prototype
- category: Process and scope
- kind: question
- status: answered
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 6 ticket 31

**Context.** persona.ts carries a note that its text is verbatim from the prototype repo and must be edited in both places. Wave 6 edited it here only; the prototype is outside the worktree.

**Question.** Is the prototype's copy still a source of truth, or can the note go?

**Why.** A note that says "edit both" and is obeyed by nobody is a trap.

**What it touches.** persona.ts.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-428

## mp-414 · The More sheet is a plain modal, not a glass sheet
- category: Design system
- kind: question
- status: answered
- image: none
- caption:
- screen: vana-sheet
- source: wave mealplanning 6 ticket 31

**Context.** The vana-sheet spec records that every future summoned glass surface inherits the glass-sheet material and its scrim. The More sheet composes MealCard and the browse Add button over the app's adaptive modal, with no material token cited.

**Question.** Does the More sheet inherit the glass-sheet material, or is a summoned list sheet exempt?

**Why.** The standards review flagged it as a check for design-sync, not a breach of the current text.

**What it touches.** picker_more_sheet.dart, the vana-sheet spec.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-428

## mp-415 · A cloned wave simulator lands on the paywall
- category: Process and scope
- kind: question
- status: answered
- image: none
- caption:
- screen: none (process)
- source: wave mealplanning 6 ticket 31

**Context.** The ticket's device check claimed a pool simulator, built and launched the branch on it, and sat on the Pro paywall: a freshly cloned simulator has no StoreKit receipt, Restore purchases finds nothing, and the debug wrench does not get past it. Meal-planning surfaces were unreachable, so the check was not run. Both halves of the ticket also arrive on the wire from vana-chat, which no wave deploys.

**Question.** How a wave agent reaches a Pro surface on a pool device: copy the dev simulator's receipt state, a dev-only bypass, or accept that Pro surfaces are checked on the dev simulator after the wave.

**Why.** Every remaining meal-planning ticket sits behind the paywall.

**What it touches.** sync.mjs simulator claim, the dev paywall gate.

> 2026-09-16 opened in wave 6 ticket 31
> 2026-09-20 answered by mp-428

## mp-419 · Vana's memory: what was built after your rethink, and four loose ends
- category: Vana's memory
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-419.svg
- screen: none (algorithm/data)
- source: spec.md; ticket 03; memory 09-10; memory 09-11; commit 1dedc493; wave mealplanning 1 ticket 13; wave mealplanning 2 ticket 14; wave mealplanning 3 ticket 15
- work: pending
- linked: mp-315; mp-334; mp-349; mp-351

**Context.** On 09-14 you held six memory cards and asked for a rethink. On 09-15 you approved mp-277 (history in chunks, notes as they happen, one summary when a conversation goes idle). Tickets 13 to 15 built it. This card replaces the six held cards, ratifies what the tickets built, and answers the four questions the agents left.

**Question.** Is the memory build that followed mp-277 right, and how do the four questions it raised get answered?

**Decision.** 1. The five held cards about the 20-message replay and the mid-conversation episode are retired. mp-277 replaced them. (mp-032 to mp-036) [no work]
2. Past conversations reach Vana as a LAST TALKS line: what the athlete said, not a read-out of their schedule. Memories hold only notes. (mp-038) [built]
3. A long conversation is summarised in chunks of twenty messages and the summary is kept on the conversation. (mp-333) [built]
4. The conversation list previews each conversation with its one-sentence summary. The internal "Through message 20…" text never shows on screen. (mp-334) [to build]
5. When the app says a conversation is idle, the server answers at once and writes the summary in the background. A repeat signal writes nothing. (mp-347) [built]
6. If a conversation gains messages after its summary was written, the next close summarises it again. One summary per conversation, always the latest. (mp-349) [to build]
7. Only a change the athlete makes through Vana, or a new day, rebuilds the cached context. Notes the server writes for itself do not. A home location, a thumb or a profile edit made outside Vana waits for the next of those. (mp-313, mp-315) [built]
8. The context block is capped at 1,500 estimated tokens, and a test fails if it grows past that. (mp-314) [built]
9. The "Remembered" card shows only when the athlete asked Vana to remember something. Notes she saves on her own stay silent, as mp-027 already says. (mp-351) [to build]

**Why.** One card instead of fourteen. Clauses 4, 6 and 9 are the only new work; the rest is already in the code and on dev.

**What else was considered.** Ruling each of the fourteen cards separately.

**What it touches.** vana-chat history and summary, the context block, the conversation list, the Remembered card.

**Details.** Summary boundaries are fixed multiples of twenty so the cached prefix changes once per chunk. Context budget constant CONTEXT_BLOCK_TOKEN_BUDGET = 1500, estimated as characters / 4. Idle is answered 202 and never charged a credit.

> 2026-09-20 folded from mp-032, mp-033, mp-034, mp-035, mp-036, mp-038, mp-313, mp-314, mp-333, mp-347; answers mp-315, mp-334, mp-349, mp-351

## mp-421 · Openers: what Vana says first, and where
- category: Vana's voice and openers
- status: proposed
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Vana sheet
- source: wave mealplanning 4 ticket 27; wave mealplanning 4 ticket 28
- work: pending
- linked: mp-352; mp-367; mp-368; mp-369; mp-377; mp-384; mp-394

**Context.** mp-268 says the general conversation opens on the screen underneath. Ticket 28 built it and left seven questions about which screen, which order and which chips. On 09-16 you also ruled that Vana drafts every opener herself and never picks from templates.

**Question.** What does Vana open on in each place, and what happens when the athlete asks for a plan?

**Decision.** 1. The order is: a live moment (a fuelling window) first, then the screen underneath, then the personal opener. (mp-364, mp-368) [built]
2. A request for a plan is a plan request even with a constraint ("quick dinners this week"). Vana hands off to the meal-planning screen and the constraint goes with it. (mp-363) [built]
3. When the opener offers to start a meal plan, that offer is the hand-off button itself. No chip that then produces a button. (mp-377) [to build]
4. The Plan tab with a plan in view opens on that plan. (mp-367) [to build]
5. Ask Vana from the formula editor opens on the formula. (mp-394) [to build]
6. The full-screen chat asks for an opener the same way the sheet does, instead of opening empty. (mp-369) [to build]
7. Picking up last time in an offer chip counts. The opener's sentence does not have to say it as well. (mp-352) [no work]
8. The launcher stays on its three screens (mp-264). mp-268's example of opening on an event is reached through the hand-off, not by putting the launcher on the event screen. (mp-384) [no work]

**Why.** Each answer follows a ruling you already made: the screen underneath (mp-268), three launcher screens (mp-264), hand-offs for every flow the app owns (mp-265).

**What else was considered.** Widening the launcher to event, meal and session screens (clause 8). Letting the screen underneath outrank a live moment (clause 1).

**What it touches.** The opener path in vana-chat, the sheet, the full-screen chat, the Plan tab, the formula editor.

**Details.** "The screen says something useful" is decided by resolving the Situation with and without the entity id: a different sentence means the athlete's own row was read. The opener logs which of the three paths fired.

> 2026-09-20 folded from mp-363, mp-364; answers mp-352, mp-367, mp-368, mp-369, mp-377, mp-384, mp-394

## mp-422 · What Vana is told about the screen in view
- category: Situation awareness
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/formula-editor.png
- caption:
- screen: Formula editor, Plan tab
- source: wave mealplanning 5 ticket 17
- work: pending
- linked: mp-370; mp-371; mp-393; mp-396; mp-403

**Context.** mp-273 gives every entry point the same athlete context plus one short section for what is on screen. mp-274 lets the formula editor send its unsaved draft. Tickets 16 and 17 built both. On the simulator Vana said 142 g of carbs for a draft the editor showed as 133 g.

**Question.** What does each screen tell Vana, and why did her carb total differ from the formula editor's?

**Decision.** 1. The formula editor sends its draft as fixed fields only: phase, sub-phase, durations, activities, component ids with quantities, and a name of at most 40 characters. A draft from any other screen is dropped without an error. (mp-385, mp-396) [built]
2. The server looks the component names up from the athlete's own foods. The app sends ids, never names. (mp-385) [built]
3. The formula section carries the editor's own carb total. Vana repeats that number and never adds it up herself, so the two can never disagree. (mp-386, mp-393) [to build]
4. A draft that has a scope (a sub-phase, a duration or an activity) is described by that scope, not called empty. (mp-403) [to build]
5. The Plan tab's section speaks for the day on screen, plus one line on the week's servings left. (mp-371) [to build]
6. The persona names the in-view section in one sentence, the way it names the Situation. (mp-370) [to build]

**Why.** Clause 3 is a bug an athlete would see. Fuelling numbers never come from the model (mp-005), so the fix is to hand her the app's number.

**What else was considered.** Letting Vana compute totals from the quantities. Sending the whole week in the Plan tab section.

**What it touches.** The Situation resolver, the formula editor, the Plan tab section, the persona.

> 2026-09-20 folded from mp-385, mp-386; answers mp-370, mp-371, mp-393, mp-396, mp-403
> 2026-09-21 picture captured at 1.27.0+3, 18e21789

## mp-423 · The sheet, the launcher and the hand-off button
- category: The sheet and launcher
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/timeline-launcher.png
- caption:
- screen: Vana sheet
- source: wave mealplanning 1 ticket 23; wave mealplanning 3 ticket 15; wave mealplanning 4 ticket 16; wave mealplanning 4 ticket 27; wave mealplanning 5 ticket 17
- work: pending
- linked: mp-350; mp-372; mp-373; mp-374; mp-375; mp-376

**Context.** You approved mp-264 (Vana on three screens), mp-265 (one sheet height, every flow the app owns is a hand-off) and mp-275 (what continues the day's conversation). Tickets 15, 16, 17, 23 and 27 built them. This card ratifies the build and answers six questions from it.

**Question.** How do the three-screen launcher, the one-height sheet and the hand-off button work in practice?

**Decision.** 1. The launcher shows on the main tabs, the meal-planning screen and the formula library, and hides whenever anything is pushed or popped over them. No screen has to name itself. (mp-326) [built]
2. The sheet is three quarters of the screen. It closes by the platform's own rule, a drag past half or a flick. The grabber is only a handle. (mp-361) [built]
3. A hand-off is a button Vana offers, labelled in the athlete's own words (60 characters at most), that opens the screen that owns the job: meal plan, new activity, event. It works in the full-screen chat too. (mp-362) [built]
4. Vana offers a hand-off only when she can name the thing. With no event named she asks which one, instead of landing on a blank form or a bare list. (mp-374) [to build]
5. A carb-loading hand-off opens the carb-loading picks for that event directly. (mp-373) [to build]
6. A fuelling hand-off edits the workout Vana named and never creates a second one. This gets checked on the simulator. (mp-375) [to build]
7. One controller decides which conversation is "today's". New meal plan, the plus button and Ask Vana in the formula editor each start a new conversation and never move that pointer. (mp-360, mp-387, mp-372) [built]
8. The app tells the server a conversation is idle when the sheet closes, the app goes to the background, a new conversation starts, or the athlete leaves the full-screen chat. At most once per opening. (mp-348, mp-350) [built, except leaving the full-screen chat]
9. Closed as already done: two new conversations sharing one screen was fixed on 09-16 (761d4d6f), and the status chip question is gone because you had the chip deleted on 09-16. (mp-372, mp-376) [no work]

**Why.** Clauses 1 to 3 and 7 are in the code. Clauses 4 to 6 finish the hand-off so it never lands somewhere useless.

**What else was considered.** Landing on a blank form when no entity is named. Keeping carb loading on the event screen.

**What it touches.** The launcher rule, the sheet, the hand-off part, the ambient conversation controller, the carb-loading picks, the new-activity screen.

**Details.** Launcher rule test walks every route the router declares. Hand-off targets: meal plan -> meal-planning page, fuelling -> new-activity screen, event and carb loading -> event screen (today).

> 2026-09-20 folded from mp-326, mp-348, mp-360, mp-361, mp-362, mp-387; answers mp-350, mp-372, mp-373, mp-374, mp-375, mp-376

## mp-424 · The planning period: start day and length
- category: Plan tab
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption:
- screen: Vana settings
- source: wave mealplanning 4 ticket 29; wave mealplanning 4 ticket 16
- work: pending
- linked: mp-378; mp-379; mp-380; mp-381; mp-382

**Context.** You approved mp-269: the week's start day and the period's length are the athlete's settings. Ticket 29 built them. Seven days from Sunday was the only shape the code knew, so a ten-day period raised five questions.

**Question.** How do a start day and a period other than seven days behave?

**Decision.** 1. The two settings sit in Vana settings: a popup of the seven days and a stepper from 3 to 14 days. Cooking labels use the athlete's own day ("Cook Monday"). (mp-366, mp-365) [built]
2. Every place that works out a week or a cook day reads the athlete's period, never the Sunday default. (mp-358) [built]
3. Periods follow each other with no overlap. A ten-day period is followed by the next ten-day period, starting where the last one ended. (mp-379) [to build]
4. A plan records the period it was built for, so changing the setting never re-reads an old plan. (mp-380) [to build]
5. Changing the start day mid-period leaves the current plan alone until it ends. The new setting applies from the next period. (mp-378) [to build]
6. The reminder text names the athlete's own days. (mp-381) [to build]
7. Vana can change both settings in conversation ("my week starts Monday"). (mp-382) [to build]

**Why.** Clauses 3 to 5 are one fix: once a plan carries its own period, overlap and mid-period changes stop being problems.

**What else was considered.** Keeping a weekly cadence with overlapping periods. Moving the current plan when the start day changes.

**What it touches.** Vana settings, the Plan tab, the plan row (one new column), coverage, reminders, Vana's settings tool.

**Details.** Length limited to 3 to 14 days: below three the three cooking sessions collapse onto one day. The period length travels on the coverage wire and the week part.

> 2026-09-20 folded from mp-365, mp-366, mp-358; answers mp-378, mp-379, mp-380, mp-381, mp-382

## mp-425 · Batches, servings and coverage
- category: Plan tab
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption:
- screen: Plan tab
- source: wave mealplanning 5 ticket 30
- work: pending
- linked: mp-397; mp-398; mp-399; mp-400; mp-401; mp-402; mp-404

**Context.** You approved mp-231: a plan fills a cooking period, not fourteen fixed slots. Ticket 30 built it and left seven questions.

**Question.** How big is a batch, what does coverage count, and where is "same as last time"?

**Decision.** 1. A batch is three meals per meal type. Servings are the period divided by three, rounded up: 7 days gives 3, 10 gives 4, 14 gives 5. A per-day planner gets one serving per pick. (mp-389) [built]
2. Coverage counts the period's days times the meal types the athlete plans. Someone who never chose keeps lunch and dinner, so existing plans' numbers do not move. (mp-390) [built]
3. Choosing "every meal" counts four slots a day. (mp-398) [to build]
4. A per-day planner cooking two servings covers two nights, not one. (mp-399) [to build]
5. "Same as last time" copies last period's meals at the servings they were cooked at and never doubles a meal already in the draft. (mp-391) [built]
6. Its tap is a button on the Plan tab's empty week, and Vana offers it in the planning opener. (mp-400) [to build]
7. Suggestions rank liked and already-cooked meals first, as mp-231 says. This gets its own ticket. (mp-401) [to build]
8. Vana settings gets a meal-type picker, so the athlete can choose what they plan without asking Vana. (mp-397) [to build]
9. A plan with no cooking mode on it means batch, in the app and on the server. (mp-392) [built]
10. Where coverage is unknown the staples check says nothing, instead of assuming fourteen slots. The shared test fixture carries the inputs so both sides work the answer out themselves. (mp-402, mp-404) [to build]

**Why.** Clauses 1, 2, 5 and 9 are built. The rest finish mp-231 where ticket 30 stopped.

**What else was considered.** Rescaling copied meals to the new period (invented numbers). Defaulting every pick to four servings.

**What it touches.** The Plan tab, coverage on both sides, the planning conversation, Vana settings, suggestion ranking.

> 2026-09-20 folded from mp-389, mp-390, mp-391, mp-392; answers mp-397, mp-398, mp-399, mp-400, mp-401, mp-402, mp-404
> 2026-09-21 picture captured at 1.27.0+3, 18e21789

## mp-426 · Pickers: named chips and Show more
- category: The planning conversation
- status: proposed
- image: test/features/meal_planning/presentation/goldens/vana_sheet_open_light.png
- caption:
- screen: Planning conversation
- source: wave mealplanning 6 ticket 31
- work: pending
- linked: mp-410; mp-411; mp-412

**Context.** You approved mp-272 (a turn may name the chips it expects next) and mp-230 (Show more opens many more options from the same search). Ticket 31 built both.

**Question.** Which chips can a turn name, and what sits behind Show more?

**Decision.** 1. A turn's named chips replace only the two reply chips ("I like these", "Other options"). The doors and filters stay. Chips belong to a picker, so a turn without a picker names none. (mp-406, mp-409) [built]
2. Both the server and the app trim the list to two to four chips. A broken list means the app shows its own set. (mp-408) [built]
3. Show more opens the rest of the same search, up to 24 more meals, with no new query. (mp-407) [built]
4. Meals behind Show more count as shown only if the athlete opened the sheet. (mp-410) [to build]
5. When nothing is left behind Show more, the chip is not drawn. 24 is enough. (mp-411) [no work]
6. A tick in the Show more sheet shows on the tiles behind it at once, and the other way round. (mp-412) [to build]

**Why.** Clauses 1 to 3 are built. Clause 6 is the one an athlete would notice.

**What else was considered.** Marking all 24 meals as shown whether or not the sheet was opened, which starves later suggestions.

**What it touches.** The picker part, the Show more sheet, the planning conversation.

> 2026-09-20 folded from mp-406, mp-407, mp-408, mp-409; answers mp-410, mp-411, mp-412

## mp-427 · Meal reviews, recipe origin labels and typed feedback
- category: Meals tab and library
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/meal-detail.png
- caption:
- screen: Meal detail
- source: wave mealplanning 1 ticket 25; wave mealplanning 2 ticket 32; wave mealplanning 1 ticket 26
- work: pending
- linked: mp-330; mp-346; mp-332

**Context.** Tickets 25, 26 and 32 each built something you had already approved (mp-144 clause 3, mp-245 clause 6, mp-146) and each left one question.

**Question.** Are the three small builds from wave 1 and 2 right: admin meal reviews, origin labels on recipes, and typed feedback reaching Wiredash?

**Decision.** 1. An admin sees a review box on every meal: Good recipe or Not good, a reason, Send. Reviews wait for the server before saying sent. Only admins can read them. (mp-329) [built]
2. The team reads reviews in the database for now. Each row gets the app version. No screen until there are enough reviews to need one. The table goes to production with the cutover. (mp-330) [to build: the version stamp]
3. A recipe says where its steps came from in one line under Directions: "As published by X" with a link, "Steps from X", or "A simple assembly, no recipe needed". AI-written steps keep the sparkle. (mp-345) [built]
4. A published recipe links the original once, from the new label. The older "See the original recipe" row goes, which also removes the overflow on narrow phones. (mp-346) [to build]
5. Feedback typed to Vana is filed to the same Wiredash inbox as a shaken report, from the device, with the label "vana-chat" so the inbox can filter it. (mp-331, mp-332) [built, except the label]
6. Wiredash has no public way to file an entry without its screen, so the app uses the SDK's internals with the version pinned. Ask Wiredash for a public call. Every Wiredash upgrade re-checks the filer. (mp-332) [no work]

**Why.** All three are small and already on dev.

**What else was considered.** Building a review screen now. Keeping both links to the original recipe.

**What it touches.** Meal detail, the meal_reviews table, the recipe screen, Vana's feedback tool, Wiredash.

**Details.** Review migration 20260916120000 on dev. Reason capped at 2,000 characters. Wiredash metadata: source vana_chat, sentiment, about, conversation id, user id and email.

> 2026-09-20 folded from mp-329, mp-345, mp-331; answers mp-330, mp-346, mp-332

## mp-428 · Housekeeping: fifteen questions that need no product ruling
- category: Process and scope
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/settings.png
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-428.svg
- screen: none (algorithm/data)
- source: wave mealplanning 1 ticket 24; wave mealplanning 5 ticket 17
- work: pending
- linked: mp-322; mp-325; mp-328; mp-339; mp-354; mp-355; mp-356; mp-357; mp-383; mp-395; mp-405; mp-413; mp-414; mp-415; mp-338

**Context.** Build agents are told to raise anything they are unsure of. Fifteen of those questions are about process, tests and tidying, not the product. You said on 09-16 not to park things for your decision, so each gets an answer here. Tick any clause you disagree with.

**Question.** Can the engineering loose ends the build agents raised be closed in one go?

**Decision.** 1. The dev-tools switch sits in a "Dev build" card on Settings, remembered per device. The card moves up so the floating buttons do not cover it. (mp-327, mp-328) [built, except the move]
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

**Why.** None of these changes what an athlete sees, except the glass sheet. They were making the page look heavier than it is.

**What else was considered.** Ruling each separately.

**What it touches.** Settings, the release doc, the dev entitlement table, the design specs list for Xuan, the conformance suite, persona.ts.

**Details.** Dev-tools key dev.tools_visible. The eval entitlement row: user 37129f7e, period_type "eval", written 2026-09-15 19:05Z.

> 2026-09-20 folded from mp-327, mp-388; answers mp-322, mp-325, mp-328, mp-339, mp-354, mp-355, mp-356, mp-357, mp-383, mp-395, mp-405, mp-413, mp-414, mp-415, mp-338

## mp-510 · How a hand grant reaches the dev webhook
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-454
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave paywall 1 ticket 01

**Context.** Ticket 01's last check was a hand grant on a dev account showing up in its row. RevenueCat logs every grant as a PRODUCTION event, and the dev webhook integration in RevenueCat only takes sandbox events, so the grant (2026-09-21, a throwaway dev account) went to the production webhook, which ignored it. Dev and prod share one RevenueCat project. The new webhook is deployed on dev with the secret key set; it simply never hears about grants.

**Question.** Should the dev integration take every environment (then real production purchases also reach dev and fail to match a user), or should grants be tested another way?

**Why.** Until one is chosen, no grant (coach, grace month, giveaway) can be tried on dev end to end, and tickets 06, 07 and 09 all grant.

**What it touches.** RevenueCat's dev webhook integration, tickets 06, 07, 09.

> 2026-09-21 opened in wave 1 ticket 01
> 2026-09-22 answered by mp-533

## mp-511 · The Test Store still sells the old products on the dev simulator
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-452
- image: none
- caption:
- screen: Paywall
- source: wave paywall 1 ticket 03

**Context.** The dev app on the simulator buys through RevenueCat's Test Store. The Test Store app holds only the old `mealvana_pro_*` products at $9.95 and $69.00, they are still in its `default` offering, and it has nothing in `founding`. So the dev simulator shows the old prices and cannot show founding prices, and ticket 03's last check (new prices on the simulator) could not pass. mp-452 clause 4 says the old products leave every offering.

**Question.** Should the Test Store get `me_pro_*` products in `default` and `founding`, with the old ones taken out?

**Why.** Without it no simulator check of the paywall's prices or the founding switch can pass, and every paywall ticket after 03 has one.

**What it touches.** RevenueCat Test Store app, `default` and `founding` offerings, tickets 14 to 18.

> 2026-09-21 opened in wave 1 ticket 03

## mp-512 · Does a granted account get the monthly Allowance
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-454
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave paywall 1 ticket 01

**Context.** The webhook grants the Allowance only on a first purchase or a renewal. A grant (a coach's 30 days, the grace month, a hand grant) is a promotional event, so a granted account can call Vana but gets no Allowance credits.

**Question.** Should an account with granted access get the monthly Allowance like a paying one?

**Why.** The grace month goes to every existing account on flip day (mp-429 clause 5); without an Allowance, what they can do with Vana depends on credits they bought before.

**What it touches.** revenuecat-webhook, the credit wallet, the ai-cost monthly budget (mp-430).

> 2026-09-21 opened in wave 1 ticket 01

## mp-513 · The paywall's trial and renewal wording
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-453
- image: none
- caption:
- screen: Paywall
- source: wave paywall 1 ticket 03

**Context.** mp-453 fixes what the paywall must say, not the words. Ticket 03 drafted them into the content defaults: the trial terms ("{days} days free … Nothing is charged during the free week"), the renewal terms ("Cancel at least 24 hours before it renews…") and the link labels. The trial line counts days from the store but says "week" in fixed words.

**Question.** Are the drafted trial and renewal sentences what Lee and Xuan want on the paywall?

**Why.** It is the copy beside the purchase button and it goes to store review.

**What it touches.** Content defaults `paywall.trial_terms`, `plans_terms`, `renewal_terms`, `founding_line`, the link labels.

> 2026-09-21 opened in wave 1 ticket 03

## mp-514 · What the app shows when an AI call is refused for no subscription
- category: Pro and paywall
- kind: question
- status: open
- linked: mp-505
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave paywall 1 ticket 02

**Context.** The five AI functions now answer 403 `pro_required` to an account with no subscription (mp-505). Only Vana reads that answer. Describe and photo show "The AI service returned an error. Please try again.", the coach insight and the old chat treat it as a server error, and the photo tool as another 403.

**Question.** Should these screens open the paywall (or say the subscription lapsed) instead of a generic error?

**Why.** Under the read-only shell (mp-429 clause 6) a lapsed athlete can still reach these buttons; a "try again" error invites them to retry forever.

**What it touches.** Meal AI service, AI coach client, the old chat repository, the meal photo repository, tickets 11 and 17.

> 2026-09-21 opened in wave 1 ticket 02

## mp-515 · How fast one athlete can call each AI feature, and how big one Vana turn can get
- category: Cutting costs
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-515.svg
- screen: none (algorithm/data)
- source: wave ai-cost 2 ticket 04
- linked: mp-430

**Context.** mp-430 clause 9 says there is no daily cap and no cap on turns, and that a call is counted when it starts. Ticket 04 built the per-minute limiter that does the counting. Before it, the chat limit could be passed by firing requests at once, openers were never limited in practice, and the fridge photo, the described meal and the meal photo had no limit at all. The ticket named no numbers, so the build chose them.

**Question.** What are the burst limits for each AI call, how large can one turn get, and what does the athlete read when refused?

**Decision.** 
1. Chat stays at 4 messages in 10 seconds.
2. Openers get 6 a minute. The old figure of 3 was never enforced; 6 leaves room for a screen that opens a moment and a chat together.
3. The fridge photo gets 3 a minute. The described meal and the meal photo get 6 a minute each. Each has its own bucket, so a photo never blocks a chat message.
4. One Vana turn stops at 150,000 tokens as well as at its step limit. The count includes cached input.
5. A refused meal analysis reads "Too many at once — try again in {n} seconds." from the content system. Chat keeps its own line.
6. No limit is longer than a minute. The monthly budget stays the only ceiling on total use.

**Why.** These are guards against a loop or a script, set well above what a person does. On dev over 14 days a planning turn ran 22,000 tokens at the median and 85,000 at most, so the first build's 60,000 would have cut off 6 of 52 real turns.

**What else was considered.** One shared bucket for every AI call, which would let a photo block a chat turn. Leaving openers unlimited until the monthly budget lands. A 60,000-token ceiling, found too low in the wave's review.

**What it touches.** The shared Vana rate limiter, the chat turn, the fridge photo action, describe-meal, analyze-meal-photo, the content defaults.

**Details.** The database decides each reservation in one step (a lock on athlete and bucket, a count, an insert). On dev, eight reservations fired at once against a limit of four left four rows.

> 2026-09-21 proposed from wave 2 of ai-cost

## mp-516 · Which plan changes rewrite a day's note
- category: Plan tab
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/plan-tab.png
- caption:
- screen: Plan tab
- source: wave ai-cost 2 ticket 13
- linked: mp-432

**Context.** The Plan tab shows a short note from Vana for each of seven days. Until ticket 13, any plan change marked all seven stale and the next open rewrote them all; dev averaged 3.6 rewrites per athlete per day, 13 at the peak. The ticket asked for a rewrite of only the days an edit touched and did not say what "touched" means.

**Question.** Which changes to a plan rewrite which days' notes?

**Decision.** 
1. A day's note is rewritten when that day's assigned meals, its workouts or its macro target change. Other days keep their notes.
2. A day with nothing assigned is rewritten when any meal joins or leaves the plan, because its note may name any meal in the plan.
3. Confirming a draft, or switching batch cooking, rewrites all seven.
4. Marking a meal as eaten rewrites nothing.
5. The note for a day with assigned meals is now written from those meals, not from the whole plan.
6. Opening the Plan tab on an unchanged plan calls no model, and two requests at once share one call.

**Why.** The saving comes from writing fewer notes, and a note is only wrong when what it was written from has changed.

**What else was considered.** Rewriting an unassigned day only when a meal is removed, not on a servings change: cheaper, and left as it is until someone rules. Asking the model for all seven and storing only the changed ones, which saves nothing.

**What it touches.** The day-notes module and endpoint, the Plan tab's refresh, one new column and one claim table on meal plans.

**Details.** An edit made while notes are being written is picked up on the next open. A request that loses the claim waits up to 25 seconds for the winner's notes, then shows the stored ones. The dev count after the change is owed after a day of use (ticket 13).

> 2026-09-21 proposed from wave 2 of ai-cost
> 2026-09-21 picture captured at 1.27.0+3, 0e20c2f0

## mp-517 · No cheaper model matched: the three background jobs stay on Haiku
- category: Cutting costs
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-517.svg
- screen: none (algorithm/data)
- source: wave ai-cost 2 ticket 14
- linked: mp-465

**Context.** mp-465 clause 3 moves the memory extraction, the rolling summary and the saved-meal ingredient list to the cheapest gateway model that gives the same structured answer on 20 stored dev conversations, checked by hand. Ticket 14 ran that comparison on 2026-09-21 for about 25 cents.

**Question.** Which model runs the three background jobs after the comparison?

**Decision.** 
1. The three jobs stay on Haiku 4.5. No candidate gave the same answers.
2. They now read their model from one setting of their own, VANA_BACKGROUND_MODEL, so a later candidate is a rerun of the test script and one setting.
3. The Formula Kit coach insight is removed and its function is undeployed from dev.

**Why.** Haiku wrote no memory on any of the 20 conversations, which is what the memory rules ask for. The cheap models invented memories: Nova Micro 32, Nova Lite 26, Gemini 2.5 Flash Lite 14 with three broken answers, Qwen 3.7 Flash 7. Their ingredient lists differed in substance, and that list is what Kroger matches. Only the summary matched everywhere.

**What else was considered.** Moving the summary alone, which matched; it would split one setting into two for a few cents a month. Qwen 3.7 Flash, the closest, which spent about 2,980 output tokens a call against Haiku's 105 and took 33 seconds.

**What it touches.** The extraction, summary and saved-ingredients modules, the Vana settings, the removed ai-coach function, shared coach tools and Formula Kit client.

**Details.** Prices were read from the gateway's catalogue on 2026-09-21. The comparison table is in ticket 14. The script is scripts/vana-eval/background-model.ts; the conversations are not committed.

> 2026-09-21 proposed from wave 2 of ai-cost

## mp-518 · Adding a saved meal to a plan calls a second model inside the Vana turn
- category: Cutting costs
- kind: question
- status: open
- linked: mp-465
- source: wave ai-cost 2 ticket 14

**Context.** mp-465 clause 6 says no helper model is called from inside a Vana turn, marked no work. Ticket 14 found one that already is: when Vana adds a dish-level saved meal to a plan, the turn waits for the ingredient-list model, because the shopping list it returns is built from those ingredients. This predates the ticket and was left as it is.

**Question.** Should adding a saved meal keep waiting for its ingredient list inside the turn, or build the list in the background and show the dish as one line until it is ready?

**Why.** It is the one place the rule in mp-465 clause 6 does not hold. Moving it changes what the athlete sees right after the add.

**What it touches.** Vana's add-meal tool, the saved-meal ingredient job, the shopping list.

> 2026-09-21 opened from wave 2 of ai-cost

## mp-519 · The plan an athlete is on is named in SQL from the two entitlement fields
- category: Cutting costs
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-519.svg
- screen: none (algorithm/data)
- source: wave ai-cost 3 ticket 05

**Context.** Ticket 05 asks the weekly view for cost per athlete by plan. mp-285 cut `user_entitlements` down to `active_until` and `period_type`, so no table in the database says whether an athlete bought the month or the year. The call log had nowhere to copy a plan from.

**Question.** Where does the call log get the subscriber's plan and trial state?

**Decision.** 
1. Every call row stores the two entitlement fields raw: `period_type` and `active_until` as they stood when the call finished. Nothing is stored as a plan name.
2. A SQL function names the plan when the view is read: TRIAL, INTRO and PROMOTIONAL name themselves; NORMAL access running more than 45 days past the call is `annual`, otherwise `monthly`; no row is `none`.
3. The read happens on the background task that finishes the call, never on the athlete's request path, and a read that fails logs nulls rather than losing the call.
4. Logged meals (the described meal and the meal photo) carry the same two fields as a chat turn.

**Why.** Storing the raw pair lets the label be re-cut in the view when the products change, with no backfill and no second copy of RevenueCat's truth. Re-adding a product id to a paywall-owned table while the paywall wave is live was not an option the ticket could take alone.

**What else was considered.** A product-id column on `user_entitlements` (reopens mp-285). A computed label column on the log row (needs a backfill when products change).

**What it touches.** The call log migration, the shared subscriber reader, chat.ts, describe-meal, analyze-meal-photo, the weekly view.

**Details.** Two columns: `subscriber_period_type`, `subscriber_active_until`. The label function is `vana_plan_label(period_type, active_until, at)`. Live dev check: two turns, one typed and one tapped, both labelled from the same entitlement row.

> 2026-09-22 proposed from wave 3 of ai-cost

## mp-520 · The 45-day cut misreads an annual subscriber in the last 45 days of the year
- category: Cutting costs
- kind: question
- status: open
- linked: mp-519
- source: wave ai-cost 3 ticket 05

**Context.** mp-519 names a NORMAL subscriber `annual` when their access runs more than 45 days past the call, else `monthly`. That is exact for October, when every annual subscriber is early in their year and monthly access never runs past about 31 days. From roughly September 2027 an annual subscriber in the last 45 days of their year reads as monthly.

**Question.** Should `user_entitlements` cache the store product id after all, which reopens mp-285's two-field ruling, or is the SQL label good enough while the cohorts are young?

**Why.** It decides whether the paywall's table grows a third field, and when. Left alone, the cost-per-plan figure drifts a little each autumn.

**What it touches.** `user_entitlements`, the RevenueCat webhook, `vana_plan_label`.

> 2026-09-22 opened from wave 3 of ai-cost

## mp-521 · What a call row records, and how the weekly figures count cost
- category: Cutting costs
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-521.svg
- screen: none (algorithm/data)
- source: wave ai-cost 3 ticket 05
- linked: mp-420

**Context.** mp-420 clause 6 and mp-464 clause 7 say what the call log must gain: cache-write tokens, steps, the gateway's charge, whether the turn drew the budget, and tap or typed. Ticket 05 built the columns, one weekly view over them, a nightly rollup and the 90-day sweep. The ticket named the figures, not how each is counted.

**Question.** How does the log measure the cache, the charge and the turn, and what does the weekly view do when a call has no charge?

**Decision.** 
1. The cache hit rate is the first step's alone: `first_step_input_tokens` and `first_step_cache_read_tokens` are their own columns. Later steps read what the same turn just wrote, so a whole-turn ratio flatters the cache.
2. The gateway's charge is added up over every step of the turn. A turn where no step reported a charge stores null, never 0.
3. Cost is the gateway's charge and nothing else. There is no price table in the log; the view shows `costed_calls` beside `calls` so a week whose cost is understated says so.
4. `input_mode` is `tap`, `typed` or null. An older build that sends nothing, or a value the server does not know, logs null; the request is never refused over it.
5. The two meal-logging functions write the same fields as a chat turn (charge, cached tokens, one step, debited, subscriber state), so cost per athlete includes logging a meal. Background jobs still write tokens only.
6. Every night the complete weeks are frozen into `vana_weekly_rollup`, then raw rows strictly older than 90 days are deleted from `vana_calls`, `ai_usage` and `plan_generation_log`. A frozen week is overwritten only while every raw row of it is still there, so the week straddling the cutoff keeps its full figure. `plan_generation_log` has no user id, so it is swept but never counted per athlete.

**Why.** The log has to answer mp-420's question honestly: how much of a turn's prompt came from the cache, and what it really cost us. Pricing tokens belongs to the monthly budget (mp-436, ticket 09); two price tables would be two answers.

**What else was considered.** One whole-turn cache ratio. One row per model step. A price table in the log. A rollup that re-rolls every week each night (it shrank the straddling week by a day a night).

**What it touches.** `vana_calls`, `ai_usage`, the views `vana_call_facts` and `vana_weekly_cost`, `vana_weekly_rollup`, `ai_log_retention_sweep`, chat.ts, log.ts, describe-meal, analyze-meal-photo, `docs/database/ai-cost-log-and-weekly-view.md`.

**Details.** Dev, one conversation, two turns: turn 1 cold, 10,436 cache-write tokens, $0.013358; turn 2 warm, 10,436 cache-read tokens, $0.0012916. The five figures: cost per athlete by plan, first-step cache hit rate, cost per confirmed plan, spend in planning conversations that never added a meal, share of athlete turns that were taps. Sweep at 03:41 UTC; a row exactly 90.0 days old is kept.

> 2026-09-22 proposed from wave 3 of ai-cost

## mp-522 · Calls the gateway never prices: does the budget's price table fill the gap?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-521
- source: wave ai-cost 3 ticket 05

**Context.** mp-521 counts cost as the gateway's own charge and shows `costed_calls` beside `calls` where it is missing. mp-436 gives the monthly budget a price table for the same case: tokens priced from one table when the gateway reports none. Ticket 09 builds that table.

**Question.** Should ticket 09's price table also back-fill `gateway_cost_usd` for calls the gateway stayed quiet about, so the weekly figures are whole, or does `costed_calls` beside `calls` stay the whole answer?

**Why.** It decides whether Lee reads one cost number or a number with a coverage figure next to it, and whether the log and the wallet can ever disagree.

**What it touches.** log.ts, the weekly view, ticket 09's price table.

> 2026-09-22 opened from wave 3 of ai-cost

## mp-523 · The daily cost alert: one Sentry event per account per day, from a cron job
- category: Cutting costs
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-523.svg
- screen: none (algorithm/data)
- source: wave ai-cost 3 ticket 05
- linked: mp-470

**Context.** Ticket 05 asks that an account costing more than $1.50 in a day be reported to Sentry the same day, refusing nothing. Nothing in the record said how the report travels or how often the same athlete is reported.

**Question.** How is an expensive day reported, and how often for the same account?

**Decision.** 
1. A `pg_cron` job at 06:23 UTC reads yesterday's spend per account from the call log and posts the accounts over the threshold, through `pg_net`, to a small edge function that reports each to Sentry. The path is the one the raw-retention alert already uses; the function address and token come from Vault, never from the migration.
2. One Sentry event per account per day, fingerprinted on account and day. A week of the same athlete running hot is a week of issues, because each day's number is its own decision.
3. The threshold, $1.50, is a default in SQL. Changing it is editing the cron command.
4. Nothing on the athlete's request path reads the check. Absent secrets, the check still runs and raises a notice.

**Why.** Sentry is where Lee already looks; a per-day fingerprint keeps a runaway account visible each day without one issue swallowing a week.

**What else was considered.** One issue per account that re-opens. The threshold in `app_config` or the content system.

**What it touches.** `vana_daily_cost_offenders`, `vana_daily_cost_alert`, the `ai-cost-alert` function, `supabase/config.toml`, dev secrets `AI_COST_ALERT_TOKEN` and the Vault entries.

**Details.** Run end to end on dev: SQL to pg_net to the deployed function, `{"success":true,"reported":1}`, HTTP 200; a wrong token gets 401. Prod has none of the secrets and nothing was deployed there.

> 2026-09-22 proposed from wave 3 of ai-cost

## mp-524 · The playbook says no cron job calls an edge function; two landed alerts do
- category: Data, sync and backend
- kind: question
- status: open
- linked: mp-523
- source: wave ai-cost 3 ticket 05

**Context.** `docs/deployment/supabase-deploy-playbook.md` §5 says no cron job, trigger or stored procedure calls an edge function, by policy, because they get lost. The raw-retention alert landed 2026-09-20 that way, and mp-523 follows it: `pg_cron` to `pg_net` to a function with a Vault token. The wave's standards review flagged the conflict.

**Question.** Is the playbook line amended to allow the alert shape (a cron job posting to a function whose address and token live in Vault), or do both alerts move to something else, such as a scheduled function or a Sentry cron monitor?

**Why.** Two live jobs now contradict a written rule. Either the rule or the jobs has to give, before production gets either.

**What it touches.** The playbook, the two alert migrations, the two alert functions.

> 2026-09-22 opened from wave 3 of ai-cost

## mp-525 · How a meal analysis is asked, answered and sized
- category: Cutting costs
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-525.svg
- screen: none (the log-meal screen has no registry key; one warning line changed)
- source: wave ai-cost 3 ticket 08
- linked: mp-473

**Context.** Ticket 08 asks the described meal and the meal photo for a cacheable prompt, totals we add up, a "not food" answer and photos at 1,000 px on the long edge. The ticket said what, not how the prompt is shaped, how not-food reaches the app, or where the photo is resized.

**Question.** How are the two meal-logging calls shaped, and what does the app get back?

**Decision.** 
1. The fixed instructions go in the SDK's system slot with a one-hour cache marker; the athlete's text or photo is the only user message. Two different meals send byte-identical instructions.
2. The model is asked not to compute totals. Its `totals` field stays optional and is ignored; the function sums the items.
3. Not food is a code, `not_food`, at the same 422 status the functions already used, never prose from the server. The app's one line comes from the content system and shows as a warning, not an error. An older installed build shows its own line.
4. A missing `suggested_slot` or `confidence` gets a default (snack, medium) rather than a 500.
5. Photos are capped at 1,000 px on both axes at the picker, one shared constant, so portrait and landscape cost the same. The two Vana pickers (attach sheet, fridge photo) had the same width-only cap and got the same fix.
6. Both models stay Sonnet.

**Why.** The system slot is where the provider puts the cache breakpoint anyway, and the SDK warns against system text inside messages. Resizing at the picker avoids re-encoding bytes on the main isolate and any EXIF-orientation regression.

**What else was considered.** A first system entry in `messages`. Dropping `totals` from the schema. A 200 with a not-food flag in the body. A `package:image` guard in the upload service.

**What it touches.** describe-meal, analyze-meal-photo, `_shared/meal_analysis/{prompt,finalize,schema}.ts`, `meal_ai_service.dart`, `meal_photo_capture.dart`, the log-meal, edit-meal, photo-capture and Vana pickers, content key `meal_planning.analysis_not_food`.

**Details.** Dev, Sonnet 4.6, one synthetic scene: landscape 1000×750 = 2,368 input tokens, portrait 750×1000 = 2,368 (0% apart); the old width-only cap sent portrait at 1000×1333 = 2,960, 25% more. Both functions answered 422 `not_food` live.

> 2026-09-22 proposed from wave 3 of ai-cost

## mp-526 · Does a photo that is not food draw the athlete's budget?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-525
- source: wave ai-cost 3 ticket 08

**Context.** mp-525 clause 3 gives a not-food photo one short answer and no macros. The model turn still ran and cost us a Sonnet call, so the build kept the log row and the debit. Nothing rules on it.

**Question.** Should "that isn't food" cost the athlete a call from the monthly budget, or be free to them and carried by us?

**Why.** Charging for a refusal may read badly; not charging invites the loop the budget exists to stop.

**What it touches.** describe-meal, analyze-meal-photo, the wallet debit.

> 2026-09-22 opened from wave 3 of ai-cost

## mp-527 · The meal-logging cache marker is inert until the instructions reach the cache minimum
- category: Cutting costs
- kind: question
- status: open
- linked: mp-525
- source: wave ai-cost 3 ticket 08

**Context.** mp-525 puts a one-hour cache marker on each function's instructions. Each block is about 600 tokens, under Anthropic's minimum cacheable prefix of about 1,024, so `cache_read_tokens` came back null on every dev call. The shape is right and the marker costs nothing; the saving in this ticket is the photo downscale.

**Question.** Grow the instructions past the minimum on purpose (a fixed rubric or worked examples) so the marker starts saving, or accept the shape and leave the saving to the downscale?

**Why.** A deliberate 400-token pad costs more on a cache miss than it saves on a hit unless most calls hit; the numbers should be measured before it is done.

**What it touches.** `_shared/meal_analysis/prompt.ts`.

> 2026-09-22 opened from wave 3 of ai-cost

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

**Context.** The grace selection includes every registered account created before the flip. On prod that includes the team's own test and demo accounts.

**Question.** Should they be excluded from the prod run, and if so, by what rule?

**Why.** They would carry `founding_member` and a 30-day grant into the numbers.

**What it touches.** `_shared/grace` selection.

> 2026-09-22 opened in wave 2 ticket 06
> 2026-09-22 answered by mp-542

## mp-534 · The prod webhook hears only purchases and renewals
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-454
- image: none
- caption:
- screen: none (RevenueCat configuration)
- source: wave paywall 2 ticket 06

**Context.** While changing the dev integration, the wave read both integrations. The prod one takes three event types: initial purchase, renewal and non-renewing purchase. The webhook's own header says a cache that only hears purchases and renewals never closes a row. On dev it takes all eleven.

**Question.** Should the prod integration take every event type before the prod cutover, in ticket 05 or before it?

**Why.** Without cancellation and expiration events, prod's entitlement rows stay open after access ends.

**What it touches.** RevenueCat integration `whintgraa6c9e50e5` (prod), ticket 05.

> 2026-09-22 opened in wave 2 ticket 06
> 2026-09-22 answered by mp-543

## mp-536 · Should a giveaway code leave a mark for reporting?
- category: Pro and paywall
- kind: question
- status: answered
- linked: mp-458
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave paywall 2 ticket 07

**Context.** Coach and influencer codes set a subscriber attribute (`coach_code`, `influencer_code`), so RevenueCat and the webhook pipeline can tell where an athlete came from. A giveaway grants 365 days and sets nothing.

**Question.** Should a giveaway also set an attribute, for example `giveaway_code`?

**Why.** Without it, a giveaway winner cannot be told apart from any other promotional grant in the reports.

**What it touches.** `redeem-code`.

> 2026-09-22 opened in wave 2 ticket 07
> 2026-09-22 answered by mp-544

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
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: wave ai-cost 4 ticket 06

**Context.** A hand-off used to take two model steps: the tool call, then a second step for the closing sentence. Ticket 06 ends the turn the moment Vana asks a choice, hands off, or saves feedback silently, so nothing runs after the call. The persona and the tool's description now tell Vana to say its one sentence first and call handOff after it.

**Question.** When Vana hands the athlete off to a screen, where does its one sentence go?

**Decision.** Vana writes its one sentence, then calls the hand-off, and the turn ends there. Nothing is said after the call.

**Why.** The call ends the turn; a sentence after it would never be written, and a second step to write it is what the ticket removes.

**What else was considered.** Keeping a second step for the sentence after the hand-off; rejected, it is the cost the ticket cuts.

**What it touches.** Vana chat, the persona and the handOff tool description on the server.

> 2026-09-22 proposed in wave 4 ticket 06
> 2026-09-22 picture captured at 1.27.0+3, b7682f1b

## mp-547 · A complaint that asks a question still gets an answer
- category: Vana's voice and openers
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: wave ai-cost 4 ticket 06

**Context.** Saving feedback ends the turn now, so a complaint costs one model step. The feedback tool already knows whether it should stay silent (a plain complaint) or answer (a complaint with a question in it).

**Question.** When the athlete's message is both a complaint and a question, does Vana answer?

**Decision.** The turn ends on saved feedback only when the feedback was the silent kind. A complaint with a question in it keeps the step that answers it.

**Why.** The spec ends the turn when Vana "saves feedback silently"; a question left unanswered would read as Vana ignoring the athlete.

**What else was considered.** Ending every turn on saved feedback; rejected, it would drop the answer.

**What it touches.** Vana chat, the stop rule in the chat module.

> 2026-09-22 proposed in wave 4 ticket 06
> 2026-09-22 picture captured at 1.27.0+3, b7682f1b

## mp-548 · Which token figure marks the picker win: per call or per step?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-471
- image: none
- caption:
- screen: none (algorithm/data)
- source: wave ai-cost 4 ticket 06

**Context.** Ticket 06 expected the fourth planning turn to fall from about 72k input tokens to under 35k. On dev it went from 91,026 to 49,662 for the whole call, and per model step from 45k to 16k; the after turn ran three steps (a setting, the picker, the sentence), which the 35k target did not assume. The whole six-call conversation went from 393k to 164k tokens, $0.227 to $0.098.

**Question.** Is the figure to track the input per call, or the input per model step? The per-call number missed the 35k target; the per-step number beat it.

**Why.** The number decides whether the picker work is done or whether ticket 07's cache work has to carry the rest.

**What it touches.** The ticket's measurement, the cost log, ticket 07.

> 2026-09-22 opened in wave 4 ticket 06

## mp-549 · What a call takes from the wallet, and what comes back
- category: Cutting costs
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-549.svg
- screen: none (algorithm/data)
- source: wave ai-cost 4 ticket 09

**Context.** The wallet now holds whole micro-dollars. A call reserves an estimate for its kind before the model runs, in the one statement that also reads the balance under the wallet's row lock; when it finishes the reservation becomes the real cost. mp-436 says a call that starts inside the budget finishes, and that the app is never sent dollars. Four rules at the edges were not written down.

**Question.** At the edges of the budget, what does a call take and what does it give back?

**Decision.** 
1. Only an empty wallet refuses a call. A call whose estimate is more than what is left takes what is left and runs; the next call gets the top-up sheet.
2. A call that costs more than it reserved takes the difference, and the wallet stops at zero. The shortfall is absorbed: it is never carried into next month and never taken from a later pack.
3. What comes back from a call that cost less than it reserved goes to the bought budget first; the monthly budget gets its share back only while the same month's window is still open.
4. A call that ran but reported no usage is charged its estimate, never nothing.

**Why.** Clause 1 is mp-436 clause 1 applied at the reservation; the first build refused on the estimate, the alternative mp-436 rejected, and the review corrected it. Clauses 2 and 3 keep the monthly budget spent first (mp-430 clause 5) in both directions. Clause 4 stops an unpriced call from being free.

**What else was considered.** Refusing a call whose estimate does not fit (rejected by mp-436); a negative balance that a later pack would first pay off (rejected, it would eat bought budget); refunding the monthly part first (rejected, the monthly part is what the call spent).

**What it touches.** The wallet SQL (reserve, settle, the hourly release of what nothing settled), every debiting function.

**Details.** Estimates per kind are one setting each on the server. Real cost is the gateway's own charge, else the logged tokens priced from one table; a cache write is priced at the one-hour rate when the SDK does not say which it was. A reservation nothing settled within two hours is given back in full.

> 2026-09-22 proposed in wave 4 ticket 09

## mp-550 · When the wallet cannot answer, Vana is unavailable, not out of budget
- category: Cutting costs
- status: proposed
- image: docs/ssot/decisions/images/mealplanning/vana-chat.png
- caption:
- screen: Vana chat
- source: wave ai-cost 4 ticket 09

**Context.** Every debiting call asks the database for a reservation before the model runs. The old code let the call through when that ask failed. mp-437 says a fault of ours shows "Vana is unavailable right now", never the top-up sheet.

**Question.** What does the athlete see when the wallet itself cannot be read?

**Decision.** A database error at the reservation refuses the call as "Vana is unavailable right now". The top-up sheet never shows for a fault of ours, and no call runs unmetered.

**Why.** Letting the call through would run the model for free and hide the fault; blaming the athlete's budget would be wrong.

**What else was considered.** Failing open, as before (rejected: unmetered calls); the 402 top-up response (rejected: it blames the wallet).

**What it touches.** Vana chat, the described meal, the meal photo, the pantry photo, the openers; the shared credits module.

> 2026-09-22 proposed in wave 4 ticket 09
> 2026-09-22 picture captured at 1.27.0+3, b7682f1b

## mp-551 · Bought extra is a share of a month, and no month means no share
- category: Cutting costs
- status: proposed
- image: none
- caption:
- svg: docs/ssot/decisions/images/mealplanning/mp-551.svg
- screen: none (server response, drawn by ticket 10)
- source: wave ai-cost 4 ticket 09

**Context.** mp-436 clause 3 sends the app a share of the month used, a refill date and any bought extra, never a dollar figure. The unit of "bought extra" and the answer for an account with no open month were not fixed. The Vana settings bar (ticket 10) reads this answer.

**Question.** In what unit is bought extra sent, and what does an account with no open month get?

**Decision.** 
1. Bought extra is sent as a share of one month's budget: the $4.99 pack is a quarter, the $19.99 pack a month and a quarter.
2. An account with no open month (a lapsed subscription, the free grant after the paywall opens) gets no share and no refill date, so the bar has nothing to draw, rather than reading as a full month used.
3. The refill date is also sent under the name today's sheet already reads, so the sheet's renewal line keeps working until ticket 10.

**Why.** One unit for everything the athlete sees keeps dollars out of the app; a lapsed account showing a full bar with no date was found on the dev check and is wrong.

**What else was considered.** Sending bought extra in credits (rejected, credits are gone); a full bar for a closed month (rejected, misleading).

**What it touches.** The 402 body, the credits endpoint, the Vana settings bar (ticket 10).

> 2026-09-22 proposed in wave 4 ticket 09

## mp-552 · Does a sandbox purchase on production grant a real budget?
- category: Cutting costs
- kind: question
- status: open
- linked: mp-474
- image: none
- caption:
- screen: none (the RevenueCat webhook)
- source: wave ai-cost 4 ticket 09

**Context.** The production webhook takes every environment by ruling, and testers get in on a production release by a free TestFlight subscription, which is a sandbox event (mp-431). A sandbox pack purchase on production would then add real budget for free. Nothing in the webhook grants differently by the event's environment; what dev does with production events is a separate, rejected card (mp-533) and not this question.

**Question.** Should a sandbox event on production grant the same budget as a real one? Three options: sandbox events grant a smaller tester budget; sandbox subscriptions grant the month but sandbox pack purchases grant nothing; accept it, since the testers are ours.

**Why.** It decides whether a tester can top up for free on the store build, and whether testers get the same month everyone else gets.

**What it touches.** The RevenueCat webhook, the wallet grants, TestFlight testers.

> 2026-09-22 opened in wave 4 ticket 09

# Mealvana Endurance

Personalized endurance nutrition planning: training-aware fuelling formulas, meal plans, and the
shopping that follows from them. This file is a glossary and nothing else — it fixes the words the
codebase and its agents use, so that two things which are not the same never share a name.

## Language

### Retailer shopping

**Location**:
A Kroger facility identified by a `locationId`, required on every catalog request because price,
stock, and fulfillment eligibility are all per-facility. A Location is not necessarily a shop.
_Avoid_: Store (unless the facility is genuinely one)

**Spoke**:
A Location that fulfils delivery only. It has no departments, no aisles, nobody walks in, and it
returns **no prices**. A market can have a Spoke and no Store — Birmingham, Alabama does.
_Avoid_: Warehouse, fulfillment center, dark store

**Store**:
A Location a shopper can physically enter. Only a Store supports pickup, and only a Store returns
prices. Never use this word for a Location whose type is unknown.

**Modality**:
Whether the shopper is collecting the order themselves or having it delivered — `PICKUP` or
`DELIVERY`. It is the shopper's intent, and it determines which Location can serve them; it is
never a property of the Location they were handed.
_Avoid_: Fulfillment type, delivery method, shipping option

**Checkout hand-off**:
The end of Mealvana's involvement in an order: the shopper leaves for Kroger's own checkout to
choose a slot and pay. Mealvana never places an order, sees an order, or knows whether one
happened, and never handles payment.
_Avoid_: Checkout, purchase, order placement, Hand-off on its own (that is Vana's button)

**Delivery area**:
Where the shopper wants their groceries delivered, as a postcode. It is the only thing about a
shopper's whereabouts this feature shows, sends, or holds, and it is never stored: Kroger's
acceptable-use terms for the Locations API forbid keeping data about a customer's location. The
Location it resolves to is persisted; the area itself is asked for again.
_Avoid_: Address, store area, zone

**Coverage**:
Whether any Location can serve a given area at a given Modality. Answerable without a shopper
account, and therefore knowable before anything is asked of them.

**Match**:
A proposed correspondence between one line of a Mealvana shopping list and one real retailer
product. A Match is a suggestion until the shopper approves it.
_Avoid_: Mapping, link, resolution

### The meal library

**Meal**:
The umbrella term for anything in the meal library a person can eat at a sitting. Every Meal is
either a Recipe or an Assembly; there is no third kind. One row of `meal_library`.

**Recipe**:
A Meal with method steps — it is cooked, and the cooking changes what the ingredients look like.
_Avoid_: Dish (that is the photographed subject, not the Meal)

**Assembly**:
A Meal with no method steps: ingredients put together rather than cooked. Its components stay
visually themselves in the bowl. Described by a pattern and a frequency rather than by steps.
_Avoid_: Combo, no-cook meal, snack

**Meal review**:
An Admin's verdict on one Meal, Good recipe or Not good with a reason, sent from the meal page to a table only Admins can read. Athletes never see it.
_Avoid_: comment, team review, recipe comment

### Meal imagery

**Dish photo**:
A photograph of the finished Meal itself, reached by one image address that points either at our
storage or at the web. A Meal has one Dish photo or none, and nothing stands in for a missing one.
Where a photo came from makes no difference to how it is shown. It may carry one credit line,
shown under it only when present.
_Avoid_: Hero, thumbnail (those are placements, not kinds of image); Kitchen photo, Stock photo
(there are no kinds of Dish photo)

**Tester**:
An account that has turned on "Mark this device as internal", reached by tapping the version in
Settings seven times. Anyone who finds the gesture can become one; nothing else is required.
_Avoid_: Admin, developer (a Tester holds no role granted by us)

**Tile**:
A photograph of a single ingredient, held in `ingredient_images` and keyed by slug, reusable
across every Meal that contains that ingredient. A Tile depicts an ingredient and never a Meal, so
a Tile is never shown as a Meal's picture.

**Mosaic**:
Two to four Tiles composed into one frame at render time to stand in for a Meal that has no Dish
photo. A Mosaic is a substitute, never a preference: where a Dish photo exists it wins. Composed
client-side in Flutter, never pre-rendered. Mosaics are kept but not shown to athletes until a
Mosaic good enough to stand in for a Meal exists.

**Image mode**:
Which of the above a Meal's picture is — `dish`, `mosaic`, `tile`, or `none`. It records what the
Meal would fall back to, so the size of the substitute population is always countable. Only
`dish` is shown; every other mode shows no picture.

**Separable / Transformed**:
Whether a Meal's named components stay individually recognisable in the finished food. A
Separable Meal may wear a Mosaic; a Transformed one — blended, baked, churned, stewed — may not,
because its parts no longer look like themselves. Cuts across Recipe and Assembly: a smoothie is
an Assembly and is Transformed, a grain bowl may be a Recipe and stays Separable.

**Verdict**:
Whether the picture a Meal is showing represents that Meal — `ok`, `weak`, or `wrong` — judged
against the composed image the athlete actually sees, not against each Tile. Honesty is counted
from Verdicts; coverage is not a measure of anything.
_Avoid_: Score, rating (those are the text ranking, which decides nothing)

**Judge**:
The model call that reached a Verdict, used only by the frozen image pipeline. A photo a Tester
adds never goes through the Judge.

### Vana and what she knows

**Hand-off**:
A button in Vana's reply that opens the app screen made for what the athlete asked, instead of
Vana doing it in the sheet: a meal plan opens the meal-planning page, fuelling a workout opens new
activity, planning an event opens the event screen (mp-305).
_Avoid_: Redirect, deep link; Checkout hand-off is the Kroger exit

**Vana**:
The single assistant persona in the app. Whatever the person asks — planning meals, a question
about tomorrow's ride, a complaint — it is one Vana who answers, choosing an Intent rather than
handing off to a different character.
_Avoid_: Jade (the retired name), the bot, the agent

**Intent**:
What a person wants from Vana in a given exchange: planning a week, answering a question,
passing feedback to the team, and others as they are named. Intent is recognised per exchange,
never fixed per conversation.
_Avoid_: Mode (that is a transport detail), kind

**Voodoo Doll**:
Everything Vana knows about one person, compiled into a single document at the moment she needs
it. It is assembled from the canonical records, never stored as a second copy of them. It has
two parts — Facts and Memories — and is read alongside the Situation.
_Avoid_: Profile, user context, dossier

**Fact**:
Something the app records about a person in the ordinary course of use: name, diet, allergies,
where they live, the training schedule, what they logged. A Fact has an owner elsewhere in the
app; the Doll only reads it.
_Avoid_: Memory (a Fact is never learned in conversation)

**Memory**:
One sentence a good dietitian would write in the margin of a person's file after talking to them:
something that changes how Vana plans for them next time, and nothing else. It comes from the
person saying it, from a debrief, or from Vana reading a finished conversation. Every Memory
carries its source and date; the person can see and delete any of them as one flat list. A keyed
Memory (batch cooking, coverage scope, budget) is a choice Vana honours without asking again.
_Avoid_: Preference, note, decision, summary, meal feedback (a thumbs vote is a Fact)

**Episode**:
One sentence saying what a single conversation established, written when Vana reads it back.
It is not a Memory and never competes with one for space: Vana reads the newest few episodes on
their own, so she can pick up where the last conversation left off.
_Avoid_: Summary (that is only the conversation list's preview of it), transcript

**Opener**:
Vana's first turn in a conversation she starts: the day's first sheet, a new plan, a check-in, a
debrief, or a moment. Every opener carries one thing only this person has told her (an episode, a
Memory, a meal they voted on, a goal), said the way a dietitian who remembers them would, never
read out. When nothing she knows bears on the moment, she leaves it out rather than stretch.
_Avoid_: Greeting (an opener never greets)


**Meal feedback**:
A thumbs vote the person gives one Meal on its detail page. It is a Fact about that Meal and that
person, kept in its own record, and Vana reads it every turn as what they liked and did not.
Anything the person tells Vana about food in words ("no cilantro", "not Thai again") is a
Memory, not Meal feedback. Fuelling-product tolerances are a separate, older record.
_Avoid_: Meal preference, like, rating

**Situation**:
What the person is looking at and doing when they speak to Vana: the screen, the entity in view,
the date. It travels with each message and is never stored.
_Avoid_: Context (overloaded), screen state

**Tool**:
A server function Vana calls during a turn to read the athlete's records or to put something in the chat, such as the upcoming events, the day-guidance tool, a meal picker or a choice question. Each call is one tool step.
_Avoid_: function call

**Turn**:
One reply from Vana and everything she does to make it: the reading, tool calls and writing behind one answer to the athlete, or behind an opener she sends first.

**Meal picker**:
The carousel of meals Vana puts in the chat for the athlete to choose from.
_Avoid_: carousel, meal cards

**Choice question**:
A question Vana asks with tappable chips as the answers. It is itself a tool, so it arrives as its own part of the message.
_Avoid_: quick replies

**Transcript**:
The stored copy of a conversation, which is what the athlete sees when they reopen it, as opposed to the live stream they watched.
_Avoid_: chat log

**Launcher**:
The Vana button on the three screens that have one: the main tabs, the meal-planning screen and coach formulas. Tapping it opens the Vana sheet on the day's conversation.
_Avoid_: Launcher sheet (that is the sheet it opens)

**Context block**:
The part of Vana's prompt that the server writes about the person and the moment: the Voodoo Doll digest plus the Situation's section. It says what exists; detail comes from tools.
_Avoid_: Context (unqualified), user context

**Remember tool**:
The tool Vana calls to save a Memory during a conversation, whether the athlete asked her to or she judged it worth keeping. The server decides whether the sentence is new or refreshes a Memory it already holds.
_Avoid_: remember (unqualified)

**Extraction**:
Vana reading a finished conversation in the background to write its Episode and any Memories nobody asked her to keep. It never shows in the chat.
_Avoid_: Extractor, background extraction

**Debrief**:
The check-in Vana opens after a plan week ends, asking how the week went. Recording it writes a debrief row and one to three Memories marked as from the debrief; it is the only writer that learns from what the athlete did.

**Vana sheet**:
The panel that rises over the current screen when the Launcher is tapped, holding a conversation with Vana. Closing it leaves the screen underneath as it was.
_Avoid_: The sheet (unqualified; the Top-up sheet is another), overlay, drawer

**Full-screen chat**:
Vana's conversation as a whole screen of its own rather than the Vana sheet. Opened from the sheet's full-screen button, it shows the same conversation, only bigger.
_Avoid_: Chat route, expanded sheet

**Route**:
The name of the screen the app is showing, such as meal detail or Settings. Every Situation carries one; Vana's own sheet and chat never report theirs.
_Avoid_: Page, path

**Moment**:
Vana speaking first: the launcher rings, a pill asks a question, and tapping it opens the sheet on her already talking. Only the pre-workout and recovery windows raise one.
_Avoid_: Nudge, notification, prompt

**Pill**:
The short question that shows beside the tab bar for a few seconds when a moment rings, such as "Fuel tonight's run?". Tapping it opens the sheet on that moment.
_Avoid_: Banner, toast, bubble

**Fuelling window**:
The pre-workout window before a planned workout or the recovery window after a finished session: the stretch of time in which a moment can raise. The pre-workout window's length comes from the fuelling window authority.
_Avoid_: Fueling window, meal window

**Prompt cache**:
The model provider's short-lived copy of the opening part of a prompt it has just seen. A later call that starts with exactly the same text reads that part back at a tenth of the price; anything that changes breaks the cache from that point on.
_Avoid_: Cache (unqualified), memory

**LIKES line**:
The line of the Context block that lists the Meals the athlete voted thumbs up or down, read from Meal feedback every time the block is built.
_Avoid_: likes, meal preferences

**LAST TALKS line**:
The line of the Context block that carries what the athlete said in recent conversations, so Vana can pick up where they left off.
_Avoid_: previous conversations, read-back

**Show more**:
The chip under a Meal picker that opens a sheet with the rest of the same search, so the athlete can see more meals without a new search.
_Avoid_: tail, More sheet

**Fuelling window authority**:
The one place in the app that decides how long a workout's pre-workout window is: the workout's own stored minutes, or a default from its duration and intensity.
_Avoid_: Window authority, fueling_window_authority

**Step**:
One call to the model inside a Turn. A turn that calls tools runs several steps; tokens and cache reads are counted per step.
_Avoid_: model step, tool step (unqualified)

### Paying for the app

**Gate**:
The one check that decides whether an account may use the app. It answers yes for an account that
holds Pro. In the app, and only there, it also opens for an Admin, who skips the paywall screen
(mp-416); the server lets in Pro alone, so a Tester or an Admin without a TestFlight subscription
or a Grant is still refused by Vana (mp-318, mp-335). There is one Gate for the whole app; no
feature has its own.
_Avoid_: Pro gate, Vana gate, feature lock

**Pro**:
What an account holds when it may use the app: a trial, a paid subscription or a Grant. The app
has no free tier, so an account either holds Pro or is Lapsed.
_Avoid_: Premium, Pro tier, paid tier

**Lapsed**:
An account that does not hold Pro. It stays signed in and meets the full-screen paywall, the same
one a new account sees, until it subscribes, restores a purchase or redeems a Code. Everything it
made is kept and is all there again when Pro is back (mp-280).
_Avoid_: Expired, free user, locked out

**Grant**:
Pro given for a fixed time without a purchase, by us, through the subscription provider. Coach
comps, giveaways and Legacy grace are all Grants.
_Avoid_: Comp, promo, free access

**pro**:
The one entitlement id in RevenueCat, the subscription provider. Every way of holding Pro, a trial,
a paid subscription or a Grant, shows up as `pro` being live for the customer, with one Expiry.
_Avoid_: Pro (that is the product), entitlement (unqualified)

**Expiry**:
The date and time RevenueCat says `pro` stops being live for a customer: the later of every
subscription and Grant they hold. The server copies it onto the Entitlement row as "active until".
_Avoid_: Expiration date, active until (that is the column, not the fact)

**Entitlement row**:
The server's copy of RevenueCat's answer for one account: active until, period type and the time
of the last event. Only the webhook writes it; the Gate reads it.
_Avoid_: Entitlements table row, cache row

**Trial**:
The free first week of a subscription, started at the store. A Trial holds Pro. When it lapses the
account is Lapsed unless a Grant still runs.
_Avoid_: Free trial, trial period

**Legacy grace**:
The thirty-day Grant every account that existed before the paywall receives on the day it opens.
_Avoid_: Grace period (the store's billing retry is a different thing)

**Founding Month**:
October 1 to November 30, when everyone is offered the founding price. A subscription started in it
keeps that price for as long as it renews.
_Avoid_: Launch discount, promo window

**Code**:
A word we issue to a coach, an influencer or a giveaway winner. Entering it records who referred
the account, may pair an athlete with a coach, and may set a price or a Grant. The stores' own
offer codes are never used.
_Avoid_: Promo code, offer code, referral link

**Tester**:
An account that turned on the seven-tap switch in Settings. It sees test items, and that is all the
switch does: to get past the Gate a Tester subscribes in TestFlight, which charges nothing
(mp-318). Anyone can become one.
_Avoid_: Internal user, beta user

**Admin**:
A team account marked by hand in the database. It may review meals, and the Gate in the app lets it
past the paywall screen; the server still needs a TestFlight subscription or a Grant before Vana
answers it (mp-416).
_Avoid_: Staff, superuser

**Top-up**:
Budget bought on its own, in a pack: $1.00 of budget for $4.99 or $5.00 for $19.99 (mp-430). It is
spent only once the Monthly budget is empty, never expires and is never forfeited, whatever happens
to the subscription (mp-281).
_Avoid_: Bundle, pack (that is the store product, not the credits)

**Paywall**:
The screen that offers the plans. An account the Gate does not let in is sent there.
_Avoid_: Pro screen, lock screen

**Webhook**:
The server function RevenueCat calls whenever something happens to a customer's subscription. It is the only thing that writes the Entitlement row.
_Avoid_: callback

**Restore purchases**:
The paywall action that asks the store for purchases this person already made, and lets them back in if one is still live.
_Avoid_: Restore (unqualified), re-sync

**TestFlight**:
Apple's way of giving test builds to the team before release. A subscription bought in a TestFlight build is a test purchase and charges nothing.
_Avoid_: beta build

**Monthly budget**:
What a subscription puts in the wallet each month, measured in what AI calls actually cost us: $4.00, the same for every plan, a quarter of it in the trial week. The athlete sees only the share used and the refill date.
_Avoid_: Allowance (its name when it was counted in credits), credits, tokens, quota

**Wallet**:
The one place an account's AI spending comes from: the monthly budget, spent first, and any bought Top-ups. Every AI call draws from it.
_Avoid_: Balance, credits account

**Top-up sheet**:
The sheet that opens when an AI action finds the wallet empty: the share of the month used, the renewal date and the two packs. It never appears for an outage of ours.
_Avoid_: Credits paywall, out-of-credits screen

**Flip**:
The moment Lee switches the paywall on. Accounts created before it get Legacy grace.
_Avoid_: Launch, go-live, 1 October (the flip is not a fixed date)

**Offering**:
A set of plans RevenueCat holds for the paywall to sell. There are two, the regular `default` and the Founding Month's `founding`, and the paywall sells whichever one is marked current.
_Avoid_: Current Offering, price list

**Onboarding paywall**:
The one paywall every account without Pro sees, whether it never subscribed or its Pro ran out: full screen, with no way to close it (mp-457).
_Avoid_: Onboarding shape, signup paywall, Paywall sheet (retired: there is no sheet over a read-only app)

**⋯ menu**:
The one button in the paywall's top corner that holds everything secondary: Restore purchases, Redeem code, Manage subscription, Sign out and Delete account.
_Avoid_: Overflow menu, more menu

**Call log**:
The server's record of every AI call: who made it, the tokens it read, wrote and cached, and what the gateway charged for it. What each athlete costs is read from it.
_Avoid_: Usage log, ai_usage (that is one of its tables)

**Gateway**:
The Vercel AI Gateway, the one service every AI call goes through to reach a model. It adds no markup and reports its own charge for each call, which is what that call really cost us.
_Avoid_: Provider, proxy

**Token**:
The piece of text a model reads and writes in, a word or part of one. A model call is priced by the tokens it reads and writes; the monthly budget is counted in dollars, never in tokens.
_Avoid_: Credit (that was the old wallet unit)

**Sandbox**:
The stores' test mode, where a test account buys a subscription without being charged. The hand runs before a release buy in it; a Grant made there still reaches the webhook labelled as production.
_Avoid_: staging

**Test Store**:
RevenueCat's own pretend store. The dev app's debug build on a simulator buys through it, so no Apple or Google record exists for those purchases.
_Avoid_: Sandbox (that is Apple's and Google's test mode)

**Live connection**:
The feed over which the server pushes the account's wallet row to the phone whenever it changes. It is open only while a screen that shows the budget is showing.
_Avoid_: Wallet channel, realtime subscription

**Usage bar**:
The bar in Vana settings that shows the share of this month's budget used, the refill date and any bought extra, as percentages and a date, never dollars.
_Avoid_: Budget bar, credits bar

**Bought extra**:
What is left of the budget bought in Top-ups, shown to the athlete as a share of one month's budget: the $4.99 pack adds a quarter of a month, the $19.99 pack a month and a quarter.
_Avoid_: Pack credits, bought credits

**Grace run**:
The script Lee runs at the flip that gives Legacy grace to every registered account created before it. An install still anonymous at the flip gets its month through a Grace claim instead.
_Avoid_: flip-day run, grace selection, grace script

**Grace claim**:
The one request an install still anonymous at the flip makes right after sign-up to get its Legacy grace. It is made once and not retried.
_Avoid_: claim (unqualified), grace-claim

**Subscription screen**:
The screen opened from the first row of Settings that shows where the plan stands and what Pro includes, with Upgrade, Manage subscription and Redeem code (mp-495).
_Avoid_: Plan screen, Pro screen

**Micro-dollar**:
A millionth of a dollar, the unit the wallet row counts in. The athlete never sees it; the phone turns it into shares of a month.
_Avoid_: micros

### Planning meals

**Draft**:
The meal plan being built in a planning conversation, before it is confirmed. Ticked meals go into it, the plan bar shows it, and it becomes the athlete's plan only at Confirm.
_Avoid_: Draft plan; active week plan (that is the confirmed plan on the phone)

**Batch cooking**:
Cooking a few meals at one sitting, a cooking session, and eating them across the plan's period. It is a setting Vana asks about once and Settings can change; when it is off, each meal is made the night it is eaten.
_Avoid_: Meal prep

**Staples**:
Foods an athlete eats again and again, such as breakfast and snacks. They are suggested from the athlete's own logs and enter a plan only when the athlete ticks them.

**Plan meal**:
One meal in a plan: which library Meal, its meal type and how many servings are left. The Plan tab shows each plan meal as one row.
_Avoid_: Plan tile (a Tile is an ingredient photo)

**Meal type**:
Which part of the day a meal is for, such as breakfast, lunch, dinner or a snack. An athlete plans only the meal types they choose.
_Avoid_: Slot

**Plan period**:
The span one plan feeds: a start day and a number of days, both set by the athlete, Sunday and seven days by default.
_Avoid_: Week (unless it is seven days), cooking period

**Plan coverage**:
How many of the period's meals a plan's servings fill, counted against the period's days times the meal types the athlete plans.
_Avoid_: Coverage (unqualified; that is whether a Kroger Location serves an area)

**Day note**:
Vana's short note about one day of the plan, shown at the top of the Plan tab. A plan's notes are written ahead and kept, and rewritten in the background when the plan changes.
_Avoid_: Daily brief

**Review sheet**:
The sheet that shows a draft plan before it is confirmed: what the period adds up to, every meal with its servings, and the Confirm button.
_Avoid_: Review plan screen, summary

**Plan bar**:
The bar pinned above the message box in a planning conversation that shows the Draft: its meals, their servings and the Review plan button. It never shows the confirmed plan.

### Building and shipping the app

**Prototype**:
The TanStack web app where meal planning was first built, kept in its own repo. It is the living reference for how the feature looks and behaves and the source of the test fixtures; none of its code is copied into the app.
_Avoid_: Web prototype, reference app, Kyle prototype

**Kyle design system**:
The app's one design system: a single set of named colours and sizes (the Kyle tokens) and a shared library where each designed widget is built once from its written component spec.
_Avoid_: Theme, skin, token registry

**Cutover**:
The one planned step that takes meal planning from the dev backend to production, following a runbook: its database changes go out, the meal library is seeded, and old columns are removed. Until then everything is dev-only.
_Avoid_: Prod launch, migration day

**Dev build**:
The app built against the dev backend rather than production, for the team. It ships every unfinished feature visible; nothing in it is hidden behind a build flag.
_Avoid_: Debug build, dev mode (that is the dev environment the build runs in)

**Wiredash**:
The bug-report tool whose inbox the team reads. An athlete reaches it by shaking the phone or from the card Vana shows for a problem, and feedback typed to Vana is filed there too.
_Avoid_: bug-report inbox, feedback form

### Building and testing

**Seam**:
The place a test enters the real code, with fakes standing in for everything beyond it: the server's handlers, the app's notifiers, the screens, or the eval. A spec names its seams in its Testing Decisions.
_Avoid_: Test layer, test level

**Testing wave**:
A round of scenario tests run on simulators, by agents driving the app and by Patrol, that checks the app, RevenueCat and the dev database together and writes down every Finding. Rounds repeat (test, triage, fix, retest) until no Finding is open.
_Avoid_: QA pass, test sweep

**Finding**:
One thing a Testing wave turned up: a bug, a conflict with an SSOT decision, a Follow-up test, or an idea. Agents record Findings and never fix them during the run; the fixing waits for triage.
_Avoid_: Issue, error report, bug ticket

**Follow-up test**:
A scenario nobody has run yet, which an agent wrote down while looking over a screen for other paths through it and other ways it could break. Together they are the backlog each later round draws from.
_Avoid_: Additional test, test idea

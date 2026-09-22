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

**Hand-off**:
The end of Mealvana's involvement in an order: the shopper leaves for Kroger's own checkout to
choose a slot and pay. Mealvana never places an order, sees an order, or knows whether one
happened, and never handles payment.
_Avoid_: Checkout, purchase, order placement

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

### Paying for the app

**Gate**:
The one check that decides whether an account may use the app. It answers yes for an account that
holds Pro, for a Tester and for an Admin, and the app and the server ask it the same way. There is
one Gate for the whole app; no feature has its own.
_Avoid_: Pro gate, Vana gate, feature lock

**Pro**:
What an account holds when it may use the app: a trial, a paid subscription or a Grant. The app
has no free tier, so an account either holds Pro or is Lapsed.
_Avoid_: Premium, Pro tier, paid tier

**Lapsed**:
An account that does not hold Pro. It can open every screen and read everything it made, under a
Subscribe bar, and can change nothing.
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
An account that turned on the seven-tap switch in Settings. The Gate lets it in, and it sees test
items. Anyone can become one.
_Avoid_: Internal user, beta user

**Admin**:
A team account marked by hand in the database. The Gate lets it in, and it may review meals.
_Avoid_: Staff, superuser

**Allowance**:
The credits a subscription grants into the wallet each billing period. Spent before any pack
credits, forfeited when the period ends, and the only credits a trial has. The wallet does not
distinguish where a credit came from except in this order of spending.
_Avoid_: Free credits, included credits, quota

**Top-up**:
A pack of credits bought on its own, spent only once the Allowance is empty. Top-up credits never
expire and are never forfeited, whatever happens to the subscription.
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
_Avoid_: Credits, tokens, quota, allowance of credits

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
The paywall as an account that never subscribed sees it, straight after sign-up: full screen, with no way to close it.
_Avoid_: Onboarding shape, signup paywall

**Paywall sheet**:
The paywall as an account that held Pro once and lost it sees it: a sheet it can close, over its read-only app, opened from the plan-ended bar, from any edit or AI tap, or from Upgrade on the Subscription screen.
_Avoid_: Lapsed shape, closable sheet

**⋯ menu**:
The one button in the paywall's top corner that holds everything secondary: Restore purchases, Redeem code, Manage subscription, Sign out and Delete account.
_Avoid_: Overflow menu, more menu

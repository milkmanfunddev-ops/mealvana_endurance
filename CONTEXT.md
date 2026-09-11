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
A photograph of the finished Meal itself. The only image that depicts what the person will
actually eat, and therefore always preferred over any substitute.
_Avoid_: Hero, thumbnail (those are placements, not kinds of image)

**Tile**:
A photograph of a single ingredient, held in `ingredient_images` and keyed by slug, reusable
across every Meal that contains that ingredient. A Tile depicts an ingredient and never a Meal.

**Mosaic**:
Two to four Tiles composed into one frame at render time to stand in for a Meal that has no Dish
photo. A Mosaic is a substitute, never a preference: where a Dish photo exists it wins. Composed
client-side in Flutter, never pre-rendered.

**Image mode**:
Which of the above a Meal is currently showing — `dish`, `mosaic`, `tile`, or `none`. It records
what the Meal fell back to, so the size of the substitute population is always countable.

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
The model call that reaches a Verdict. It is a gate, not an audit: no picture is stored for a
Meal unless the Judge has already rated it `ok` for that Meal.

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

# Scope the AI assistant to weekly meal planning and in-the-moment suggestions, not race fueling

- **Source URL:** https://app.notion.com/p/382e3fdb754c81358d77ec4a64e8aa8a
- **Ancestor path:** Feature Requests (data source) → Feature Requests (database) → 🛠️ Product & Engineering
- **Snapshot as of:** 2026-06-28T22:23:47.588Z
- **Area:** AI Assistant
- **Effort:** 5 · **Impact:** 5
- **Reporter:** Xuan Huang, Lee
- **Reported:** 2026-06-17
- **Updated:** 2026-06-25
- **Status:** New
- **Roadmap link:** https://app.notion.com/p/2e8e3fdb754c80c4806ed277144fc50d
- **Tasks link:** https://app.notion.com/p/382e3fdb754c81fa8728c4b1c11418ed
- **Source transcript:** Transcript: 2026-06-17T132941Z__Milkman-Inc-s-Personal-Meeting-Room__r-JBBeSLRcqRNrGuvYmROw--.md, S3

## Request

Fix the AI assistant's scope and offered options. "Fuel my 12-mile run today" should NOT be an offered option — the deterministic before/during/after module already plans race fueling well. The two real reasons users open the assistant are: (1) plan multiple days / get a shopping list, and (2) in-the-moment "what's a good snack / quick dinner" suggestions. The assistant should support **weekly meal planning + shopping lists**, be **time-aware** (suggest meals around when the workout actually is, not blanket pre/post), and when suggesting for today should prefer meals the user already planned or bought.

## Underlying need

Routing race-fueling to the LLM wastes an existing deterministic function and risks hallucinated fueling advice (the LLM doesn't know the protocol). Aligning the assistant's options to the two genuine user intents keeps it useful and safe.

## Evidence

- Xuan Huang: "fuel my 12-mile run today, that simply shouldn't be an option being offered there… I already have a deterministic module that does that."
- Xuan Huang: "if you use AI, it will hallucinate and say, hey, you go have some dates at this mile… it doesn't know the [protocol]."
- Xuan Huang: "People come to Jade because they want to plan out the whole week's meal… I want to plan, I want to get a shopping list… [or] I'm hungry, what would be a good quick snack."
- Lee: "Maybe we can make this a little bit smarter, where it checks the time when your workout is at, and it's not recommending all the pre-workout and post stuff."
- Lee: "this is the same problem that we've had for, like, 5 years… we can change the term that's here from Log It to Plan It."

## Decision / rationale

The founders settled the assistant's scope: race fueling stays with the deterministic before/during/after module (do not route it to the LLM — it wastes the existing function and risks hallucinated, protocol-ignorant advice). The assistant is scoped to the two validated user intents — week-long meal planning with shopping lists, and in-the-moment snack/quick-dinner suggestions — and should be time-aware and bias toward already-planned/bought meals. Lee flagged the long-standing "Log It vs Plan It" labeling ambiguity for future-dated meals as still open.

## Notes

Source segment S3 (cues 237–275, 290–319). Secondary design-note: the "Log It / Plan It" label on future-dated meal suggestions is a ~5-year UX ambiguity, still unresolved. Ties to S1 (logistics / shopping list as prime real estate) and to S9 (don't route deterministic work to the LLM, token cost).

## Past interview evidence

Strong — both the framing (fueling spans daily / training / race day, not just race day) and the demand for a conversational planning assistant are attested:

- Ryan Bolton (Coach, 2025-11-14): frames fueling as three components that must each be handled — daily nutrition, training fuel, and race day. — [interview](https://app.notion.com/p/328e3fdb754c81fb871fdd016b30cb11#e3c2bd9216ab47a98a158f94f86fc8e0)
- Sarah Portella (Coach, 2025-11-21): draws an explicit boundary — she dials in during-exercise fueling and refers the rest out — showing how athletes silo fueling to the workout itself. — [interview](https://app.notion.com/p/328e3fdb754c81128a28c4e85f3d750b#3abd8cb3ed284642b2064e0612f30c2f)
- Athletes in prototype tests reached for the assistant to plan, not just to log — Ashley Foster used it as a planning partner. — [interview](https://app.notion.com/p/366e3fdb754c80519193f1e66d17de0d)

Note: the conversational, plan-led assistant tested well; corroborated across coach and athlete sessions. (Ashley's session has no text body in Notion — transcript is a .vtt attachment — so that link lands on the interview page, not a block.)

---

## Update 2026-06-25 — meal-planning development

*From the 2026-06-25 Xuan + Lee sync. Develops this FR with the meal-planning prerequisite; the AI suggestion/magic button is hidden in v1 until this lands (see 🎨 Design Discussion on the AI insight).*

### Request

A dedicated **meal-planning** capability (a future/separate tab) that lets an athlete plan a week of meals, generate a **shopping list** from that plan, and then power **AI meal suggestions** that answer "which of your planned recipes fits today" against the day's macro target. Meal planning is the explicit **prerequisite** — without it, suggestions can't be useful.

### Underlying need

Suggesting what to eat is unhelpful today because the app doesn't know what the user actually has or plans to have — "go have avocado toast" is useless if they don't have it. Bridging the gap between a daily macro target and an actual, followable food choice requires knowing the user's planned/available food.

### Evidence

- Xuan: "right now we do not do meal planning… you suggest people go have avocado toast, and people are like, okay, where do I get it?"
- Xuan: "once we have that nailed down, then the next step is meal planning… that will be a different tab… then we develop the suggestion, because now we know what you have planned."
- Lee: "prioritize recent foods and saved foods… look at some of the recipes we have… try to fit it in… it's gonna probably be shitty at first, but that's what I would suggest."

### Corroborating evidence

Advances a validated problem — **Plan creation is slow, manual, and error-prone for coaches** (Strong (6+), Coach, 3 interviews) — [problem statement](https://app.notion.com/p/308e3fdb754c8186b371e445bbdba189). The directly-relevant voice is the gap between macro targets and real food choices:

- Josh & Jen (Coach): "An athlete used an app that connected to TrainingPeaks and provided macros, but the athlete still came back asking what to eat — that actually put more work on us… Current tools stop at macro targets without bridging to actionable food choices."

Secondary (weaker/broader) — **Algorithm-generated nutrition recommendations must be realistic and trustworthy out of the box** (Moderate (3-5), Both, 3 interviews) — [problem statement](https://app.notion.com/p/321e3fdb754c8138bd62e4965b4414ba):

- Claudia McCoy (Athlete): "I want to look into it as you guys give me suggestions what is perfect, and I'll eat it." — plus the "4 bananas" unrealistic-defaults problem; meal suggestions must draw on real, available food.

**Honest fit caveat:** both statements corroborate the "tell me what to actually eat" need, but neither's core is the meal-planning-tab *mechanism* (plan week → shopping list → suggest-from-plan). That specific workflow is Xuan's product vision and is not yet validated by prior research. **Verdict: thin** (real but partial/broader corroboration).

### Notes

- Tightly coupled to design point **S3** (2026-06-25): the AI suggestion ("magic"/sparkle) button is being **hidden for v1** precisely because suggestions can't do a good job until meal planning lands. This FR is the capability that unblocks re-enabling that button.
- The live prototype already shows a meal-suggestion surface (Chocolate Milk +330 / Grilled Chicken +640 / Sweet Potato +200, each with a + button) — `data/design-handoff/2026-06-25…Mcbeiy7CRBCb9f5ukGhfsg--/screen_04.png` — but it's deferred until meal planning exists.
- Lee's first-version approach: use the daily macro targets, prioritize recent/saved foods + the quick-recipe DB, fit into rough slots, expand the ingredient list; "shitty at first" but a starting point.
- Lee flagged unspecified problems with Xuan's meal-planning vision "to talk about later."
- **Dedup/evolution:** Substantively the same want as this same 2026-06-17 FR (`382e3fdb-754c-8135-8d77-ec4a64e8aa8a`) — the update recommends evolving/cross-linking this row rather than creating a parallel duplicate.

### Candidate interview questions — 2026-06-25

**Test type:** Discovery · **Why test:** The "tell me what to eat" need is validated, but the *meal-planning-tab mechanism* (plan a week → shopping list → suggest-from-plan) is Xuan's product vision, not something users have asked for in that shape. Lee himself flagged "unspecified problems" with it. We don't yet know whether athletes want a plan-ahead workflow or just-in-time "what should I eat now" suggestions.

**Prior evidence:** Thin — prior PSes corroborate that apps stop at macro targets without bridging to real food ("still came back asking what to eat"; the "avocado toast — where do I get it" failure), but none validate a weekly-plan-then-suggest workflow as the right solution shape.

**Show the participant:** Nothing — discovery, behavior-first; surface how they actually decide what to eat and how they shop before introducing any planning tab or suggestion screen. Optional reveal-late prop (only after the behavior questions): the deferred suggestion surface `data/design-handoff/2026-06-25…Mcbeiy7CRBCb9f5ukGhfsg--/screen_04.png` — never as the opener.

1. Walk me through how you decided what to eat yesterday on a training day — from waking up to your last meal.
   - *Listening for:* whether they plan ahead vs. decide in the moment; what actually drives the choice (what's in the fridge, time, training load, convenience).
2. Think about the last time you grocery-shopped — how did you decide what to buy, and how (if at all) did your training week factor in?
   - *Listening for:* whether a week-ahead meal/shopping plan already exists in their life or it's ad hoc; the real gap between "I have a target" and "I have the food on hand."
3. The last time an app or a coach told you what to eat, what made you actually follow it — or ignore it?
   - *Listening for:* the "avocado toast — where do I get it" failure mode; availability/practicality (do I own it, can I make it now) as the gate on following any suggestion.

## Comments / Discussions

None found (page-level and all-block comment search, including resolved, returned empty).

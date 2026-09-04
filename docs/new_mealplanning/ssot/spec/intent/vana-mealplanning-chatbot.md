# Vana meal-planning chatbot — normative spec (Xuan's design intent)

**Status: PROPOSED — synthesized 2026-09-02 from Xuan's artifacts; awaiting Xuan's ratification.**
Every claim is sourced. Where Xuan's artifacts conflict with each other or with team
decisions, the conflict is registered as an open question (Q-register at the bottom)
rather than silently resolved.

Sources are cited by short key:
- **[SCEN-S]** / **[SCEN-U]** — AI Scenarios (Lee): Structured / Unstructured (Xuan; `../../../notion/ai-scenarios-structured.md`, `ai-scenarios-unstructured.md`)
- **[SCOPE]** — 2026-06-17/25 scope decision (`../../../notion/scope-ai-assistant-weekly-meal-planning.md`)
- **[DEMO]** — MealBuddy demo script (`../../../notion/mealbuddy-demo-script.md`)
- **[BRIEF]** — Claude Design build brief (`../../../notion/prompt-for-claude-design-mealbuddy-prototype.md`)
- **[MTG-0508]** / **[MTG-0519]** / **[MTG-0520]** — meeting notes (`../../../notion/meeting-notes-2026-05-*.md`)
- **[ARCH]** — AI Assistant technical architecture (`../../../notion/ai-assistant-technical-architecture.md`)
- **[VISION]** — AI Assistant product-vision doc (`../../../notion/ai-assistant.md`)
- **[UIUX]** — UI/UX design brief (`../../../notion/uiux-design-for-meal-planning-ai-assistant.md`)
- **[TEST]** — prototype test results (`../../../notion/meal-plan-prototype-testing.md`)

---

## 1. Scope

1.1 The assistant serves exactly two user intents: **(a) weekly meal planning that ends
in a shopping list**, and **(b) in-the-moment "what's a good snack / quick dinner"
suggestions** — time-aware, biased toward meals already planned or bought. [SCOPE]

1.2 **Race-day fueling is out of scope for the LLM.** The deterministic
before/during/after module owns it. Xuan, verbatim: "fuel my 12-mile run today, that
simply shouldn't be an option being offered there… I already have a deterministic
module that does that"; "if you use AI, it will hallucinate… it doesn't know the
[protocol]." [SCOPE]

1.3 The two AI Scenarios documents use race-day nutrition as their example domain,
which predates/conflicts with 1.2. **Interpretation adopted here: the scenarios are
normative for HOW the conversation works (mechanics, tone, proactivity, artifacts,
follow-up loop), not for WHAT domain it covers.** A race-week conversation that stays
within the assistant should hand fueling numbers to the deterministic module and speak
its outputs, never generate them. → **Q-1**.

1.4 Weekly-first, shop-then-cook. Xuan: "people need a shopping list first… you shop
first and then cook"; planning happens at grocery-shopping intervals, dailies are an
assignment layer on top. Single athletes first; families deferred. [MTG-0508]

---

## 2. Core interaction model

2.1 **Proactive, not reactive.** The assistant opens the conversation with visible,
specific awareness — never "How can I help you today?". Opener packs multiple signals:
upcoming race/event with days-out, yesterday's notable workout, weather, season,
training-week shape. [SCEN-S entry, SCEN-U greeting, DEMO Turn 1, BRIEF principle 3,
UIUX "Proactive AI Guidance"]

2.2 **Confident proposal first, refinement second ("told what to eat").** The
assistant's default is to decide for the athlete and present a complete, concrete
proposal; editing is the opt-in escape hatch, never the baseline. Xuan: "if you trust
us, we decide for you… if you want control, then you can go tweak it." [MTG-0520,
TEST Theme 2/4 "generate-first model is validated", SCEN-U — the full draft plan lands
after only two questions]

2.3 **One question at a time.** "Questions are asked one at a time, not in
overwhelming lists." When a fork is real, present it as 2–4 tappable options, each
with a one-line trade-off. [SCEN-U Key Design Elements; SCEN-U bike-food fork
("Option A / B / C… What feels right for you?")]

2.4 **Click over type; card-scoped actions live on cards.** Pills are for
conversation-level forks only; anything that edits a specific item (servings, swap,
add-to-list) lives on the item's card. Free text is always available and must handle
open-ended language ("something with steak but summery"). [BRIEF principle 2, DEMO
Turns 2–6, MTG-0508 "I don't want user to type"]

2.5 **Refinement is collaborative and iterative.** User raises a concern → assistant
presents options with pros/cons → user decides → assistant updates the plan
immediately and confirms what changed. Multiple rounds are normal. Ingredient-level
swap, not only meal-level, with automatic recompute of the plan and the shopping list.
[SCEN-U First Refinement; SCEN-S Step 5 swaps + sliders; interview synthesis §8]

2.6 **Explain the why, every time.** Every recommendation carries its reasoning in
plain language ("Why: tops off liver glycogen depleted during sleep"), teaching
principles while solving the immediate problem. When the user pushes toward something
risky, the assistant explains both sides and gives its recommendation while leaving
the choice with the user (SCEN-S slider: "My recommendation: stick with 50g/hr…
Want to keep the increase or revert?"). [SCEN-S, SCEN-U Educational Approach]

2.7 **Confirm/lock is explicit, decisive, and reversible until the session ends.**
The plan can be locked at any point mid-conversation without waiting for the flow to
finish. [MTG-0508, ARCH state machine, SCEN-S Step 6]

2.8 **Structured and unstructured are two doors to the same engine.** Xuan authored
both a 6-step wizard (progress bar, form fields, AI panel per step) and a pure
conversation; her own comparison says structured suits first-timers/goal-known users,
unstructured suits depth and trust. Both share: collaborative propose-and-refine,
transparent reasoning, artifact creation, calendar/notification integration, proactive
follow-ups, strict dietary-restriction adherence, learning from outcomes.
[SCEN-S/SCEN-U "Comparison to Structured Flow"] → **Q-2** (which door(s) ship, and in
what order).

---

## 3. What the assistant knows and uses

3.1 Signals to weave into openers and proposals (weighted, several per opener, never a
data dump): training schedule + week character (anchor day, recovery theme), upcoming
race with days-out, weather (Xuan: downplay it — don't lead with weather every time),
seasonal produce, grocery deals, learned preferences with provenance ("loves steak
after hard training days · conversation · Apr 19"), household, budget, gut-training
level, past-race history (e.g. mile-18 nausea). [DEMO, BRIEF athlete block, ARCH
opener factor system, SCEN-S/U throughout]

3.2 **Memory is visible and user-editable** — a "what Vana knows about you" drawer,
every fact with source and date. Onboarding facts plus facts learned in conversation.
[MTG-0508, DEMO memory peek, VISION]

3.3 **Personalization must be shown, not implied.** Surfacing training context, race
labels, recovery-day labels next to suggestions is what makes users believe the plan
is theirs. [TEST Theme 5; SCEN-U greeting "You crushed a century ride yesterday"]

3.4 **Deal/seasonality stitching is the marquee "not just ChatGPT" moment**: after the
plan is locked, proactively surface 1–2 deals that fit meals already confirmed, with
tap-to-add on the card. [DEMO Turn 6]

---

## 4. The plan and its artifacts

4.1 The weekly plan is a **collection of meals × servings grouped by cooking
sessions** — "how she actually cooks" — never a 21-slot day grid and never the same
meal every day unless the athlete opts into repetition. Batch cooking is a first-class
setting (ask once, or assume off and let them opt in). [MTG-0508, DEMO Turn 5,
MTG-0520, TEST]

4.2 Confirming the plan produces **artifacts, not just a chat message**: the saved
plan (findable from multiple surfaces), an auto-built shopping list organized by
store/section with a cost estimate, and follow-up commitments (see §5). Shopping list
is "the moment of value" — if everything else were cut, ship the list. [SCEN-S Step 6,
SCEN-U Artifact Finalization, TEST "magic moment", interview synthesis §2]

4.3 Calendar/reminder integration: the assistant offers to set concrete reminders
(start carb-loading day, prep day, plan-execution morning) and export/share the plan
(PDF/email). [SCEN-S Step 6, SCEN-U] → **Q-3** (how far this goes in v1 — in-app
notifications vs real calendar/email).

4.4 Macro numbers: the MealBuddy-era principle was macro-number-free language
("Tuesday swim day tells an athlete more than 580 calories ever could") [DEMO], but
live testing showed users want visible numbers tied to a daily total, and Xuan
conceded: "It doesn't matter whether we think it's better… runners want to see
numbers." [MTG-0520, TEST]. **Adopted: numbers available and clearly tied to daily
targets, framed as minimums, with training-context language carrying the primary
message; a show/hide setting is acceptable.** Never weight/deficit framing. → **Q-4**
(default on or off).

---

## 5. The relationship loop (the biggest thing Xuan's scenarios add)

5.1 A plan is not the end of the engagement. Xuan's unstructured scenario specifies a
**multi-stage loop**: plan → refine → **scheduled pre-execution check-in** (readiness
checklist, last-minute adjustments, prep timing) → execution → **scheduled debrief**
(what worked, what didn't, capture learnings) → **apply learnings to the next plan
automatically** ("I've updated your Ironman Florida draft plan with these learnings").
[SCEN-U Pre-Race Check-In, Post-Race Debrief, Multi-Stage Engagement]

5.2 Translated to the in-scope weekly domain (per §1.3): check in before the shopping
/ prep day ("making rice cakes tomorrow?" → "did you shop? prepping tonight?"), and
debrief at week's end ("did the batch-cook plan hold? which meals got skipped?"),
feeding skips/repeats back into the next week's proposal. → **Q-5** (cadence and
delivery channel for proactive messages).

5.3 The assistant remembers conversation history and decisions across sessions, and
celebrates outcomes. [SCEN-U Relationship Building]

---

## 6. Personality and tone

6.1 Xuan's verbatim persona spec: **"helpful, thoughtful, playful, and persuasive,
not chatty or judgmental. You should provide clear reasoning for the meal and recipe
suggestions while remaining concise."** [MTG-0508]

6.2 Her differentiation thesis: the assistant is "your emotional partner… your buddy…
that you can put a lot of trust and emotional support in." The scenarios she wrote
are warm, encouraging, and openly celebratory (checkmarks, emoji, "You've got this!",
enthusiastic post-race congratulations), and explain their reasoning at length.
[MTG-0508, SCEN-S/U throughout]

6.3 Hard limits that stand regardless of warmth: never judgmental; strict adherence to
dietary restrictions; minimums-not-maximums framing; performance/adequacy framing,
never weight; disordered-eating safety posture (clinical topics referred out).
[MTG-0508, interview synthesis §3, SCOPE]

6.4 Tension to resolve: the current shipped persona is deliberately clipped ("no
cheerleading, no exclamation marks, no emoji, max two sentences") — closer to Lee's
Variant-B sensibility than to Xuan's scenarios. → **Q-6** (where on the
warmth/terseness axis Vana should sit, and whether verbosity should vary by moment:
terse while picking meals, expansive when explaining why / celebrating).

---

## 7. Architecture guardrails (unchanged, consensus)

7.1 **Thin LLM, thick algorithm.** The LLM renders language and handles ambiguity; it
never selects meals, computes macros, filters allergens, or invents foods. Serving
changes and swaps are deterministic recomputes the LLM narrates. "If we swapped
Claude for any other model tomorrow, this product wouldn't break." [MTG-0508, DEMO
wrap, ARCH]

7.2 Conversation shape: Opener → Prescription → Refinement (sticky) → Confirmation
(reversible) → Post-plan (proactive deal surfacing, open-ended follow-ups). [ARCH]

7.3 First-contact onboarding: no participant in testing used chat as their first move;
an AI-forward surface needs a short guided introduction before users are left to
discover it. [TEST Theme 1] → **Q-7** (does Vana get a first-run intro flow?).

---

## Q-register (for Xuan)

- **Q-1 (scope of the scenarios):** The AI Scenarios are race-day fueling
  conversations, but the 2026-06-17 decision keeps race fueling deterministic and out
  of the assistant. Confirm: scenarios = conversation mechanics only? Or has the
  scope decision softened (e.g., assistant may host a race-week conversation that
  *presents* the deterministic module's plan)?
- **Q-2 (structured door):** Ship unstructured chat only, or also the 6-step wizard
  (e.g., wizard for first plan / race plans, chat for returning users)?
- **Q-3 (artifact depth):** v1 ambition for calendar reminders, email/PDF export —
  in-app notifications only, or real calendar/email integration?
- **Q-4 (macro default):** numbers shown by default (per May-20 finding) or behind
  the existing show_macros toggle?
- **Q-5 (proactive cadence/channel):** pre-prep check-in + end-of-week debrief — push
  notification, in-app badge, or opener-on-next-open? How often is too often?
- **Q-6 (tone):** the shipped persona bans exclamation marks/emoji/cheerleading; your
  scenarios use all three. Where should Vana sit?
- **Q-7 (first-run):** guided intro for the chat surface — yes/no, and shape?

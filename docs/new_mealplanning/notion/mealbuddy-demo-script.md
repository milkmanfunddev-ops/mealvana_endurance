# MealBuddy demo — script for tomorrow

- **Source URL:** https://app.notion.com/p/359e3fdb754c81169715eb1e7fb65687
- **Snapshot date (as fetched):** 2026-05-08T00:20:42.566Z
- **Icon:** 🎬
- **Ancestor path:** Homepage › [unnamed] › [unnamed] › Features › Technical and Product Documentation › (data source: Technical and Product Documentation) › AI Assistant › **MealBuddy demo — script for tomorrow**

## What this is

A ~5-minute walkthrough that demos how much proprietary intelligence MealBuddy uses while narrowing to a confirmed plan fast. Each turn packs multiple signals (training, weather, season, cooking knowledge, deals, household). Caroline is an already-onboarded power user.

The conversation is **macro-number-free** — direction is given through training context, sensory cues, and seasonal language. The demo also rotates UI patterns: pills, free-text input, serving editor, **interactive deal cards (direct tap-to-add, no pill mediation)**, and the memory drawer.

---

## Setup (20 sec) — before opening the prototype

> "Almost every athlete and coach we talked to asked for meal planning. Performance nutrition is the hook; meal planning is the retention. Watch how this conversation uses everything we already know — training, weather, season, this week's deals — to land a confirmed plan in under five minutes."

Open the demo.

---

## Turn 1 — Opener (~25 sec)

**MealBuddy:**
> "Hey Caroline. Heat wave through Wednesday, then cooling. Your brick on Sunday means recovery's the theme. Summer squash, tomatoes, peaches just hit peak. What sounds good?"

**UI:** assistant bubble · pill row · free-text input visible

**Pills:** `Steak` · `Light & fresh` · `Surprise me`

**Proprietary intelligence:**
- 7-day weather forecast (heat → cooling)
- Training schedule (TrainingPeaks: brick Sunday)
- Recovery framing for the week
- Local seasonal produce (region × month)

**Narration (point at the opener):**
> "Four signals in one sentence — weather, training week, recovery theme, season. The system is already framing the week before Caroline says anything."

---

## Turn 2 — Caroline types (~10 sec)

**Caroline (free text):**
> "Something with steak but I want it to feel summery."

**UI:** free-text input — typed, not pill-tapped

**Narration:**
> "Pills are convenient, but the system handles open-ended language. *Summery steak* isn't a checkbox — that's interpretation."

---

## Turn 3 — Ribeye proposal with serving editor (~45 sec)

**MealBuddy:**
> "Grilled ribeye with chimichurri, paired with a peach and tomato salad. Anchors Thursday's hill repeats and keeps the heat outside the kitchen — grill night."

**UI:** assistant bubble · meal card with **serving editor (− / +)**

```
[Meal card]
  Image: ribeye + chimichurri
  Title: Grilled ribeye + summer salad
  Subtitle: peach, tomato & basil salad on the side
  Tag: Thursday · post-hill recovery
  Servings: [−] 2 [+]   ← interactive
```

**Demo move:** Tap **+** twice. Servings go 2 → 4.

**Inline status:**
> "Updated to 4 — bumping the ribeye and tomatoes on your list."

**Proprietary intelligence:**
- Routes craving (steak) into training context (Thursday hills)
- Pairs with peak-season produce (peaches, tomatoes)
- Cooking intelligence: grill chosen for the heat wave
- Deterministic recompute on serving change (ingredients, shopping list, macro alignment)

**Narration:**
> "The serving change isn't an LLM call — it's a deterministic recompute. Ingredients scale, the shopping list updates, macros stay aligned. The LLM just narrates."

---

## Turn 4 — Pair proposal (~40 sec)

**MealBuddy:**
> "For Tuesday's swim — Lemon Herb Chicken with Mediterranean quinoa. Light, hydrating, won't sit heavy. For Sunday brick recovery — Baked Salmon with Capers and a Greek cucumber salad on the side. Omega-3s for inflammation, cold sides after a long brick. Cool with these for your three cooking sessions?"

**UI:** assistant bubble · two stacked meal cards · pill row

```
[Card 1] Lemon herb chicken thighs · Tuesday · swim day
[Card 2] Baked salmon, tomatoes & capers · Sunday · brick recovery
```

**Pills:** `Lock all three` (primary) · `Swap one`

**Proprietary intelligence:**
- Each meal tied to a specific training day's recovery profile
- Sensory cues replacing numbers ("won't sit heavy", "cold sides")
- Cooking-session rhythm (Caroline's three-sessions-per-week pattern)

**Narration:**
> "Each card carries the training context where macros used to be. *Tuesday swim day* tells an athlete more than 580 calories ever could."

---

## Turn 5 — Lock + cooking sessions summary (~35 sec)

**Caroline (pill):** `Lock all three`

**MealBuddy:**
> "Done. Three cooking sessions, your usual rhythm — Sunday afternoon for ribeye prep, Monday evening for chicken, Saturday morning for salmon."

**UI:** cooking sessions card

```
[Cooking sessions card]
  Session 1 · Sunday afternoon
    Grilled ribeye + chimichurri (Thu post-hill recovery)
    Peach + tomato salad (in-season)
  Session 2 · Monday evening
    Lemon herb chicken thighs (Tue swim day)
  Session 3 · Saturday morning
    Baked salmon w/ capers (Sun brick recovery)
    Greek cucumber salad (bright, hydrating side)
```

**Narration:**
> "Plan grouped by *cooking sessions*, not by days — that's how she actually cooks. Each meal still carries its training context inside the session view."

---

## Turn 6 — Proactive interactive deal cards (~50 sec) ⭐

**MealBuddy:**
> "While I have you — two things on sale this week that fit your plan."

**UI:** two **interactive deal cards** stacked, each with a tappable `+ Add to list` button on the card itself. **No pills** — interaction is direct on the card.

```
[Deal card 1 · Peaches]
  Image: peaches
  Title: Local peaches
  Deal: 25% off — just dropped at Publix
  Why: Already in Thursday's salad — bump for grilled side too
  Action: [+ Add to list]   ← tappable directly on card

[Deal card 2 · Asparagus]
  Image: asparagus
  Title: Asparagus
  Deal: peak season — best price of summer
  Why: Top up for Saturday's salmon prep
  Action: [+ Add to list]   ← tappable directly on card
```

**Demo moves:**
1. Tap `+ Add to list` on the peaches card → animates to `✓ Added`, button changes color.
2. Tap `+ Add to list` on the asparagus card → same animation.

**MealBuddy (after both added):**
> "Both added to your Publix list."

**Proprietary intelligence:**
- Deal API integration (this week's circular)
- Deals stitched directly into already-confirmed meals
- Cross-meal memory

**UX intelligence:**
- **Direct interaction on the card itself** — no pill mediation. The card is a unit of action, not a presentation. The user does what makes sense *where* it makes sense.

**Narration:**
> "Two things to notice here. First — the deals aren't a list. They're stitched back into Thursday's salad and Saturday's salmon, two meals we already locked in. Second — the interaction lives on the card itself. She taps *Add to list* directly. No 'do you want me to add these?' pill. The card *is* the action."

---

## Turn 7 — Final lock (~25 sec)

**MealBuddy:**
> "Locked. Three cooking sessions, lined up with your training, peaches and asparagus added. Shopping list ready for Publix. Wes can see it. Your nutrition coach too."

**UI:** final lock card (forest-green confirmation)

**Proprietary intelligence:**
- Coach visibility (nutrition coaches)
- Household visibility (Wes)

**Narration:**
> "The loop closes. Plan, deals, household, coach — every input we have, threaded through one plan."

---

## Memory peek (~30 sec, optional but recommended)

**Demo move:** Tap **Memory** in the header. Drawer slides up.

**Narration:**
> "Last beat. This is what MealBuddy knows about Caroline. Profile, household, this week's training, and learned facts — every one with a source and a date. *Loves steak after hard training days* — from a conversation, April 19. *Drawn to peaches and stone fruits in summer* — May 4. She can edit any of it. This is the trust layer."

Close the drawer.

---

## Wrap (~45 sec)

> "What you saw runs on three things we already own — V5 macro pipeline, fueling templates, TrainingPeaks integration — plus three things we're building: the residual budgeter, the lego recipe engine, and the editable memory script. The LLM is in there, narrating, never deciding. Macros, allergens, deals, food safety — all computed by our stack."

Pause.

> "If we swapped Claude for any other model tomorrow, this product wouldn't break. The intelligence is in our stack. We are not building a wrapper."

---

## UI elements demonstrated (for the record)

| Element | Where it appears | Why it's there |
|---|---|---|
| Pill row | Turns 1, 4 | Fast forks, low-friction |
| Free-text input | Turn 2 | Open-ended language |
| Meal card with serving editor | Turn 3 | Lego recompute on adjustment |
| Stacked meal cards | Turn 4 | Pair proposals at once |
| Cooking sessions card | Turn 5 | Plan organized by *how she cooks* |
| **Interactive deal cards (tap-to-add)** | Turn 6 | Card *is* the action — no pill needed |
| Final lock card | Turn 7 | Closes the loop |
| Memory drawer | Optional | Trust layer reveal |

---

## Proprietary intelligence demonstrated (for the record)

| Signal | First shown | Re-used |
|---|---|---|
| Weather forecast | Turn 1 | Turn 3 (grill choice) |
| Training schedule (TrainingPeaks) | Turn 1 | Turns 3, 4, 5 |
| Seasonal produce | Turn 1 | Turns 3, 6 |
| Recovery framing per training day | Turn 3 | Turn 4 |
| Cooking intelligence (heat → grill) | Turn 3 | — |
| Cooking-session rhythm | Turn 4 | Turn 5 |
| Deal API integration | Turn 6 | — |
| Cross-meal pairing of deals into existing plan | Turn 6 | — |
| Coach + household visibility | Turn 7 | — |

---

## Things deliberately NOT in the demo

- **Onboarding flow.** Caroline is already onboarded.
- **Macro numbers.** By design — system uses them internally, athlete sees language.
- **Performance nutrition / during-workout fueling.** Separate, already-shipped product.
- **Breakfast and snacks.** Cut to keep the demo focused on dinners.
- **Coach dashboard view.** Separate prototype thread.
- **Real backend.** All data is mocked.

---

## Likely questions

**"Where are the macro numbers?"**
> Internal. The V5 pipeline computes them, the residual budgeter subtracts fueling, recipes validate against alignment. Athletes get language; coaches will get numbers in the dashboard.

**"Isn't this just ChatGPT with recipes?"**
> ChatGPT doesn't have her training week, can't surface this week's deals at her store, and doesn't remember the meals it just suggested in order to pair them with peaches and asparagus. Every one of those is our stack.

**"How big is the recipe content build?"**
> ~10–20 templates and ~80–120 components for v1. Variety is combinatorial, not curated.

**"What's not in the prototype yet that's in the script?"**
> Three on-card interactions: (1) the serving editor `+ / −` on the meal card, (2) the `⇄ Swap` action on each meal card with substitution sheet, (3) the `+ Add to list` button on the deal cards with tap-to-add animation. About 30 minutes each. Without them, the script can still be narrated while showing the static cards.

---

## Comments / discussion threads

None found (no discussion markers returned by `notion-fetch` with `include_discussions: true`).

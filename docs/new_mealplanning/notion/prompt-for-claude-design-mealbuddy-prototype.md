# Prompt for Claude Design — build the MealBuddy prototype

- **Source URL:** https://app.notion.com/p/35ae3fdb754c81c6a5fcc6008648f3f3
- **Snapshot date (as fetched):** 2026-05-18T20:14:23.705Z
- **Icon:** 🎃
- **Ancestor path:** Homepage › [unnamed] › [unnamed] › Features › Technical and Product Documentation › (data source: Technical and Product Documentation) › AI Assistant › **Prompt for Claude Design — build the MealBuddy prototype**

## How to use this

Copy everything below the divider line into Claude Design. Attach the Figma file. The prompt is self-contained — no other docs needed.

---

# MealBuddy interactive prototype — build brief

Build a single self-contained interactive prototype (HTML + React via CDN, or a React artifact) that walks a stakeholder team through a 5-minute demo conversation between an endurance athlete (Caroline) and an AI meal-planning assistant (MealBuddy). It should render as a mobile phone-shaped prototype and run in any browser without a backend.

The attached Figma file is reference material for layout patterns and component composition. **Ignore** the broccoli mascot and any fridge-scan flow you see in the Figma; those were earlier explorations and are not part of this build.

**Use the design system for everything related to typography, color, spacing, sizing, animation, and visual treatment.** This brief only specifies content, structure, and behavior.

---

## The strategic context (this shapes every decision)

MealBuddy is the meal-planning surface of Mealvana Endurance, a nutrition app for endurance athletes. Performance nutrition (pre/during/post workout fueling) is the hook that brings users in. **Meal planning is the retention driver** — every athlete and coach we interviewed asked for it.

This prototype demos a single weekly meal-planning conversation that uses everything the system already knows about the athlete — training schedule, weather, seasonal produce, this week's grocery deals, household, learned preferences — to land a confirmed plan in under 5 minutes. The intelligence is the differentiator vs. a generic recipe app.

### Three design principles, in priority order

**1. Macro-number-free.** Athletes never see grams or calories. Direction is given through training context ("Thursday post-hill recovery"), sensory cues ("won't sit heavy", "cold sides after a long brick"), and seasonal language ("peaches just hit peak"). The underlying system computes macros internally; the language layer is what users see.

**2. Card-scoped actions live on cards.** Pills are only for conversation-level forks (lock the plan, advance, keep going). Anything that edits a specific item — change servings, swap an ingredient, add to the list — lives on the item's card itself, not in a separate pill row below the message. This applies to meal cards (servings + swap), deal cards (add to list), and any future card-level affordance.

**3. Proactive, not reactive.** MealBuddy doesn't wait to be asked. It opens with training-aware framing, surfaces this week's deals contextually mid-flow, and stitches deals back into meals already confirmed earlier in the same conversation.

---

## The athlete (already-onboarded power user)

```
Name: Caroline
Diet: Omnivore
Avoids: Cilantro
Household: 2 — Caroline (NYC Marathon prep · triathlete) + Wes (partner · eats anything)
Goals: Recovery-aware fueling · Eat with the season
Budget: $85/week
ZIP: 35242 (Birmingham, AL)
Stores: Publix · Aldi
Cooking: Intermediate · prefers 3 cooking sessions/week
Gut training: Intermediate (60–80g carbs/hr)
Training source: TrainingPeaks

This week's training:
  Mon  Easy run · 45 min
  Tue  Swim · 1500m intervals
  Wed  Easy bike · 60 min
  Thu  Hill repeats · 6×400m
  Fri  Rest
  Sat  Long ride · 3 hr
  Sun  Brick · 2hr ride + 45min run

Learned preferences (each with source + date — these appear in Memory drawer):
  - Loves steak after hard training days        · conversation · Apr 19
  - Prefers meal-prep over daily cooking         · conversation · Mar 02
  - Eats Greek yogurt with breakfast             · onboarding   · Jan 10
  - Keeps milk and eggs in the fridge always     · conversation · Apr 28
  - Drawn to peaches and stone fruits in summer  · conversation · May 04
```

---

## The conversation — 8 turns, scripted, linear

The demo is a strictly-linear scripted conversation covering one full week of meal prep — 1 breakfast, 2 lunches, and 3 dinners (matches Caroline's batch-cooking pattern). User actions advance the script. There's no AI — every response is pre-written. Pills, free-text submissions, and card actions all move the state machine forward to the next pre-written assistant turn.

A chat input field is present throughout. By default it shows a placeholder ("type a message…") and is decorative. The one exception is Turn 1 → Turn 2 — see Turn 2 below.

### Turn 1 — Opener

**Assistant message:**
> Hey Caroline. Heat wave through Wednesday, then cooling. Your brick on Sunday means recovery's the theme. Summer squash, tomatoes, peaches just hit peak. Let's plan the week — starting with dinner. What sounds good?

**Pills** (primary = first):
- `Steak` (primary) → advances
- `Light & fresh` → advances (same path for demo simplicity)
- `Surprise me` → advances (same path)

### Turn 2 — Caroline replies (free text)

When the user picks any pill in Turn 1:
- Remove the pill row
- Show a user bubble:
  > Something with steak but I want it to feel summery.
- Auto-advance after a brief delay to Turn 3.

### Turn 3 — Ribeye proposal with on-card serving editor and swap

**Assistant message:**
> Grilled ribeye with chimichurri, paired with a peach and tomato salad. Anchors Thursday's hill repeats and keeps the heat outside the kitchen — grill night.

**Meal card.** Visual structure follows Mealvana's existing meal-card pattern in the live app: one hero photo of the main + small circular component insets overlaid at the bottom-left of the hero, each inset a thumbnail of an accompanying component (side, sauce, etc.). This reflects the underlying data model — a meal is a composition of first-class swappable components, not a single recipe. The Figma reference shows this composition pattern.

Card contents:
- Hero photo: ribeye + chimichurri (URL below — the main image)
- Component insets (overlaid on hero): peach + tomato salad thumbnail, chimichurri sauce thumbnail
- Template label: GRILL + ROAST
- Training context: Thursday · post-hill recovery
- Title: Grilled ribeye + summer salad
- Subtitle: peach, tomato & basil salad on the side
- Serving editor: `[−] 2 [+]`
- Swap action: `⇄ Swap`

**Demo behavior:**
- Tapping `+` increases servings (2 → 3 → 4). Show inline status: *"Updated to 4 — bumping the ribeye and tomatoes on your list."*
- Tapping `⇄ Swap` opens a substitution sheet listing 4 protein options (Tofu, Shrimp, Chicken thighs, Tempeh), each with a one-line note. Picking one closes the sheet and updates the card title (e.g., "Grilled tofu + summer salad"). The user doesn't need to actually swap during the demo, but the affordance must be tappable.

**Pills below the card** (after a brief delay): `Continue` (primary)

When `Continue` is tapped, advance to Turn 4. Auto-advance after a short delay also acceptable.

### Turn 4 — Pair proposal

**Assistant message:**
> For Tuesday's swim — Lemon Herb Chicken with Mediterranean quinoa. Light, hydrating, won't sit heavy. For Sunday brick recovery — Baked Salmon with Capers and a Greek cucumber salad on the side. Omega-3s for inflammation, cold sides after a long brick. Cool with these for dinner?

**Two meal cards** (same hero + component-insets pattern as Turn 3):

Card A — Lemon herb chicken thighs
- Hero photo: chicken thighs (URL below)
- Component inset: mediterranean quinoa thumbnail
- Subtitle: mediterranean quinoa
- Template label: SHEET PAN
- Training context: Tuesday · swim day
- Serving editor: `[−] 4 [+]`
- Swap action: `⇄ Swap`

Card B — Baked salmon, tomatoes & capers
- Hero photo: salmon (URL below)
- Component inset: greek cucumber salad thumbnail
- Subtitle: with greek cucumber salad
- Template label: BAKE + SIDE
- Training context: Sunday · brick recovery
- Serving editor: `[−] 4 [+]`
- Swap action: `⇄ Swap`

**Pills:** `Looks good — what about breakfast and lunch?`

Note: no `Swap one` pill — swap is on each card.

When the pill is tapped → user bubble: "Looks good — what about breakfast and lunch?" → advance to Turn 5.

### Turn 5 — Breakfast + lunches batch

**Assistant message:**
> For breakfast — Creamy Oatmeal with banana, berries and almonds. Batch on Sunday, works pre-swim and pre-ride. For lunches, two to alternate — Sesame Chicken Noodles for the lighter days (packs cold), Jambalaya for the heavier ones (reheats well at the office).

**Three meal cards** (same hero + component-insets pattern):

Card A — Creamy Oatmeal
- Hero photo: oatmeal (URL below)
- Component insets: banana thumbnail, berries thumbnail
- Subtitle: with banana, berries & almonds
- Template label: BATCH PREP
- Training context: pre-training fuel
- Serving editor: `[−] 5 [+]` (weekday breakfasts)
- Swap action: `⇄ Swap`

Card B — Sesame Chicken Noodles
- Hero photo: sesame chicken noodles (URL below)
- Subtitle: pack cold, reheats fine
- Template label: STIR FRY
- Training context: easy training days
- Serving editor: `[−] 3 [+]`
- Swap action: `⇄ Swap`

Card C — Jambalaya
- Hero photo: jambalaya (URL below)
- Subtitle: hearty, reheats well
- Template label: ONE POT
- Training context: heavy training days
- Serving editor: `[−] 2 [+]`
- Swap action: `⇄ Swap`

**Pills:** `Lock the week` (primary)

When `Lock the week` is tapped → user bubble: "Lock the week." → advance to Turn 6.

### Turn 6 — Cooking sessions summary

**Assistant message:**
> Done. Three cooking sessions, your usual rhythm — Sunday afternoon you batch the oats and the ribeye; Monday evening, chicken and jambalaya; Saturday morning, salmon and the noodles.

**Cooking sessions card with three sections:**
- Header label: "YOUR WEEK" · title: "3 cooking sessions"
- Section 1 — "Sunday afternoon":
  - Creamy Oatmeal (breakfast for the week)
  - Grilled ribeye + chimichurri (Thursday · post-hill recovery)
  - Roasted summer vegetable medley (in-season)
- Section 2 — "Monday evening":
  - Lemon herb chicken thighs (Tuesday · swim day)
  - Jambalaya (lunches · heavy days)
- Section 3 — "Saturday morning":
  - Baked salmon, tomatoes & capers (Sunday · brick recovery)
  - Greek cucumber salad (bright, hydrating side)
  - Sesame chicken noodles (lunches · easy days)

Each meal row includes a thumbnail.

Auto-advance to Turn 7.

### Turn 7 — Proactive interactive deal cards (the marquee moment)

**Assistant message:**
> While I have you — two things on sale this week that fit your plan.

**Two deal cards.** Each has its own action button — no pills for this turn.

Deal card 1 — Peaches:
- Food photo (peach URL below)
- Title: Local peaches
- Deal: "25% off — just dropped at Publix"
- Why: "Already in Thursday's salad — bump for grilled side too. Tops the oats too."
- Action: `[+ Add to list]`

Deal card 2 — Asparagus:
- Food photo (asparagus URL below)
- Title: Asparagus
- Deal: "peak season — best price of summer"
- Why: "Top up for Saturday's salmon prep."
- Action: `[+ Add to list]`

**Demo behavior:**
- Tapping `[+ Add to list]` flips the button to `✓ Added` and stops accepting further taps.
- After both are added, append: *"Both added to your Publix list."* Then auto-advance to Turn 8.

This is the most important UX moment of the demo. **The card is the action** — no pill mediates between intent and confirmation.

### Turn 8 — Final lock

**Assistant message:**
> Locked. Six recipes, three cooking sessions — breakfast, lunches and dinners lined up with your training. Peaches and asparagus added. Shopping list ready for Publix. Wes can see it. Your nutrition coach too.

**Final lock card:**
- Cart icon
- Title: "All set for the week"
- Sub: "Shopping list synced · your nutrition coach can see this plan"

No further pills. Demo end state.

---

## Memory drawer — accessible from the header at any time

A "Memory" affordance lives in the chat header. Tapping it opens a drawer from the bottom of the phone, dismissible by tapping outside or via a close button.

**Drawer header:**
- Label: "WHAT MEALBUDDY KNOWS"
- Title: "about you"
- Close button

**Drawer body** (scrollable, sectioned):

```
Section: Profile
  Name      Caroline
  Diet      Omnivore
  Avoids    Cilantro
  Cooking   Intermediate · prefers 3 cooking sessions/week

Section: Household · 2
  Caroline  NYC Marathon prep · triathlete
  Wes       partner · eats anything

Section: Logistics
  Budget    $85/week
  ZIP       35242
  Stores    Publix · Aldi

Section: Training
  Source         TrainingPeaks
  Gut training   Intermediate (60–80g carbs/hr)
  Goals          Recovery-aware fueling · Eat with the season
  ----
  THIS WEEK:
  Mon  Easy run · 45 min
  Tue  Swim · 1500m intervals
  Wed  Easy bike · 60 min
  Thu  Hill repeats · 6×400m
  Fri  Rest
  Sat  Long ride · 3 hr
  Sun  Brick · 2hr ride + 45min run

Section: Learned over time
  - Loves steak after hard training days  · from conversation · Apr 19
  - Prefers meal-prep over daily cooking  · from conversation · Mar 02
  - Eats Greek yogurt with breakfast      · from onboarding   · Jan 10
  - Keeps milk and eggs in the fridge always · from conversation · Apr 28
  - Drawn to peaches and stone fruits in summer · from conversation · May 04
  Each item has an "edit" affordance.

Footer: "Updated automatically · edit anything · clear anything"
```

The Memory drawer is the *trust layer* — a record of what the system knows about the athlete.

---

## Image URLs (Unsplash)

Use these exactly. They work without auth and have reliable CDN delivery.

```
ribeye      https://images.unsplash.com/photo-1558030006-450675393462?w=900&q=80&auto=format&fit=crop
veg medley  https://images.unsplash.com/photo-1540420773420-3366772f4999?w=900&q=80&auto=format&fit=crop
chicken     https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=900&q=80&auto=format&fit=crop
salmon      https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=900&q=80&auto=format&fit=crop
greek salad https://images.unsplash.com/photo-1540420773420-3366772f4999?w=900&q=80&auto=format&fit=crop
oatmeal     https://images.unsplash.com/photo-1517673400267-0251440c45dc?w=900&q=80&auto=format&fit=crop
sesame      https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=900&q=80&auto=format&fit=crop
jambalaya   https://images.unsplash.com/photo-1611273426858-450d8e3c9fce?w=900&q=80&auto=format&fit=crop
peaches     https://images.unsplash.com/photo-1629828874514-9b1ca5b58c3a?w=900&q=80&auto=format&fit=crop
asparagus   https://images.unsplash.com/photo-1515471209610-dae1c92d8777?w=900&q=80&auto=format&fit=crop
```

If any URL fails to load, show the dish name as a fallback.

---

## State machine — simple linear advance

```
start → Turn 1 (opener pills shown)
        ↓ user taps any pill
      Turn 2 (user bubble appears, brief delay)
        ↓ auto-advance
      Turn 3 (assistant + ribeye meal card)
        ↓ user taps Continue (or auto-advance)
      Turn 4 (assistant + 2 dinner cards)
        ↓ user taps `Looks good — what about breakfast and lunch?`
      Turn 5 (assistant + 3 cards: breakfast + 2 lunches)
        ↓ user taps `Lock the week`
      Turn 6 (assistant + cooking sessions card)
        ↓ auto-advance
      Turn 7 (assistant + 2 deal cards with on-card add buttons)
        ↓ user taps both `+ Add to list` (in either order)
        ↓ auto-advance after both added
      Turn 8 (assistant + final lock card)
        end — demo complete
```

Memory drawer is independent of this state machine — it can be opened or closed at any point without affecting conversation state.

A "Restart demo" affordance outside the phone clears all messages and resets to Turn 1.

---

## Things deliberately NOT in this prototype

- **No mascot avatar.** The MealBuddy identity is text-only (a single-letter monogram is acceptable, but no characters or illustrations)
- **No fridge-scan or photo-attachment flow.** Caroline does not upload photos in this build
- **No performance-fueling content.** No race-day gels, no during-workout fueling templates, no product catalog. That feature lives in a separate part of the app and is out of scope here
- **No snacks.** Breakfast, lunch, and dinner only
- **No macro numbers visible to the user.** No grams, no calories, no "match %" badges. The system uses these internally but they don't surface in the UI
- **No coach dashboard view.** The plan is mentioned to be visible to the nutrition coach in Turn 7 text, but there's no coach screen built
- **No real backend.** All data is hardcoded in the prototype

---

## Output format

A single self-contained interactive prototype. Either:
- One HTML file with React via CDN + Tailwind via CDN, or
- A single React `.jsx` artifact

No build step required. Should run on any modern browser without configuration.

---

## What success looks like

A stakeholder watching this demo for 5 minutes should walk away thinking:
- "This isn't a recipe app — it's an athlete's planner."
- "It knows things ChatGPT couldn't possibly know."
- "The interactions feel right — actions live where they should."
- "I want to use this on my own training week."

If any of those feel off after a test run, prioritize fixing the cards and the deal-card moment first — those are the highest-leverage details.

---

## Comments / discussion threads

None found (no discussion markers returned by `notion-fetch` with `include_discussions: true`).

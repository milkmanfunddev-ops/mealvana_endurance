---
title: Top Inspiration Picks + Outside-the-Box Directions — Meal Planning Prototype
generated_date: 2026-05-06
summary: >
  Quick-scan companion to 01_meal_planning_landscape.md. Five concrete UX moves to steal,
  three directions no existing app does well.
---

# Top 5 Inspiration Picks + 3 Outside-the-Box Directions

## Top 5 Picks

---

### 1. Fuelin Smart Meals — Context-Aware Card Generation (not chatbot)

**The move to steal:** The app detects where you are (home / restaurant / road) and silently generates 3 meal option cards, each aligned to your current training-day macro targets. Zero chatbot interaction. User taps one card — done.

**Apply to Mealvana:** For each meal slot, generate 2–3 "assembly cards" formatted as "[Protein] + [Carb] + [Veg] + portions" based on the day's training load pulled from Garmin/TrainingPeaks. No recipes. No steps. Just components + quantities.

Source: [Fuelin Smart Meals](https://endurance.biz/2025/industry-news/fuelin-launches-ai-powered-smart-meals-for-endurance-athlete-nutrition/)

---

### 2. Hexis Carb Coding + Color System — Visual Training-Day Signal

**The move to steal:** A clear daily color code / banner at the top of the plan view tells the athlete at a glance whether today is a high-carb, moderate-carb, or low-carb day based on training intensity. Removes all ambiguity before the user even opens a meal slot.

**Apply to Mealvana:** Render a daily training context header ("Hard Day — 240g carbs, 170g protein" vs "Rest Day — 130g carbs, 160g protein") derived from the already-synced Garmin workout data. This primes every meal decision in the plan with the right context.

Source: [Hexis Athlete App](https://hexis.live/athlete-app)

---

### 3. RP Diet Coach — Column-Selection Meal Builder (food lists, not recipes)

**The move to steal:** Each meal slot shows three columns: Proteins / Carbs / Vegetables. Each column lists 4–6 pre-filtered options with portions (e.g., "6 oz chicken breast / 4 oz salmon / 5 oz turkey"). User picks one item from each column. The AI pre-filters the lists based on training day, user preferences, and dislikes. No recipes exist in this flow.

**Apply to Mealvana:** Build the primary meal-building UI as a column-picker rather than a recipe browser. AI curates the short lists. User selects. Simple assembly instructions ("Cook and combine") appear only if requested.

Source: [RP Diet Coach — Screens Design](https://screensdesign.com/showcase/rp-diet-coach-meal-planner)

---

### 4. Eat This Much — Generate → Selective Swap Loop

**The move to steal:** Generate the complete week in one shot. Any individual meal slot can be regenerated independently — one tap, no context re-entry, no full-week redo. The plan is mutable and fast to iterate.

**Apply to Mealvana:** The "Plan my week" action should produce a complete 7-day grid instantly, using training calendar data for carb periodization. Each meal slot has a single-tap regenerate button. User preferences and dislikes persist silently — no need to re-enter them. The week "locks" as the user confirms each day.

Source: [Eat This Much Review 2026](https://www.promealplan.com/en/blog/eat-this-much-review-2026)

---

### 5. HelloFresh Label System — Scan-and-Decide Cards

**The move to steal:** Every meal card carries 3–4 scannable labels that enable a decision in under 10 seconds: training intensity tag ("Hard Day Fuel"), macro summary ("52g protein / 180g carbs"), assembly time ("5-min"), and cuisine hint ("Asian bowl"). Users make choices by scanning labels, not reading detail views.

**Apply to Mealvana:** Each assembly card in the weekly grid renders: training-day tag + protein/carb gram summary + estimated assembly time + main ingredient label. Tapping a card shows full portions; not tapping is fine because the labels provide enough information to accept or swap.

Source: [HelloFresh vs Blue Apron 2025](https://mealbakery.com/blue-apron-vs-hellofresh/)

---

## 3 Outside-the-Box Directions

---

### Direction 1: The Repeating Template System (Reuse Over Variety)

Athletes eat the same 8–10 foods repeatedly by design. No app supports this. Build a "My Rotation" feature: the user defines their 5–8 go-to component assemblies (e.g., "Hard Day A: chicken / rice / broccoli," "Easy Day: salmon / quinoa / spinach"). The AI auto-schedules these against the training calendar and suggests minor sauce/spice variations — not new meals. Grocery list stays predictable: 15–18 items, same every week. This is the polar opposite of every existing meal planner's "variety-first" design, and it's what high-mileage athletes actually want.

---

### Direction 2: Race Calendar Phasing (Season-Long Nutrition Arc)

No app phases nutrition across a full training season. Connect to the race calendar and automatically phase: base training (fat adaptation focus), build phase (carb ramping), taper (volume down, carb density maintained), race week (systematic carb loading), race day (timed carb protocol), recovery week (protein-forward repair). The AI generates phase-appropriate plan variants and explains the rationale. MAVR has a race-day calculator; nobody has the full season arc.

---

### Direction 3: Living Meal Plan — Intra-Day Adaptation

The meal plan adapts to what already happened today, not just what training is scheduled. Logged morning meal was 40g carbs over target? Afternoon automatically adjusts. Athlete taps "I'm drained" in a 3-button check-in? Recovery macros kick in. Training shifted from rest to hard run? The day restructures. The plan is a live document, not a Sunday-set-and-forget schedule. This requires real-time state management but turns the planner from a planning tool into a daily nutrition copilot.

---

## One-Line Design Principle (from this survey)

Every existing meal planner solves either "what to cook" (recipe-based) or "how many macros" (tracker-based). Mealvana's opportunity is to solve "what to eat today, given today's training" — and do it without recipes or chatbots, using simple ingredient assemblies that any athlete can execute in 5 minutes.

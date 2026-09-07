# Meal Planning Feature — 1st + 2nd Round Interview Insight

Source: https://app.notion.com/p/372e3fdb754c8031b6defffe64eb6ac5
Parent: Interview Synthesis (database) → 🛠️ Product & Engineering
Round: Round 1 + 2 | Status: Final
Feature Area: Meal Planning, Shopping List, AI / Coaching
Last edited/viewed: 2026-06-01 / 2026-06-04

**Headline Recommendation (property):** Build a diagnose-and-add product (not generate-a-plan), primarily button-driven with embedded chat for AI-native users, shopping list as the killer feature, anchored to time-of-day, framed around performance/minimums for clinical safety, competing against meal kits on friction.

## Comments on this page (unresolved, inline)
1. On section "5. Time-of-day anchoring" — xh.analytics@gmail.com, 2026-06-01T14:01: **"I push back on this a little"** (no further reply visible/resolved)
2. On section "8. Ingredient-level swap" — xh.analytics@gmail.com, 2026-06-01T14:02: **"I push back on this"** (no further reply visible/resolved)

## The five things to build around

### 1. Diagnose-and-add as the primary flow, not generate-a-plan — STRONG
Biggest single finding across the whole research project. Both prototypes assumed the product creates a week from scratch. Four independent data points say the better model is "tell me what you already eat, tell me what's missing, suggest additions."
- **Landon**: *"I wouldn't want it to create a whole new thing... if there were an assistant that would use the current context of what I eat already and to spice it up."*
- **Madhu**: picked Option B by behavior — already used a chat AI to optimize her existing eating, not build new plans.
- **Isidoro**: *"Option B by far. I don't have that much time, so I would like the app to tell me how can I optimize what I already do."*
- **Rachel**: her actual professional workflow (as a dietitian) is reviewing a few days of food diary and suggesting additions. Refuses to do prescriptive plans for clinical reasons.
- Even Rhonda's pattern (same staples on rotation) fits diagnose-and-add better than generate-a-plan.

**Product implication:** Sunday-morning core loop = *"tell me what you ate the last few days"* → *"here's what's missing for the kind of week you have ahead"* → *"add these specific things at these specific moments."* Not "here's your 21-meal grid."

### 2. The shopping list is the moment of value, not the meal plan — STRONG
Across nearly every Round 1 participant, the shopping list moment was the strongest positive reaction in the entire interview.
- **Anna**: *"lowers the activation energy of making a list."*
- **Jeff**: *"If the app actually creates a shopping list, I'm totally sold."*
- **Eric**: *"send to Publix."*
- **Ashley**: *"can you do a pickup order?"*
- **Cherie**: noticed the Aldi/Publix dual-store option specifically.

People don't open meal planners to plan meals — they open them to know what to buy. The plan is the input; the list is what gets used.

**Product implication:** If cutting every other feature, ship the shopping list — auto-generated from inferred eating patterns, organized by store and aisle, with grocery pickup integrations shipped as fast as possible. The plan view exists; the list view is sacred.

### 3. The product takes a position on disordered-eating safety — EMERGING, well-grounded
- **Rachel** (clinical authority): explicitly refuses prescriptive meal planning due to disordered-eating risk. *"I like to be very careful around giving specific amounts."* Logging is *"something I'm never going to recommend"* for regular use.
- **Madhu**: recovered macro-tracker. *"I was very much like the person who was very obsessed with weight... right now is how do I eat?"* Actively rejects the macro display.
- **Rhonda**: explicitly wants weight loss as primary goal. *"If I want to lose 4 to 5 pounds, literally that's my goal right now."*

Together: disordered-eating risk is real in this population, including users who *want* to lose weight. Ignoring it doesn't protect users; the product has to take a position.

**Product implications:**
- Defaults: Minimums, never maximums. "Hit at least X grams of protein," never "consume exactly X."
- Framing: Performance and adequacy, never weight — even for users with weight goals, frame as muscle-mass/protein-adequacy, not deficit.
- Macros: Visible on demand, off by default in the daily experience.
- Logging: Available for specific high-value use cases (carb-load week, troubleshooting GI issues), not the daily core loop — expert-level/situational.
- Get Rachel's explicit input on positioning language before launch — potentially a clinical-advisor relationship worth formalizing.

### 4. The real competition is meal kit services, not nutrition apps — STRONG
Anna pays for Cook Unity, Home Chef, and EveryPlate. Madhu cited similar services. Several participants have outsourced the planning problem entirely. None of the participants cited MyFitnessPal or Fuelin as direct competition.

**Product implication:** Every design decision evaluated against "does this reduce the activation energy to eat well?" Diagnose-and-add, time-of-day anchoring, shopping list, ingredient-swap all reduce friction. Macro-tracking, logging, plan customization add friction. Lean hard into the first set.

### 5. Time-of-day anchoring, not meal-category anchoring — STRONG (Rachel + multiple users) *[commented — pushback noted above]*
Rachel: *"Between breakfast and lunch, add this in. Maybe you like this snack, add this in around 3pm, this is gonna get you through your evening run."* Multiple users described eating in time-and-context terms ("after the long run," "before kid pickup") rather than meal-category terms.

**Product implication:** Plans, reminders, and recommendations organized around the user's day shape — wake time, training window, work blocks, family events — not breakfast/lunch/dinner slots. UI decision with ripple effects through the data model.

## Three tier-two takeaways

### 6. Segment the interaction model: chat for some, button for others — EMERGING
3 of 3 heavy daily AI users picked the conversational vignette (Landon, Madhu, Isidoro). 4 of 7 others picked button-driven, including Rhonda — a daily AI user, breaking the clean segmentation hypothesis. Pattern is directional, not categorical.

Rather than force one paradigm: button-driven default with a "chat with the assistant" affordance available. Don't try to convert button-preferrers to chat; don't make chat the only entry point.

**Product implication:** Primary surface is button-driven (Mealvana-style). Chat is an embedded refinement layer for users who prefer it. Matches Landon's design constraint: chat is words, structured data lives in the regular UI.

### 7. Component-based eating with recipe discovery as the "stuck" feature — STRONG
6 of 8 lean component-based ("protein + carb + veggies" or "bowls"). Cherie and Madhu lean recipe-driven. Even Rachel (cookbook author) defaults to components and Googles when stuck.

**Product implication:** Default to component thinking ("here's your protein for the week, your carb, your veggies, your sauces"). Recipes surface as discovery when users want variety. "What can I make from these tonight?" is a feature; "follow this 7-step recipe" is rarely what users actually do.

### 8. Ingredient-level swap is the missing feature — EMERGING *[commented — pushback noted above]*
Multiple participants asked for it unprompted. Both prototypes only offered meal-level swap. "Can I swap almond milk for oat milk?" "Can I swap salmon for chicken?" "Can I add a veggie to this meal?"

**Product implication:** Swap operates at ingredient level, not just meal level. Ingredient substitution should auto-recalculate macros and shopping list.

## What NOT to build
- Don't build a 21-meal weekly grid as the primary surface. Both prototypes assumed this; data says it's wrong as the default.
- Don't make macros the daily core experience. Visible on demand, off by default.
- Don't position around weight loss. Even for users who want it (Rhonda), the safe frame is muscle/protein/performance.
- Don't try to replace nutritionists. Position as augmentation — Rachel-style professionals are channel partners, not competitors.
- Don't make logging the daily loop. Carb-load week, troubleshooting GI, race prep — that's it.
- Don't optimize the race-day calculator for numerical precision. Default to action; precision is opt-in.

## Single-source insights worth carrying forward
- **Cost matters as a fueling constraint** (Isidoro). Surfacing budget alternatives (maple syrup, honey, homemade vs. branded gels) could be a feature.
- **Seasonal/weather fuel substitution** (Isidoro). Granola bar doesn't work at 100°F; rice cake doesn't either. A weather-aware fuel-format suggestion is a small feature with real value.
- **Daily hydration recommendations outside workout windows** (Isidoro, Alabama summer context).
- **Diabetes/insulin-spike concern from high-carb fueling** (Isidoro). One anecdote — worth a literature review with Rachel before next major feature ship.
- **Empty-nester athlete demographic** (Rhonda). Different from younger participants — worth a deliberate persona definition.
- **The "I tried meal planning and stopped because life got busy" failure mode** (Madhu). Retention design has to survive busy life, not assume disciplined users.

## The biggest open question
What does the actual diagnose-and-add output look like as a daily artifact? Rachel's "notes, not templates" sets the direction. Landon's "chat words, data separate" gives the interaction principle. But the research hasn't shown users a reaction to what the actual output of a diagnose-and-add product looks like on day 3 of using it. This is what the next prototype needs to test — not another research round, the actual artifact.

## One last frame
The two prototypes (Plan A button-driven, Plan B conversational) framed the choice as a UI fork. The synthesis says the real product question was the *underlying model* (diagnose-and-add vs. generate-a-plan), and the UI fork (button vs. chat) is secondary segmentation on top of that. Neither prototype tested the right primary question.

> "If I had to summarize in one sentence: build a diagnose-and-add product, primarily button-driven with embedded chat for the AI-native segment, with the shopping list as the killer feature, anchored to time-of-day rather than meal-category, defaulting to performance-and-minimums framing for clinical safety, competing against meal kits on friction."

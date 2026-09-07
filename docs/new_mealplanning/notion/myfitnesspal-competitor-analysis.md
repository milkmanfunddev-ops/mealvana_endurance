# MyFitnessPal competitor analysis

- **Source URL:** https://app.notion.com/p/35de3fdb754c803e9ec8c332884105d8
- **Parent/ancestor path:** 🛠️ Product & Engineering → MyFitnessPal competitor analysis
- **Fetched (Notion "as of" timestamp):** 2026-05-11T03:35:14.547Z
- **Analysis basis note (from page footer):** Based on walkthrough of MyFitnessPal iOS app, May 2026. Premium account, Garmin + Strava connected, 14-day food diary populated. Captured across Today / Plan / Progress / Coach tabs plus the profile drawer and Goals subpages.

## Executive Summary

**Context.** MyFitnessPal (MFP) is the dominant general-population calorie-tracking app — 14M food database, integrated barcode / voice / photo logging, an active community forum, and a newly launched AI Nutrition Coach. They've shipped meaningful AI investments and continue to lead on logging friction.

**Headline finding.** MFP's product is exceptionally well-built for the general-population, weight-management use case. It is structurally weak for endurance athletes — not because the AI or UX is bad, but because the domain model underneath is generic. Nutrition targets are anchored to weight goals, sodium is sedentary-level (2,300 mg), "during-workout fueling" is absent as a concept, weight is the primary outcome metric, and there is no coach-facing surface anywhere in the app. *This is the gap that justifies a dedicated endurance product.*

## Five highest-leverage takeaways

1. **Domain depth is the moat, not AI.** MFP has shipped competent AI tooling: visible tool calls, RAG over the user's food diary, multi-turn conversation, correct per-day calorie math. What's missing is the sports-science layer beneath it. Their AI recommended 30–60 g carbs/hr for a 20-mile run; modern research (Jeukendrup, Burke, ISSN 2017+) is 60–90 g/hr with multiple transportable carbohydrates. **Mealvana wins by being domain-correct, not by being AI-first.**
2. **MFP partially has periodization** via day-of-week Custom Daily Goals — but it's manual, doesn't adapt to actual training load, doesn't integrate with the connected Strava / Garmin data, and has no within-day timing. Positioning refinement: *"Mealvana auto-adjusts to training state"* — not *"we have periodization, they don't."*
3. **No coach-facing surface anywhere in the app.** Confirms the structural opening for the B2B2C thesis. Coaches who want to verify and shape what their athletes eat have zero MFP affordance — not for assignment, not for review, not for accountability.
4. **The recent MFP redesign is unpopular.** Active community thread with 28+ comments titled *"anyone else hate the new diary layout and think it's more difficult to navigate."* User trust around UX changes is fragile right now — possible competitive moment for capturing migrating users, especially those who want a sport-specific alternative.
5. **Pricing signals are clear and useful for Mealvana monetization.**
   - **Calorie Goals By Meal** is paywalled (Premium) → users will pay for per-meal structure
   - **Meal Planner** (week of meals planned for you) is paywalled (Premium Plus) → top-tier hook is automated planning
   - **GLP-1 Support** is in beta → MFP is leaning into the highest-growth nutrition vertical right now
   - The training-state versions of these features (per-fueling-window calorie goals, training-aware weekly planning) are stronger and more defensible for endurance

## Patterns worth borrowing for Mealvana product design

Consolidated from across all tabs.

- **Universal "+" FAB** on every tab with tiered quick-add (food → barcode → voice → photo, then water / weight / exercise)
- **Voice log with natural-language parsing** as a primary entry point, not buried in a menu
- **Save Meal / Copy From / Copy To** for repeat fueling stacks — athletes eat similar things, especially on training days
- **Visible tool-use cards** in the AI Coach — transparency builds trust
- **Persistent quick-action chips + dynamic suggested follow-ups** in chat — eliminates cold-start typing
- **AI-generated personalized weekly insight** at top of Progress (Mealvana's version is sports-science-grounded)
- **"Foods Highest In X" drill-down** — Mealvana's version: *"Foods that powered your long run"*
- **Per-meal calorie / protein labeling** in meal plans — transparency by default
- **Three-tier taxonomy** Recipe → Meal → Plan — we adopt as Recipe → Fueling Stack → Training Block Plan
- **Standing disclaimer** in AI chat footer (appropriate for any sports nutrition AI)
- **Email-verified data export gate** — natural fit for coach licensing: *"share my Progress with my coach"*
- **Empathic, action-oriented copywriting** — *"Fuel your goal today"*, *"Great day — you've logged more than usual"*

## Validated for Mealvana's existing roadmap

- The **Nutrition Transparency UI's progressive disclosure** approach is the right answer — MFP's Goals page is a cautionary tale on settings sprawl (*"too much control… really clunky"* — Xuan)
- The **MealBuddy / AI assistant work** is the right competitive surface — MFP has shown what good looks like and where the domain gaps are
- **Coach as distribution channel** remains structurally defensible — MFP hasn't built a coach surface and is unlikely to without abandoning the general-population positioning

---

# Tab 1 — Home (Today)

## Purpose

The default landing screen. Daily snapshot of energy balance (calories in vs. out) with macros and a meal-by-meal diary. Everything else (history, search, exercise, water, profile, community) is one tap from here. This is MFP's core loop: **see your day → log → close the day.**

## Top-level information architecture

- Sticky day header: "Today" dropdown + horizontal weekday strip (S M T W T F S) with checkmark on logged days
- Streak indicator (⚡) and profile avatar top right
- **Calorie card** (consumed / goal / remaining, with fire emoji on adjusted goal)
- **Macro card** (Carbs / Fat / Protein, gram + progress bar, swap icon to toggle gram/percent view)
- **Diary** list (Breakfast / Lunch / Dinner / Snacks — each with Log button + overflow menu)
- Floating "+" for universal add
- Bottom nav: Today / Plan / Progress / Coach
- "Complete diary" overlay button to finalize the day

## Key features

**Calorie & macro target engine**
- Pulls workout calories from Strava + Garmin and inflates daily goal (Xuan's day: 4,888 cal — clearly endurance-volume territory)
- Macro targets recalculate proportionally with calorie goal (612 g carbs / 162 g fat / 245 g protein at 4,888 cal — roughly 50/30/20 split)
- Macros displayed in grams by default; toggle to percentage view

**Meal logging entry points from Today**
- Search (foods / brands / flavors) with All / My Meals / My Recipes / My Foods filters
- Barcode scan (their long-standing strength — 14M food database)
- Voice log (worked first try: "4 oz beef, 1 cup cooked rice" → parsed correctly into two line items with macros)
- Meal scan (photo recognition)
- Quick add (manual macros, no food name)
- History: most-recent logged items with one-tap re-add

**Meal detail view (Breakfast example)**
- Donut chart with calorie center + macro split (48% / 24% / 28%)
- Per-item rows with calorie subtotal and verified badge (green shield) on database-confirmed foods
- Actions: **Copy from**, **Copy to**, **Save meal** (turn this combo into a reusable meal)

**Recipe & custom food creation**
- My Meals: combine logged items into a named meal with photo + ingredients + instructions
- My Recipes: create from scratch or import from URL (recipe scraping — failed on one attempt during the demo, so reliability is inconsistent)
- My Foods: create custom foods when the 14M database misses (requires manual macro entry)

**Healthy Habits / supporting trackers**
- Water: simple "Log water" with friendly empty state — no sodium, electrolytes, or hydration target
- Exercise: imported from Garmin + Strava with duration and calorie burn
- **Bug noted:** same workout appears twice when both Garmin and Strava are connected (no de-duplication). Visible in screenshot — Bicycling 16-20 mph logged at 130 min / 1,383 cal *and* 122 min / 1,383 cal
- Steps, Weight (current / start / change / goal), Notes diary

**Profile drawer (top-right person icon)**
- My Premium, My Profile, GLP-1 Support (Beta), Intermittent Fasting, Sleep, Recipe Discovery, Workout Routines, Goals, Weight & Measurements, My Weekly Report, Nutrition, My Meals/Recipes/Foods, Reminders, Apps & Devices
- Account shows Streak, Progress (lbs lost), username, Premium status
- **Weekly Digest ("Food Insights" beta)** categorizes logged foods into Nutrition Superstars (vegetables), Full of Fiber (fresh fruits), Nutrition Powerhouses (proteins) — gamified positive-reinforcement framing

**Community**
- Web-embedded forum (literally renders the myfitnesspal.com webview inside the app — visible "myfitnesspal" header bar)
- Chit-Chat sub-forum has active threads (e.g., one with 28 comments in <24 hrs about the new diary layout being a downgrade)
- Strong engaged user base, but **UX tension**: the recent redesign is generating community backlash

## Strengths

1. Voice log accuracy — natural-language parsing into two line items with macros worked first try
2. 14M food database + barcode — still the moat, especially for packaged goods
3. Universal "+" + multiple log entry points — minimizes friction to capture, which is the whole game for retention
4. Copy from / Copy to / Save meal — repeat-meal flow is well-thought-out
5. Verified food badges — trust signal for database accuracy
6. Garmin + Strava integration — data is flowing (even if de-duplication is broken)
7. Macro % vs. gram toggle — accommodates both flexible-dieting and gram-counting users
8. Active community — high engagement, organic content, free retention

## Endurance-specific gaps (our wedge)

- **No fueling timing.** Calorie goal is a single daily number. No pre-workout window, during-workout fueling, or post-workout recovery window — the *entire* basis of endurance nutrition
- **No sodium / electrolytes.** Water is a binary "did you drink?" check, no sweat-rate, no sodium target, no hydration plan
- **No during-workout carb targets.** 60–90 g carb/hr fueling is invisible
- **Workout-adjusted goal is naive.** Bulk-adds Strava+Garmin burn into a single daily allowance rather than partitioning around the session
- **No periodization.** A hard interval day and a recovery day look identical in MFP
- **No coach view.** Zero accountability layer for an endurance coach to verify whether their athlete actually fueled the long run

## General UX weaknesses

- De-duplication bug for Strava/Garmin double-counting is unfixed — high-trust failure for serious athletes
- Recipe importer is unreliable (failed on first attempt in the demo)
- Community is a webview, not native — feels grafted on
- Recent redesign is unpopular (28+ comment thread literally titled "anyone else hate the new diary layout") — fragile user trust around UX changes, possibly a competitive moment
- Goals page is overwhelming — separate flows for weight, calorie, macro, by-meal, additional nutrients, fitness, exercise calories — no progressive disclosure

## Patterns worth borrowing

- Voice log as a primary entry point (not buried in a menu)
- Save Meal from a logged combination (athletes repeat fueling stacks)
- Calorie goals by meal (Mealvana version: by fueling window — pre / during / post / between)
- Macro % toggle so coaches and athletes can speak both languages
- Weekly Digest gamification framing with positive categories (Mealvana version: "Pre-Race Ready," "Recovery Champion," etc.)

---

# Tab 2 — Plan

## Purpose

The discovery and organization layer for what you *might* eat — recipes (inspiration), custom meals (your own combos), and meal planning (paywalled). Distinct from Today's logging-of-what-you-*did*-eat. Today is the retrospective tracker, Plan is the prospective library / meal-planning surface.

## Top-level information architecture

- "Plan" header
- **Hero card** "Discover new dishes — Easy, tasty recipes you can make and enjoy today" with **"Make something new"** primary CTA (links to recipe browse)
- **My Recipes** — Individual dishes you've saved or created
- **My Meals** — Multiple dishes you've saved and logged together
- **Meal Planner** — *"Let us plan up to a week of meals for you"* (🔒 paywalled, Premium Plus only)
- Bottom nav: Today / Plan / Progress / Coach + floating "+"

## Key features

**Discover (recipe browse)**
- Curated recipe collections from various sources, organized by category
- Observed categories: **High Protein, GLP-1, Plant-Based, Mediterranean, Women's Health** (and more)
- "View more" pagination within each category
- **No search bar on the Discover page** — notable gap, browse-only
- Calls back to current macro/wellness trends (GLP-1, women's health) — MFP is actively curating for trending personas
- **Endurance lens:** no "Pre-Long-Run," "Race Morning," "Recovery," "Race Week Carb Load," or "Training Block" categories. The taxonomy is condition / lifestyle-driven, not training-state-driven

**My Recipes (custom recipe creation)**
- Three entry points side-by-side: **Create recipe / Discover / Import**
- Create recipe flow: title + servings → bulk import ingredients (optional) → search ingredients via the 14M database → save
- Search returns multiple variations of the same food (e.g., "4 eggs," "4 scrambled eggs," "4 grade-A eggs," "generic large eggs," "whole large eggs") — large database, but **disambiguation burden is on the user**
- One recipe (Egg Stir Fry, 80 cal, 1 serving) showed inconsistency with the entered servings — possible save bug or unclear UI

**My Meals (combo meals)**
- Saved combinations of multiple logged items (e.g., "Tuesday breakfast = oatmeal + banana + peanut butter")
- Reusable as a single log action — same concept as Save Meal in Tab 1
- Same database + entry pattern as recipes

**Meal Planner (paywalled — Premium Plus)**
- Promises to "plan up to a week of meals for you"
- Not accessible without Premium Plus
- Suggests MFP positions automated meal planning as their highest-tier value
- **Endurance lens:** this is the closest analog to what Mealvana does end-to-end, and MFP gates it behind their top tier — signals (a) it's expensive to power, (b) it's their premium retention hook. Worth a separate paid-account teardown later

## Strengths

1. Hero CTA framing leads with the *enjoyment* benefit, not the macro tracking benefit
2. Persona-aware categories in Discover (GLP-1, Women's Health) — MFP is listening to where the market is moving
3. Bulk import option for recipe creation
4. Clear taxonomic separation: Recipe (one dish) vs. Meal (multiple dishes logged together) vs. Plan (a week of meals)
5. Same database powers everything — recipe ingredients, meal items, direct logging

## Endurance-specific gaps

- **No training-state categories.** Discover has no "Pre-Long-Run," "Race Morning," "Recovery," "Race Week," or "Hard Day vs. Easy Day" buckets. Endurance fueling is inseparable from training state — MFP treats nutrition as a static lifestyle choice
- **No periodized planning.** Even the paid Meal Planner promises a generic week of meals, not a plan that adjusts to a training calendar
- **No fueling-window concept.** Recipes have no metadata for "good as pre-workout 90 min before" or "post-workout within 30 min"
- **No race-day execution.** No countdown, no pre-race carb-load plan, no during-race fueling stack templates
- **No coach-side.** No view for an endurance coach to assign meal plans to athletes

## General weaknesses

- No search on Discover — significant for a recipe library
- Disambiguation friction: too many near-duplicate database entries
- Meal Planner paywalled — the most interesting feature is invisible to most users
- Possible save bug observed (servings count discrepancy)
- No connection between Plan and Today beyond logging — saved recipes don't auto-suggest based on today's calorie remaining or upcoming workout

## Patterns worth borrowing

- Hero-card pattern with enjoyment framing — Mealvana version: "Fuel your next session" or "Ready for Saturday's long run?"
- Persona-aware Discover categories → training-state categories: Pre-Workout, During-Workout, Recovery, Race Week, Easy Day, Long Run, etc.
- Three-tier taxonomy (Recipe → Meal → Plan) → Recipe → Fueling Stack → Training Block Plan
- Bulk import for recipe creation
- Premium Plus gating of automated planning — confirms WTP tier for "do the planning for me"

## Strategic read

The Plan tab is where MFP's general-population positioning is most exposed. They treat meal planning as a lifestyle / weight-management feature, not a performance / periodization feature. For Mealvana, this is the most direct competitive surface — and MFP's decision to paywall their version (and still keep it generic) is a structural opening. The endurance niche needs the *opposite* of a generic meal planner: it needs a planner that knows what's on Strava/TrainingPeaks tomorrow and adjusts today's fueling accordingly.

---

# Tab 3 — Progress

## Purpose

The retrospective analytics layer. Where Today is "what's happening right now" and Plan is "what could I eat," Progress is "how have I been doing." It's where MFP makes the case for the value of all the tracking work the user has done — through trends, averages, behavioral nudges, and (importantly) AI-generated weekly insights.

## Top-level information architecture

Horizontally scrolling sub-tab bar:
- **Overview** — AI insight + summary cards for Calories, Weight, Macros, Reports
- **Calories** — detailed daily/period breakdown with pie chart by meal, net calorie math
- **Nutrients** — 12+ nutrients in Total / Goal / Left table format
- **Macros** — pie chart + carb/fat/protein vs. goal, Foods Highest In drill-downs
- **Steps** — bar chart + per-day entries, avg/best/total summary
- **Weight** — line chart + entries log
- **Sleep** (not deeply demoed)
- Export / Share icon top-right, gated behind email verification

## Key features

**Overview — AI insight card ("Sunday's insight")**
- Personalized, time-stamped to current day of week
- LLM-style generated copy: "A fresh log today can restart your streak. It's been a few days since your last entry. One quick log today brings your pattern back into focus. Log a meal now, then check in tomorrow…"
- **"Tell me more"** CTA implies deeper conversational thread
- Purpose is clearly retention: re-engage lapsed users by reframing a gap in logging as a recoverable problem
- Tone: empathic, non-judgmental, action-oriented

**Overview — summary cards**
- **Calories card**: 7-day average + weekly bar chart with day-of-week labels
- **Weight card**: Start / Current / Change with date stamp, empty-state CTA
- **Macros card** (Carbs / Fat / Protein, each with):
  - Color-coded label
  - One-line behavioral nudge in natural language ("Go for fruit and whole grains to bring your average up today", "Great day, you've logged more than usual and still under goal", "Fuel your goal today from a variety of sources, it all adds up")
  - 7-day average + mini-bar chart with end-points highlighted
- "Manage my goals" link
- Reports → Weekly Digest

**Calories sub-tab**
- Day View toggle with prev/next arrows for date navigation
- Pie chart of calorie distribution by meal
- Three metrics: Total / Net / Goal
- Foods Highest In Calories drill-down
- Export button top-right
- **Endurance lens:** the Net Calories metric of −2,476 on a day with a 2-hour bike ride looks like a catastrophic deficit on screen — when it's actually a normal training day. MFP doesn't contextualize this; an athlete looking at it would feel either alarmed or confused. The framing assumes "deficit = good (weight loss)" or "deficit = bad (under-eating)" — both wrong for performance fueling

**Nutrients sub-tab**
- Clean three-column table: **Total / Goal / Left** for each nutrient
- 12+ nutrients tracked with mini progress bars
- Macros: Protein, Carbohydrates, Fat
- Fiber, Sugar
- Sub-fats: Saturated, Poly, Mono, Trans
- Cholesterol, Sodium, Potassium (and more below the fold)
- **Endurance gaps:** Sodium goal is 2,300 mg (US FDA general-pop guideline). An endurance athlete sweating moderately can lose 1,000–1,500 mg/hr — meaning a single long run blows past the "goal" before lunch. No sweat-rate calibration or workout-adjusted sodium target. No magnesium, no calcium, no caffeine, no iron-in-mg (critical for female endurance athletes)

**Macros sub-tab**
- Pie chart with 3-way macro split + Total% vs. Goal% comparison
- Consistent color system: Carbs (teal) / Fat (purple) / Protein (orange)
- **Foods Highest In Carbohydrates / Fat / Protein** drill-downs — useful for "where did my numbers come from"

**Steps sub-tab**
- 1 Month default period
- Three KPIs: Average / Best / Total (with date stamp on Best)
- Bar chart by week, daily entries log
- **Notable in this account:** 43,536 steps on Saturday April 25 — a marathon or ultra-distance day. MFP has no way to recognize that as a race day or attach the appropriate fueling context

**Weight sub-tab**
- Start / Current / Change KPIs
- Line chart, entries log with photo attachment option
- **Endurance lens:** Weight is treated as the primary outcome metric of the app. For an endurance athlete in maintenance (this account is 105 → 105 → 105), this view is useless. Performance outcomes (paces, HR, watts, race times, recovery scores) are completely absent from MFP's "progress" model

**Sleep sub-tab** (mentioned, not demoed)

**Share / Export**
- Icon top-right of Progress
- Requires email verification before share is enabled — sensible privacy gate

## Strengths

1. AI-generated insight card — personalized, day-of-week stamped, retention-focused, well-written. A real product investment and meaningful retention lever
2. Empathic copywriting throughout — even "you've logged more than usual" reframes deviation positively
3. Net Calories math is exposed
4. Foods Highest In drill-downs — excellent for behavior change ("where are my carbs coming from?")
5. Consistent color system across all sub-tabs
6. Comprehensive nutrient tracking — 12+ nutrients with goals is more than most competitors
7. Day View / Period View toggle with prev/next arrows
8. Export gated behind email verification — thoughtful privacy posture

## Endurance-specific gaps

- **7-day averages flatten periodization** — a Monday recovery day and a Saturday 3-hour long run have radically different fueling needs. MFP shows a single rolling average that obscures this
- **Net Calories framing is misleading** for athletes — −2,476 reads as a failure mode
- **Sodium goal is sedentary** (2,300 mg) — actively misleading for sweat-rate-relevant athletes
- **No iron, magnesium, calcium tracking** — these matter disproportionately for endurance athletes (especially female)
- **No caffeine, no electrolyte timing, no carb timing**
- **Weight as primary outcome metric** — for performance athletes in maintenance, "0 lbs change" is the goal, not a problem
- **No correlation with training data** — even though Strava/Garmin are connected, Progress doesn't surface "your protein on hard days vs. easy days"
- **No race day / training block markers** in any chart
- **No coach view**

## General weaknesses

- Information density on Overview — Xuan's own reaction: "It's really a lot of information"
- Sleep tab feels grafted on
- AI insight has no thread depth visible

## Patterns worth borrowing

- **AI-generated personalized insight at top of Progress** — Mealvana version: "Saturday's long run drained ~1,200 mg sodium below target. Today's session is easy — let's load up on potassium and 80 g carb/hr for next Saturday's race rehearsal." This is exactly where domain knowledge gives us a moat
- **Empathic, action-oriented copywriting**
- **Foods Highest In drill-down** → "Foods that powered your long run," "Foods that hurt your tempo session"
- **Day View / Period View toggle with prev/next arrows**
- **Three-column Total/Goal/Left table** — clean format for fueling-window targets
- **Export with email verification gate** — natural fit for coach-licensing
- **Consistent macro color system** — reinforces learnability across screens
- **Retention card framing** — "restart your streak" is psychologically smarter than "you missed 3 days"

## Strategic read

Progress is MFP's most data-rich tab, and it's also where their general-population framing is most exposed. The math is correct, the visuals are clean, and the AI insight feature is genuinely good — but the entire mental model is built on **"calories in vs. out, weight trend over time."** That model is wrong for endurance athletes, where the outcome metrics are performance (paces, watts, HR, race times) and the relevant fueling decisions are about timing windows around workouts, not midnight-to-midnight totals.

For Mealvana, this tab is the most exciting competitive surface to outbuild — we can keep the polish (AI insights, drill-downs, color system, copywriting tone) and replace the metric layer with training-state-aware analytics.

---

# Tab 4 — Coach (Nutrition Coach AI)

## Purpose

The newest, most strategically important tab. A chat-based AI nutrition assistant ("Nutrition Coach") that can plan meals, draft grocery lists, diagnose problems, and pull from the user's actual logged data. This is the direct competitive surface for Mealvana's MealBuddy / AI assistant architecture — and the most worth dissecting in detail.

## Top-level information architecture

- "Nutrition Coach" chat interface as a full-screen tab
- Top-right compose icon for starting a new chat (implies chat history persistence)
- Message bubbles (user right / AI left), markdown formatting (bold, bullets)
- **Inline tool-call cards**, collapsible, showing tool name + parameters (transparency)
- **Persistent quick-action chip buttons** under AI responses: `Browse Recipes`, `View Diary`, `Log Food`
- **Dynamic suggested follow-up chips** below messages (response-specific)
- "Ask a question" text input with up-arrow send button
- Standing disclaimer: "Content provided for information only. Nutrition Coach can make mistakes."

## AI architecture observations (critical for MealBuddy design)

**Tools called visibly during the demo:**
- `get_nutrition_goals` — returns user's calorie/macro targets
- `get_food_diary` with `days: 14` parameter — RAG over actual logged food
- `search_recipes` with parameters `max_time`, `max_results`, `keywords`, `dietary_approach`, `meal_type` — structured recipe search

**Tool-use UX patterns**
- Tool calls render as inline collapsed cards ("Used get_food_diary" with chevron to expand)
- Expanded view shows raw parameters and partial raw response
- Multiple tool calls per turn render as "Used 2 tools" (collapsed by default)
- **Transparency-by-default** — users see what the agent did, which builds trust

**Conversation patterns**
- Multi-turn state preserved across messages
- AI proactively asks clarifying questions (cook time, plan style, allergies) but **re-asks information that should already be in the profile** (allergies were asked at onboarding)
- AI uses "Say 'Go' and I'll do X" pattern to gate longer outputs — light commitment device
- AI offers next-step CTAs at end of responses (deepen this OR broaden to that)
- Suggested follow-ups appear as tappable chips — reduces typing friction

**Personalization depth observed**
- *Strong*: pulls user's logged food (Raspberry Smoothie Bowl) and reuses it in plans
- *Strong*: matches calorie/protein targets exactly (1,960 kcal / 98 g protein per day, summed correctly across 5 days)
- *Weak*: doesn't pull race goals, training calendar, sweat rate, sport, or injury history
- *Weak*: doesn't know it already asked about allergies during onboarding

## Walkthrough — Conversation 1: weekly meal planning

1. User: "Can we plan for the next week together?"
2. AI asks 3 clarifying questions (plan style, allergies, cook time per meal)
3. User picks "30 min weekdays" → AI calls `get_nutrition_goals`, confirms targets
4. AI asks again (plan style + allergies) — *suggests imperfect state management*
5. User says "high-protein" → AI calls `get_food_diary` (14 days), generates sample weekday menu reusing the user's logged Raspberry Smoothie Bowl
6. User asks for full 5-day plan → AI drafts Days 1-5 with breakfast/lunch/snack/dinner, varying protein sources
7. AI offers two next steps: convert to exact calories OR search recipes
8. User picks convert → AI matches **each day exactly to 1,960 kcal / 98 g protein** with per-meal calorie/protein subtotals (math is correct, summed accurately)
9. AI offers grocery list → produces categorized list (Protein / Dairy / Grains / Fruits & Veg / Pantry)
10. AI offers "format as one-column checklist with checkboxes" + "printable PDF" CTA chip
11. User picks "printable PDF" → **AI fails** with "I can't create files directly, but here's a ready-to-copy printable checklist…"
12. Recovery: AI offers to refine to per-week quantities → produces refined list

## Walkthrough — Conversation 2: marathon planning (endurance test case)

User: "I'm a marathon runner. Can you help me plan out a long 20-mile run on Saturday."

AI output structured by fueling window:
- **3–4 hr before**: Raspberry Smoothie Bowl with Pears & Pistachios (1 serving, from her diary)
- **30–60 min before**: ½ banana or 1 small sports gel
- **During run**: 30–60 g carbs/hr; gel/banana every 30–45 min; sip water/electrolytes
- **Immediately after (within 45 min)**: 16–24 oz chocolate milk OR smoothie bowl + 6 oz Greek yogurt (~20 g protein)
- **Hydration**: 16–24 oz first hour post; continue with electrolytes

Follow-up chips: "Check my Diary for pre-run options, Find a high-carb recipe for 3-4 hours before, Show gels and sports nutrition in my saved foods."

## Walkthrough — Recipe search

User picks "Find a high-carb recipe for 3–4 hours before"
- AI calls `search_recipes(max_time=20, max_results=5, keywords="oatmeal smoothie bowl porridge high carb breakfast", dietary_approach="carb", meal_type=[...])`
- **Returns only 1 result** (Cottage Cheese Breakfast Bowl — not high-carb / not great for pre-run)
- **AI falls back to LLM-generated recipe** (Large Banana Oat Bowl: 1 cup rolled oats + 1 banana + 2 tbsp maple syrup + ¼ cup raisins + 1 tbsp chia seeds + pistachios) — yields ~70–90 g carbs
- User asks to convert to 2 servings → **scaling bug**: ingredients don't actually double (1 cup rolled oats stays at 1 cup)

## Walkthrough — Diagnostic question

User: "Why do I feel sluggish when I'm eating enough?"

AI gave 6 generic bullet-point suggestions (swap carb-only lunch for protein+fiber, hydration, smaller meals, walk after eating, reduce late sugar, check sleep/stress/alcohol) and mentioned vegetarian/vegan iron+B12 caveat with referral to healthcare provider. Offered "review your last 3 days" personalization but didn't auto-trigger it. Follow-up chips: "Check my last 3 days, Show protein-rich meal swaps, Suggest snacks to prevent afternoon crashes."

## Strengths

1. **Tool transparency by default** — visible tool-use cards build trust
2. **Real RAG over user data** — pulling the Raspberry Smoothie Bowl from her actual diary is genuine personalization (not theater)
3. **Calorie/macro math is correct** — summing 4 meals to exactly 1,960 kcal / 98 g protein per day, 5 days running
4. **Suggested follow-up chips** — eliminate cold-start typing
5. **Multi-turn commitment devices** — "Say 'Go' and I'll…" paces complex generations
6. **Sub-message CTAs** offering both deepening and broadening — gives user agency
7. **Grocery list categorization** — Protein / Dairy / Grains / Fruits & Veg / Pantry & Extras is the right ontology
8. **Per-meal calorie/protein labeling** — "Breakfast 470 kcal • 32 g protein" is excellent transparency
9. **Standing disclaimer** at all times
10. **Empathic clinical referral** for severe/persistent symptoms — responsible AI behavior
11. **Endurance template recognized** — the 3-4hr / 30-60min / during / immediately-after / hydration scaffold *is* the correct sports nutrition framework

## Endurance-specific gaps (the heart of the competitive case)

- **Outdated carb-during-exercise target.** 30–60 g/hr is the *old* ACSM range. Modern sports science recommends **60–90 g/hr for events >2 hr**, with well-trained athletes pushing 90–120 g/hr using multiple transportable carbohydrates. A 20-mile run at marathon pace is ~3 hours — should be at the high end. **This is a substantive correctness gap, not just a personalization gap.**
- **No multiple-transportable-carb concept.** No mention of glucose:fructose ratios (2:1 or 1:0.8), which is foundational for high-rate carb intake without GI distress
- **No sodium / electrolyte targets.** "Sip water/electrolyte" is hand-wavy. A 3-hour run could cost 1,500–3,000 mg sodium. No individual sweat-rate calibration
- **Doesn't ask about pace, intensity, or race vs. training run** — fueling at marathon pace vs. easy long run pace is materially different
- **"Sports gel" as generic noun** — no brand awareness, no carb-mix specifics
- **No gut training principle** — endurance fueling requires progressive training of GI tolerance
- **No race-week tapering, carb loading, race-day specifics**
- **No connection to training data** — even with Strava/Garmin synced from Today tab, Coach doesn't pull workout context

## General AI/UX weaknesses

- **Re-asks information from onboarding** (allergies) — state management or memory failure
- **Scaling bug**: "convert to 2 servings" doesn't actually double ingredients — basic math failure that erodes trust
- **CTA-capability mismatch**: AI offered "printable PDF" as a choice and then said it can't create files. *Never suggest an action you can't perform.*
- **Inconsistent values across surfaces**: Raspberry Smoothie Bowl logged as 400 cal in history but the meal plan assigned 400 kcal at one point and 280 cal at another
- **Recipe search underperforms**: keyword + filter search returned 1 result for a basic "high-carb breakfast" query, then fell back to LLM-generation
- **Personalization ceiling is low**: 14-day food diary lookup is good; no goals/race/sport/injury/sweat-rate context to draw on
- **Diagnostic answers are textbook-generic** — the "why am I sluggish" response reads like a WebMD article, none of the user's logged data informed it
- **No coach affordance** — zero way for an actual human coach to see, validate, or shape what the AI told the athlete

## Architecture patterns worth borrowing (for MealBuddy)

1. **Visible tool calls (collapsible)** — standardize a "Used <tool_name>" pattern with expandable parameters
2. **Persistent quick-action chips + dynamic suggested follow-ups** — two-tier suggestion system
3. **"Say 'Go' to proceed" gating** — light commitment device before generating long outputs (matches progressive disclosure)
4. **Multi-tier CTA offers** at end of responses (deepen this OR broaden to that)
5. **Per-meal calorie/protein/macro labeling** in plan output — transparency by default
6. **Categorized grocery list ontology** — Protein / Dairy / Grains / Produce / Pantry, with optional checkbox/printable mode
7. **Standing disclaimer** in chat footer
8. **Compose-new-chat icon top-right** — chat history as a first-class feature
9. **Markdown bold for key numbers** in long messages
10. **Empathic clinical-referral language** for symptoms beyond scope

## Structural advantages Mealvana has

1. **Domain depth.** Sports-science-grounded AI outputs correct carb-rate recommendations — MFP's 30-60 g/hr for a 3-hour run is meaningfully behind state-of-the-art
2. **Proprietary engine layer.** Calorie math worked, but recipe scaling broke. A deterministic engine for portioning, scaling, electrolyte math, and macro targets — with the LLM only handling natural language — fixes the entire class of errors visible here
3. **Training-state awareness.** Saturday 20-miler isn't a meal occasion, it's a node in a training plan
4. **Sweat-rate / electrolyte calibration.** Nothing prevents Mealvana from collecting this — MFP hasn't
5. **Coach view / coach-side AI.** AI assistant exposed both to athletes and to their coaches with different affordances
6. **CTA-capability discipline.** Don't suggest "printable PDF" if you can't generate one
7. **Cross-surface value consistency.** Single source of truth for food values across surfaces
8. **Race-day execution mode.** Dedicated UX surface for race morning / during-race fueling

## Strategic read

This is the most strategically important tab for Mealvana, and it confirms the thesis: **MFP has shipped an AI nutrition coach that is genuinely good at the general-population use case and structurally weak at the endurance use case.** The tool-using architecture is competent, the math (sometimes) works, the personalization (sometimes) draws on real data, and the conversation UX is well-designed. But the domain knowledge is generic, the substantive recommendations for a 3-hour run are behind current sports science consensus, and there is no coach-facing surface at all.

Competitive framing: "MFP's Coach is a credible general-population AI. It is not credible as an endurance coach — not because of the AI, but because of the domain model underneath it and the absence of any coach-side affordance. The opportunity is to build the same conversational quality on top of a sports-science-grounded proprietary engine and a coach-as-distribution architecture."

---

# Supplementary Features

Cross-cutting features surfaced by poking around. Three of the four are strategically important enough to flag, and one of them **partially updates an earlier analysis point about periodization.**

## Universal "+" FAB (quick-add)

Tapping the floating "+" (present on every main tab) opens a quick-action sheet with two tiers:
- **Top tier (4 large cards)**: Log Food, Barcode Scan, Voice Log, Meal Scan — color-coded with distinct icons
- **Bottom tier (list)**: Water, Weight, Exercise — secondary loggers grouped together

**Read.** Genuinely good IA. The FAB is the same on every tab, so the user never has to navigate to log anything. Reinforces MFP's core mental model: *the app is for logging, everything else is secondary.*

**Mealvana equivalent.** Log Food / Log Fueling (during workout) / Log Hydration / Log Sweat Test — same universal-shortcut pattern, scoped to endurance log types.

## Custom Daily Goals — partially updates earlier analysis

In Goals → Calorie, Carbs, Protein and Fat Goals, there's a section called **Custom Daily Goals** where users can override the default daily calorie/macro target on specific days of the week. In this test account: "Tue, Thu, Sat — 5,000 Calories (C 50%, P 20%, F 30%)" layered on top of a default of 1,960 kcal.

**Honest update to earlier analysis.** I previously said MFP has no periodization. That was too strong. MFP does have weekly variation — a user can manually set higher-calorie days for known training days. **This is closer to periodization than I credited.**

**The gap is still real and worth being precise about:**
- It's **day-of-week based**, not **training-state based**. The system assumes Tuesday is always a hard day; it doesn't know if this Tuesday is a recovery day or a tempo session
- It's **fully manual**. The user has to know their own training pattern and configure it. No auto-suggest from Strava/Garmin data
- It **doesn't adapt**. A training block changes intensity from week to week (build → peak → taper); the day-of-week template doesn't move with it
- It **doesn't have within-day timing**. Higher calorie target for Saturday helps, but says nothing about pre-run / during-run / post-run windows
- The interaction is **clunky**. Xuan's own reaction: "Too much control… really clunky."

**Read.** The infrastructure for variable daily targets exists. The intelligence layer that would make it useful for an endurance athlete does not. **Positioning refinement:** don't say "MFP doesn't have periodization" — say "MFP has manual day-of-week calorie variation; Mealvana auto-adjusts each day based on the actual planned/completed training session."

## Calories By Meal (per-meal calorie targets, paywalled)

Premium-gated feature. Lets the user set what % of daily calories go to each meal slot (Breakfast / Lunch / Dinner / Snacks) and configure independently for each day of the week. Default visible: 30 / 30 / 30 / 10. Toggle at bottom switches between calorie view and percent view.

**Endurance lens.** This is the closest MFP pattern to fueling windows — and it's still the wrong shape. Slots are meal-name-based (Breakfast / Lunch / Dinner / Snacks), not training-state-based (Pre / During / Post / Between). And it's per-day-of-week, not per-workout.

**Pattern worth borrowing.** The *structure* of "different calorie split on different days" is exactly what we want; the *axes* need to change. Mealvana version: training-state windows (Pre / During / Post / Between / Race Morning) with per-session calorie + macro + sodium + hydration targets that auto-adjust to the scheduled workout.

**Also worth noting.** MFP paywalls this. Willingness-to-pay signal — splitting daily calories into per-meal targets is something users will pay for. For Mealvana, the training-state version is more valuable *and* paywall-able for the same reason.

## Additional Nutrient Goals

Full list visible in Goals → Additional Nutrient Goals:
- **Fats (granular)**: Saturated 22 g, Polyunsaturated 0 g, Monounsaturated 0 g, Trans 0 g
- **Cholesterol**: 300 mg
- **Sodium**: 2,300 mg
- **Potassium**: 3,500 mg
- **Fiber**: 25 g
- **Sugar**: 73 g
- **Vitamins/Minerals (as % RDA, not mg)**: Vitamin A 100%, Vitamin C 100%, Calcium 100%, Iron 100%

**Endurance gaps to call out:**
- No magnesium (critical for endurance — muscle function, cramping)
- No B vitamins (B12 especially for plant-based athletes)
- Iron is % RDA, not mg — female endurance athletes need to know mg targets and intake against a clinical reference range
- No caffeine
- Sodium still 2,300 mg (sedentary general-pop guideline — actively wrong for endurance)
- No electrolyte mix view (sodium / potassium / magnesium / chloride together)
- Sugar at 73 g (AHA-style limit) — not contextualized for endurance, where high-glycemic sugar is *strategically useful* pre/during sessions

**Read.** Comprehensive on paper, but the targets are clinical/general-pop, not performance-aware. For endurance athletes, the right move isn't *more nutrients tracked* — it's *the right nutrients with the right reference ranges for the right user state.*

## Xuan's UX verdict to internalize

> "Too much control, I want to say. I mean, good to have — but also just really clunky."

This is a meaningful insight worth keeping. MFP's Goals section is the clearest example of **control without progressive disclosure**: every customization knob is exposed at the same level, with no opinionated defaults guided by user state. Validates Xuan's own design work on the Nutrition Transparency UI's progressive disclosure — don't give the user 12 settings sliders; give them the 3 that matter for their training state today, and let the rest expand on demand.

## Summary of strategic implications

1. **Partial-credit on periodization.** MFP does have day-of-week calorie variation. Competitive frame: "auto-adjusting to training state" vs. "manual day-of-week templates"
2. **Per-meal calorie targets are paywalled** — confirms WTP for that level of structure
3. **Additional nutrient list is comprehensive but generic** — magnesium, B12, iron-in-mg, caffeine, and electrolyte-mix views are wide open gaps
4. **Universal "+" FAB is a clean pattern worth adopting**
5. **Goals page is a cautionary tale on settings sprawl** — reinforces progressive disclosure as a Mealvana principle

---

*Analysis based on walkthrough of MyFitnessPal iOS app, May 2026. Premium account, Garmin + Strava connected, 14-day food diary populated. Captured across Today / Plan / Progress / Coach tabs plus the profile drawer and Goals subpages.*

## Comments

*No comments/discussion threads were present on this page at fetch time (include_discussions returned no discussion markers).*

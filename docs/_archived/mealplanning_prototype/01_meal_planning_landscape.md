---
title: Meal Planning Landscape Survey — UI/UX Patterns for the Mealvana Prototype
generated_date: 2026-05-06
summary: >
  A comprehensive survey of 40+ meal planning apps, tools, and platforms, with structured
  analysis of UX paradigms, AI integration patterns, athlete-specific gaps, and concrete
  inspiration picks for the Mealvana Endurance meal-planning web prototype.
---

# Meal Planning Landscape Survey

## Purpose

This document is a deep, breadth-first survey of the meal-planning product space, produced to inform the design of a Next.js + Vercel AI SDK web prototype for Mealvana Endurance. The goal is not to build a generic meal planner — it is to build an AI-native, training-aware nutrition planner for endurance athletes who want simple ingredient assemblies ("chicken + rice + veg"), not 30-minute recipes. This report covers consumer, fitness, athlete, AI-native, and adjacent tools, then synthesizes patterns into actionable design direction.

---

## Part 1: App-by-App Survey

### 1.1 Mainstream Consumer Meal Planners

---

**Mealime**
- What it does: Generates personalized weekly dinner plans from a recipe library, produces sorted grocery lists, targets 30-minute meals.
- Pricing: Free tier (limited nutrition info); Pro $2.99–$5.99/month or $49.99/year.
- Primary UX paradigm: **Recipe library + preference filtering + weekly pick grid.** After a short onboarding quiz (diet type, 12 allergies, up to 119 individual disliked ingredients), users see a curated recipe list. They manually pick meals from that list and the app assembles a shopping list. No auto-generation by default — users browse and choose.
- Preference expression: Upfront quiz + ongoing ingredient exclusions from a long list. Eight diet types. Portion size selector. No macro targets in free tier.
- Recipe representation: Full recipe cards with steps, ingredients, and nutrition behind Pro paywall.
- AI features: None meaningful as of 2025. The filtering and matching is algorithmic, not generative.
- Strengths for our use case: The dislike system (excluding individual ingredients, not just broad categories) is excellent. Grocery list by aisle is genuinely useful.
- Weaknesses: No macro-awareness, no training calendar integration, recipe-first not ingredient-assembly-first, dinner-only focus.
- Source: [Mealime App Review — Plan to Eat](https://www.plantoeat.com/blog/2023/04/mealime-app-review-pros-and-cons/), [Mealime Getting Started Guide](https://support.mealime.com/article/151-getting-started-guide)

---

**PlateJoy** (DEFUNCT — shut down 2025)
- What it did: Comprehensive lifestyle-questionnaire-driven meal plan generation, with CDC-recognized diabetes prevention program, covered by some insurance.
- Primary UX paradigm: **Questionnaire → static weekly plan.** Long onboarding (health goals, allergies, schedule, budget, household size, cooking skill) producing a fixed weekly plan updated weekly.
- Why it died: Acquired by RVO Health; determined the RD-assisted static-plan model couldn't scale.
- Lesson for us: Even with real dietitian involvement, static-plan generation is brittle. Users abandon when the plan doesn't fit their real week.
- Source: [PlateJoy Shut Down 2025 — MealThinker](https://mealthinker.com/blog/platejoy-alternative)

---

**Paprika**
- What it does: Personal recipe manager — clip recipes from any URL, organize, scale, and meal-plan them.
- Pricing: One-time purchase, $4.99 iOS.
- Primary UX paradigm: **Recipe library → manual drag-to-calendar.** Users build their own library, then manually schedule meals. There is no automated generation — it's a database with a calendar view.
- Preference expression: None — it's entirely user-curated.
- AI features: None.
- Strengths: Extreme user control, offline access, no subscription.
- Weaknesses for our use case: No automation, no macro awareness, no training connection. Requires significant upfront effort.
- Source: [Best Meal-Planning Apps 2025 — centenary.day](https://centenary.day/blog/article/best-mealplanning-apps-2025-10-tools-take-dinner-your-plate)

---

**Samsung Food (formerly Whisk)**
- What it does: Recipe clipping + social discovery + meal planner + shopping list. Includes Vision AI for pantry scanning.
- Pricing: Free; available on all platforms.
- Primary UX paradigm: **Recipe collection → weekly calendar grid.** Strong import from any website. Calendar UI is polished, but functional issues persist (serving-size changes not persisting, shopping list sync problems).
- Personalization: Limited preference filtering; Vision AI can identify fridge/pantry contents and suggest recipes.
- AI features: Vision AI ingredient recognition is a genuine capability differentiator. Weekly meal planner UI is clean.
- Weaknesses: Yummly (major recipe source) shut down December 2024, degrading content. Functional bugs undermine trust. No macro tracking.
- Source: [Samsung Food Review — Plan to Eat](https://www.plantoeat.com/blog/2026/01/samsung-food-review-pros-and-cons/), [Samsung Food — MealThinker](https://mealthinker.com/blog/samsung-food-alternative)

---

**Yummly** (SHUT DOWN December 2024)
- Status: Discontinued by Whirlpool. Recipe database model proved economically unviable.
- Lesson: A recipe database alone is not a business. Users want planning and execution help, not just recipes.

---

**Eat This Much**
- What it does: Automatic meal plan generation from macro targets and dietary preferences — "autopilot for your diet."
- Pricing: Free (single-day plan); Premium ~$9/month (full week, all features).
- Primary UX paradigm: **Parameter input → auto-generated week → selective swap/regenerate.** Users set calorie target, macro split, diet type, meal count; the algorithm generates a full week instantly. Individual meals can be regenerated independently without redoing the whole plan.
- Preference expression: Calorie target, macros, diet type (keto/vegan/paleo/vegetarian/Mediterranean/custom), disliked foods, pantry inventory.
- Meal representation: Full recipes with instructions and ingredients, but the *key differentiator* is that users can also "build a meal" by selecting food categories manually — though this is less prominent than the auto-generation flow.
- AI features: Automation engine is algorithmic (constraint satisfaction), not LLM-based. Shopping list connects to Instacart/AmazonFresh.
- Strengths: Fast, macro-accurate, broad dietary support. CNN named it best meal planning app 2025. 6+ million users.
- Weaknesses: Recipe repetition by week 3–4 even with variety maxed. Grocery costs can run 2x estimates. No training calendar awareness. UI feels dated.
- Source: [Eat This Much Review 2026 — ProMealPlan](https://www.promealplan.com/en/blog/eat-this-much-review-2026), [Eat This Much — WellnessPulse](https://wellnesspulse.com/nutrition/eat-this-much-ai-meal-planner-review/)

---

**EatLove**
- What it does: RD-backed personalized meal planning and coaching platform. Integrates with fitness journeys, primarily targets clinical/coaching contexts.
- Pricing: Subscription; sold B2B to health plans and gyms, not primarily D2C.
- Primary UX paradigm: **Questionnaire → coached plan.** More clinical than consumer.
- Strengths: RD involvement, medically credible.
- Weaknesses for our use case: Not athlete-sport-specific; heavy onboarding; B2B-first.
- Source: [EatLove JCC Feature](https://mayersonjcc.org/how-eatlove-transforms-meal-planning-to-support-your-fitness-journey/)

---

**Plan to Eat**
- What it does: Manual recipe organization + drag-to-calendar meal planning. Emphasizes user control.
- Pricing: $69/year.
- Primary UX paradigm: **Manual recipe library + calendar grid.** Drag recipes to days. No automation; you build the plan yourself. Like Paprika with better web UX.
- Weaknesses: All effort is on the user. No macro tracking. No training awareness.
- Source: [Plan to Eat App Store](https://apps.apple.com/us/app/plan-to-eat/id1215348056)

---

**Prepear**
- What it does: Social meal planning centered on following content creators and subscribing to their plans.
- Primary UX paradigm: **Creator-subscription → weekly plan adoption.** Strong split-screen cooking mode. Community/social discovery angle.
- Weaknesses for our use case: Creator-dependent quality; no macro tracking; no athlete focus.
- Source: [Best Meal Planning Apps 2025 — Nimble App Genie](https://www.nimbleappgenie.com/blogs/best-meal-planning-apps/)

---

**BigOven**
- What it does: Community recipe database (1M+ recipes) with a calendar meal planner and shopping list.
- Primary UX paradigm: **Recipe database browse → manual calendar scheduling.**
- Weaknesses: Dated UI; massive database creates decision fatigue rather than solving it; no macro focus; no training awareness.

---

**AnyList**
- What it does: Begins as a grocery list app, expands into recipe management and meal planning with "Complete" upgrade.
- Primary UX paradigm: **Grocery-list-first → light meal planning.** Excellent collaborative list management.
- Strengths: 4.9/5 App Store rating; superb for households managing shared grocery lists.
- Weaknesses for our use case: Meal planning is secondary to grocery list management; no macro tracking; no athlete context.

---

**MealPrepPro**
- What it does: Batch-cooking-focused meal planner for fitness enthusiasts. Emphasizes cooking everything on Sunday for the week.
- Pricing: $9.99/month.
- Primary UX paradigm: **Goals + preferences → batch-cook week plan.** Built for prep efficiency: "cook one session, eat all week." Users define calorie targets, meal counts, prep schedules.
- Meal representation: Recipe-based but optimized for batch quantities.
- Strengths for our use case: The batch-cooking mental model maps well to how athletes actually eat (cook proteins and carbs in bulk, assemble combinations).
- Weaknesses: Still recipe-based, not component-assembly. No training calendar integration.
- Source: [MealPrepPro](https://www.mealpreppro.com/)

---

### 1.2 Macros / Fitness-Flavored Planners

---

**MyFitnessPal Meal Planner** (launched 2025)
- What it does: AI-powered weekly meal plan generation (via acquisition of startup Intent), integrated with MFP's tracking and grocery delivery.
- Pricing: Premium+ only — $24.99/month or $99.99/year in the US.
- Primary UX paradigm: **Budget + goals → AI-generated weekly plan with grocery sync.** Produces 2–15 day plans. Ten diet types. Filters for allergies, cuisines, budget constraints.
- AI features: Uses ML/LLM to generate plans; shopping list syncs to Instacart, Walmart, Kroger, Amazon Fresh.
- Strengths: MFP's massive user base, established trust, food database.
- Weaknesses: Very new (May 2025 launch); expensive paywall; no training calendar integration; standard recipe output.
- Source: [MyFitnessPal Meal Planner — TIME Best Inventions 2025](https://time.com/collections/best-inventions-special-mentions/7320844/myfitnesspal-meal-planner/), [What to Know About MFP Meal Planner](https://blog.myfitnesspal.com/myfitnesspal-meal-planner-what-to-know/)

---

**Lose It!**
- What it does: Calorie counter with a basic meal planning / calorie allocation feature.
- Pricing: Free (limited); Premium $39.99/year.
- Meal planning UX: Minimal — targets allocate calories per meal slot (breakfast/lunch/dinner/snacks), but there is no generated plan or recipe library of significance. Primarily a log-what-you-ate tool.
- Weaknesses: The app is "showing its age" (ads in free tier, 25-entry cap per day in free). No meaningful meal planning capability. No athlete specificity.
- Source: [Lose It Alternatives 2025 — centenary.day](https://centenary.day/blog/article/8-lose-it-alternatives-2025-better-tracking-smarter-plans-lower-costs)

---

**Carbon Diet Coach**
- What it does: AI/algorithm-driven macro coaching that adjusts weekly based on weight trends.
- Pricing: ~$14.99/month.
- Primary UX paradigm: **Goal setting → macro targets → self-log meals.** Not a meal planner per se — it tells you your targets and adjusts them, but you select and log your own meals.
- Strengths: Excellent adaptive macro calculation, weekly check-in model, recipe builder for custom logging.
- Weaknesses: No meal suggestions, no training integration. A tracker, not a planner.
- Source: [MacroFactor vs Carbon — GoldAI](https://goldiai.com/blog/macrofactor-vs-carbon-diet-coach/)

---

**MacroFactor**
- What it does: Adaptive macro tracker that uses weight data to reverse-engineer metabolic rate and adjust targets.
- Pricing: ~$12.99/month.
- Primary UX paradigm: **Data-driven coaching → macro targets → self-log.** Like Carbon but with stronger metabolic modeling.
- AI features: Recently added photo-based food logging. AI Coach adjusts program based on logged weight + nutrition.
- Strengths: Best-in-class adaptive macro engine. Strong user community and transparency about methodology.
- Weaknesses for our use case: No meal suggestions, no training calendar integration, no athlete-specific fueling protocols. A tracker, not a planner.
- Source: [MacroFactor Review — MarraStrength](https://marrastrength.com/macrofactor-review/), [MacroFactor vs Carbon vs ReciMe](https://www.recime.app/blog/macrofactor-vs-carbon-vs-recime/)

---

**Cronometer**
- What it does: Hyper-detailed micronutrient tracker (84 micronutrients tracked) for people who care about nutritional completeness beyond macros.
- Pricing: Free tier; Gold ~$9.99/month.
- Meal planning: None. It is purely a food diary.
- AI features: Photo logging for Gold subscribers added September 2025.
- For our use case: Useful as a data source (nutritional completeness), but not a planning paradigm to emulate.
- Source: [Best Nutrition Tracking Apps 2025 — Gymscore](https://www.gymscore.ai/best-nutrition-tracking-apps-2025/)

---

**Strongr Fastr**
- What it does: Generates macro-matched meal plans and workout programs simultaneously.
- Pricing: Free for workouts and macro recommendations; Premium for full meal planning.
- Primary UX paradigm: **Profile → one-click generate → swap individual meals.** Fill in your profile (goals, diet type, schedule, foods you like/dislike), click generate, receive a macro-matched week. Swap any meal; AI re-matches macros.
- Strengths: Fast generation, macro accuracy, swap functionality.
- Weaknesses: Reports of bizarre portion sizes ("3.7 oz of chicken breast") to hit exact macros; some nutritional accuracy issues; no training calendar awareness in the athlete-periodization sense (just "training vs rest day" binary toggle).
- Source: [Strongr Fastr](https://www.strongrfastr.com/), [Strongr Fastr Review — JustUseApp](https://justuseapp.com/en/app/1326334081/strongr-fastr-fitness-planner)

---

**Prospre**
- What it does: Macro-first meal plan generator with barcode scanning and a large food database.
- Pricing: Free forever; Premium for additional features.
- Primary UX paradigm: **Macro targets → auto-generated plan → swap meals.** Similar to Eat This Much but skews fitness/bodybuilding.
- Strengths: Free, macro-accurate, good swap UX, Amazon Fresh autofill.
- Weaknesses: Recipe-centric output; no training integration; no athlete periodization.
- Source: [Prospre Features](https://www.prospre.io/features)

---

**Trifecta**
- What it does: Organic prepared-meal delivery service targeting athletes, with an accompanying app for tracking.
- Pricing: Prepared meals $10–$17 each; subscription delivery.
- Meal selection UX: Convenience plans (Clean, Keto, Vegan) use rotating chef-curated menus — users cannot select individual meals in these plans. However, an à la carte "Meal Prep" option lets users pick individual proteins, veggies, and carbs — a direct analog to the ingredient-assembly model we want.
- AI features: The app supports tracking logged meals; no generative AI.
- For our use case: The à la carte ingredient-component approach is the closest physical-food analog to what we want to build digitally.
- Source: [Trifecta Nutrition Review 2026 — MealFan](https://mealfan.com/reviews/trifecta-nutrition/), [Trifecta](https://www.trifectanutrition.com/)

---

**RP Diet Coach (Renaissance Periodization)**
- What it does: Meal plan generation grounded in periodized nutrition science for strength/physique athletes. Developed by sport scientists and RDs.
- Primary UX paradigm: **Onboarding quiz → time-blocked meal templates → food list selection.** Not IIFYM — RP prescribes specific meals at specific times tied to training schedule. You set wake time, train time, meal count; it creates daily meal templates and you select from food lists within each template.
- Strengths: Scientifically rigorous, training-time aware (different templates based on whether you train fasted, pre-fed, etc.), excellent onboarding UX (uses body-type illustrations, avoids abstract fat% questions).
- Weaknesses for endurance athletes: Built for strength/physique athletes; carb periodization logic is different; no running/cycling/triathlon specificity.
- Source: [RP Diet Coach — Screens Design](https://screensdesign.com/showcase/rp-diet-coach-meal-planner), [RP Diet App Review — FeastGood](https://feastgood.com/rp-diet-app-reviews/)

---

### 1.3 Athlete / Endurance-Flavored Tools

---

**Fuelin**
- What it does: Personalized endurance nutrition coaching platform, integrating with TrainingPeaks, Humango, TriDot, RunDot, and Final Surge. Used by Olympians and age-groupers. Led by Patrick Wilson (RD).
- Pricing: Not publicly disclosed; premium subscription. No free trial.
- Primary UX paradigm: **Training sync → traffic-light carb periodization → food logging.** The "traffic light" system maps carb targets to training intensity: red (rest/low) → yellow → green (high-intensity). App 2.0 (April 2025) added: AI food recognition, favorites/recent log items, calendar view comparing daily/weekly energy prescriptions vs actuals, Smart Meals feature.
- Smart Meals (2025): AI suggests three tailored meal options based on user's situation — cooking at home, eating out at a restaurant, or on the road. Each suggestion aligns with personalized macro targets. This is the closest existing product to what we want: context-aware, non-recipe meal suggestions aligned to performance nutrition.
- Preference expression: Sport type, training platform sync, dietary preferences, cuisine preferences.
- Meal representation: Smart Meals presents option cards (not step-by-step recipes) — aligned with the "inspiring meal that hits your goal macros" philosophy.
- AI: Photo food recognition, smart meal suggestions — genuinely useful, not chatbot-driven.
- Strengths for our use case: Training-aware carb periodization is the core paradigm we need. Smart Meals feature directly addresses the recipe-fatigue problem. Integration with major training platforms.
- Weaknesses: Expensive; opaque pricing; no free trial is a friction point; RD-mediated coaching makes customization slow.
- Source: [Fuelin](https://fuelin.com/), [Fuelin App 2.0 — Endurance.biz](https://endurance.biz/2025/industry-news/fuelin-app-2-0-more-personalized-approach-to-nutrition-for-athletes/), [Fuelin Smart Meals — Endurance.biz](https://endurance.biz/2025/industry-news/fuelin-launches-ai-powered-smart-meals-for-endurance-athlete-nutrition/)

---

**Hexis**
- What it does: Research-backed carb periodization platform for athletes. Built by exercise scientists. Uses proprietary Carb Coding™ algorithm.
- Pricing: From £11.50/month (~$14–15 USD).
- Primary UX paradigm: **TrainingPeaks sync → Carb Coding™ daily prescription → food log.** Hexis's differentiator is the minute-by-minute carbohydrate requirement model — it analyzes planned session intensity (watts, duration, time of day, session type: training vs key performance vs competition) and produces precise daily carb targets. Real-time adaptation when actual sessions differ from planned.
- Preference expression: Diet type, food preferences, body composition goals.
- Meal representation: Food log with quick logging. Visual cues for "what to eat during exercise" — during-workout fueling windows are explicit and timed.
- AI: Carb Coding™ algorithm, AI-powered food recognition. Not chatbot-based.
- Strengths for our use case: The training-data → carb-prescription pipeline is exactly right. The "during workout" fueling window display is a feature no general meal planner has.
- Weaknesses: No meal suggestion engine (tells you how many carbs to eat, not what to eat). UI is data-heavy, which can be overwhelming. Focused heavily on cycling; run/triathlon athletes may find it less tuned.
- Source: [Hexis Athlete App](https://hexis.live/athlete-app), [TrainingPeaks Fueling Insights vs Hexis — Basecamp](https://www.joinbasecamp.com/post/trainingpeaks-fueling-insights-vs-hexis-what-athletes-should-know)

---

**MAVR**
- What it does: AI-powered endurance nutrition app that imports training calendars and adjusts daily fueling targets automatically. Positions itself as "Fuelin without the human coach" — fully automated.
- Pricing: Free trial; Pro subscription (exact pricing not disclosed publicly).
- Primary UX paradigm: **Training calendar import → dynamic daily targets → meal logging + recommendations.** Key differentiator: instant macro recalculation when training schedule changes — no waiting for a human coach to review. Training-day vs rest-day targets adjust automatically.
- Features: Live glycogen projections, during-workout fueling timing, pre/during/post-workout meal windows, AI food coach "Kai" for conversational guidance, race plan calculator for carb-loading strategy.
- Integrations: Strava, TrainingPeaks, Intervals.icu, Runna, COROS, Garmin, Apple Health.
- Meal representation: Curated 4M+ food database + meal recommendations based on daily targets.
- AI: Kai AI coach, natural language food logging, voice meal logging, dynamic macro recalculation.
- Strengths for our use case: The most automated of the athlete nutrition apps. Race-day planning is a unique feature. Breadth of training platform integrations.
- Weaknesses: Newer app; less proven than Fuelin/Hexis. Comparison pages are written by MAVR itself (bias caveat). Meal suggestions still recipe-based.
- Source: [MAVR](https://www.mavr.app/), [MAVR vs Fuelin — MAVR Blog](https://www.mavr.app/blog/mavr-vs-fuelin-best-nutrition-app-endurance-athletes-2025)

---

**TrainingPeaks Fueling Insights** (launched July 2025)
- What it does: Substrate utilization model built into TrainingPeaks, predicting carb/fat burn for each planned session and recommending carb intake accordingly. Based on Dr. Iñigo San Millán's research with Tour de France cyclists.
- Pricing: Included in TrainingPeaks Premium (coaches get it too).
- UX: Built into the existing workout calendar. Pre-workout: estimates carb needs. Post-workout: calculates actual substrate utilization. Recommends up to 125g carbs/hour for elite sessions.
- Strengths: Native to where athletes already plan training. No separate app. Data-informed by elite cycling research.
- Weaknesses: Very new; limited to cyclists initially; requires Premium; research methodology has debated limitations (lab-calibrated with Tour cyclists, may not generalize to all athlete types).
- Source: [Introducing Fueling Insights — TrainingPeaks](https://www.trainingpeaks.com/coach-blog/introducing-fueling-insights/), [Fueling Insights vs Hexis — Basecamp](https://www.joinbasecamp.com/post/trainingpeaks-fueling-insights-vs-hexis-what-athletes-should-know)

---

**FuelMyRide / EatMyRide**
- What it does: Cycling-focused nutrition planning integrated with Garmin/Wahoo for on-bike carb pacing.
- Focus: During-ride nutrition windows rather than daily meal planning.
- For our use case: During-workout fueling is already handled in Mealvana's existing features; less relevant to the meal-planning prototype.
- Source: [MAVR vs EatMyRide — MAVR Blog](https://www.mavr.app/blog/mavr-vs-eatmyride-best-fueling-app-runners-cyclists-2025)

---

**The Athlete's FoodCoach**
- What it does: Dynamic nutrition recommendations that adjust based on what you've actually logged vs what was planned.
- UX differentiator: Adjusts recommendations *intra-day* — if you ate more carbs at breakfast than planned, the app revises your afternoon targets. This "realtime rebalancing" is distinct from all other apps.
- Source: [Comparing Top Nutrition Apps for Endurance Athletes — Fast Talk Labs](https://www.fasttalklabs.com/fast-talk/comparing-the-top-nutrition-apps-for-endurance-athletes/)

---

### 1.4 AI-First / 2024–2026 Entrants

---

**MealsAI / AI Meal Planner (ai-mealplan.com)**
- What it does: LLM-powered weekly meal plan generator with grocery list output.
- Primary UX paradigm: **Questionnaire → generated week → regenerate individual meals.** Parameters: dietary restrictions, allergies, preferences, household size, budget. Regenerate button on any meal slot.
- AI: Uses LLM to generate arbitrary meals (not constrained to a recipe database), enabling genuine variety and constraint satisfaction.
- Strengths: No recipe database ceiling — it can generate infinitely varied meals. Grocery list auto-generated.
- Weaknesses: No macro targets, no training awareness, no athlete context.
- Source: [Best Meal Planning Apps 2025 — AI Meal Plan](https://ai-mealplan.com/blog/best-meal-planning-apps)

---

**PlanEat AI**
- What it does: AI meal planner that generates weekly menus with grouped grocery lists based on goals, dislikes, and cook time.
- Primary UX paradigm: **Goals + preferences → AI-generated week.** Swap or regenerate any individual meal without redoing the plan.
- Strengths: Clean, simple interface. Swap UX is fast. No chatbot interaction required.
- Source: [PlanEat AI](https://planeatai.com), [Best Apps for Meal Planning 2025 — PlanEat](https://planeatai.com/blog/best-apps-for-meal-planning-that-actually-work-2025)

---

**Ollie**
- What it does: Family-focused AI meal planner with pantry detection, ingredient reuse logic, and Instacart/Amazon Fresh integration.
- Primary UX paradigm: **Learning preferences → "Your Menu" (auto-filled week) → one-tap swap.** The AI recognizes household patterns ("Taco Tuesdays," "Friday leftovers") and proactively accounts for ingredient reuse. Natural language commands: "Plan two easy Italian dinners."
- AI: Genuine LLM integration — responds to natural language requests and learns patterns. Ranked #1 by multiple 2025/2026 roundups.
- Weaknesses for our use case: Family/consumer focused; no macro targets; no athlete/training context.
- Source: [Ollie — Best Meal Planning Apps 2026](https://ollie.ai/2025/10/21/best-meal-planning-apps-in-2025/)

---

**Lifesum AI**
- What it does: Consumer diet app with AI-powered meal plans, photo logging, and a "Life Score" that grades daily eating.
- AI features (2025 update): Photo logging, voice logging, barcode scanning. Meal plans for multiple diet types (keto, Mediterranean, high-protein).
- AI: Useful for logging speed; meal plan generation is still template-based. Chatbot assistant for food questions.
- Weaknesses: Accuracy issues with AI features have frustrated users. No training awareness.
- Source: [Lifesum Premium Worth It 2026 — NutriScan](https://nutriscan.app/blog/posts/lifesum-premium-worth-it-2026-meal-plans-macros-cost-6ffc879a6c)

---

**AteMate / Ate Food Journal**
- What it does: Photo-based food journal with behavioral reflection, not calorie counting. Mindfulness-first.
- Primary UX paradigm: **Photo-snap → reflect on eating context → track habits over time.** No calorie counting, no planning — pure retrospective journaling.
- AI: Photo recognition for food identification; behavioral coaching.
- For our use case: The photo-first logging paradigm is worth studying (zero-friction logging), even though the overall product is not a planner.
- Source: [AteMate — youate.com](https://youate.com/)

---

**ChatGPT Meal Planner GPT**
- What it does: Custom GPT configured to generate meal plans from natural language requests.
- UX paradigm: **Conversational.** Users describe constraints in prose; GPT responds with plans or modifications.
- Strengths: Infinitely flexible, handles complex constraints gracefully ("I have 45 minutes, hate cilantro, need 150g protein today, and am doing a 3-hour ride tomorrow").
- Weaknesses: No structure, no persistent memory (without Projects), no shopping list integration, no macro tracking. Requires users to know what to ask.
- Note: A significant number of new AI meal plan apps (MealsAI, etc.) are thin wrappers over GPT API calls.
- Source: [Using ChatGPT for Meal Planning 2026 — PlanEat AI](https://www.planeatai.com/blog/using-chatgpt-for-meal-planning-updated-prompts-2026)

---

**Noom / Welli**
- What it does: Behavioral weight loss app with an AI assistant (Welli) for meal planning and coaching.
- AI meal planning: Welli Meal Planner suggests personalized recipes based on dietary needs; AI chatbot provides 24/7 guidance on food choices, eating while traveling, and GLP-1 support. Photo/voice/text food logging.
- For our use case: Noom's AI integration is chatbot-first — genuinely useful for behavioral coaching but the chatbot interaction model is not what we want.
- Source: [Welli Meal Planner — Noom](https://www.noom.com/support/faqs/using-the-app/daily-features/2025/10/welli-meal-planner-discover-personalized-recipes-in-the-app/)

---

### 1.5 Subscription Meal Kits — Browsing UX

The browsing-and-deciding UX of meal kit services is instructive because they have invested heavily in reducing selection friction at scale.

---

**HelloFresh**
- Selection UX: ~20 recipes per week, shown with clear labels: "Calorie Smart," "Quick & Easy," "Hall of Fame/Best Recipe," "Gourmet Plus." Users see 6 weeks of upcoming menus. Preference-based ordering (your past choices influence what appears first) without hiding other options. Allergen/dietary filters are prominent.
- Key UX move: **Persistent labeling system that lets users scan-and-decide in under 10 seconds.** Labels do the filtering work, not dropdowns.
- Source: [HelloFresh vs Blue Apron — Taste of Home](https://www.tasteofhome.com/article/blue-apron-vs-hellofresh/)

---

**Factor (Fresh-Prepared)**
- Selection UX: 6/8/10/12/14/18 meal subscriptions; filter by diet type (keto, low-calorie, high-protein, flexitarian, vegan). Customers can always view the full menu regardless of selected filters.
- Key UX move: **Explicit serving count selection upfront** reduces cognitive load — you know exactly how much you're committing to.
- Source: [Factor Meals Menu 2025–2026](https://factormealsmenu.us/)

---

**Green Chef**
- Selection UX: Dietary lifestyle preferences set during signup determine which recipes appear first; users can override and browse full menu. 2/3/4 recipes per week, 2/4/6 servings each.
- Key UX move: **Personalization defaults that reduce menu paralysis, with easy escape hatch to full menu.**

---

**Tovala**
- Selection UX: Choose meal count (4–16) upfront, then pick from rotating menu. Subscription-focused; pause/skip is prominent.
- Key UX move: **Commitment level choice first** (how many meals?) before meal selection — anchors expectations before overwhelming users with choices.

---

### 1.6 Adjacent Tools

**Notion Meal Plan Templates**
- Several popular templates exist (Marie Poulin's, Food HQ) with recipe databases, weekly grid planners, and shopping list generation. Most sophisticated templates include "meal bundles" — pre-assembled sets of components that can be applied to week slots.
- Key insight: Notion users are heavy power users who want complete control. The template ecosystem proves there's demand for "programmable meal grids" but the friction is too high for casual users.
- Source: [15 Best Notion Meal Planner Templates 2025 — Otter Stacks](https://otterstacks.com/blog/notion-meal-planner-templates)

**Airtable Meal Plan Templates**
- Similar to Notion but with stronger relational database features. Teams/coaches use it for client meal plan management. Advanced, not consumer-facing.

**../mealvana_ai_mealplanner**
- This directory exists in the project structure (noted for completeness) but is not accessed here per the research brief.

---

## Part 2: Synthesis

### 2.1 UI Paradigm Taxonomy

The following clusters cover the dominant interaction models:

---

**Cluster A: Recipe Library + Manual Calendar Grid**

*Apps using it: Paprika, Plan to Eat, Samsung Food, BigOven, AnyList*

How it works: User builds or imports a recipe collection, then manually drags recipes into a weekly calendar. Shopping list auto-generates from scheduled meals.

When it works: Power users who have an established recipe collection and want to organize their week. Works well when the user is the expert.

When it falls apart: Anyone who lacks 30+ curated recipes to draw from faces a blank-slate paralysis. Zero automation means zero assistance on decision fatigue. Brittle to dietary changes ("I just decided to avoid gluten — now I have to manually audit 200 recipes").

Relevance to us: The weekly calendar grid itself is a proven container for a 7-day plan view. The manual nature of these apps is what we want to replace with AI.

---

**Cluster B: Questionnaire → Static Generated Plan**

*Apps using it: PlateJoy (defunct), Mealime (semi), RP Diet Coach, older EatLove*

How it works: Upfront onboarding questionnaire (goals, allergies, preferences, schedule) produces a fixed weekly plan. Updated weekly or on-demand.

When it works: Users with stable preferences who are okay with the plan as-is. Good for habit formation when adherence to a repeating structure is the goal.

When it falls apart: Real life changes daily. Training load varies. Travel happens. Plans become stale within 2 weeks. Users who dislike a meal feel stuck. PlateJoy's shutdown is the canonical failure case. The model doesn't adapt.

Relevance to us: Useful for initial plan generation (first run), but must be combined with dynamic swap and daily-context adaptation.

---

**Cluster C: Parameter Input → Auto-Generated Week → Selective Swap/Regenerate**

*Apps using it: Eat This Much, Strongr Fastr, Prospre, Ollie, AI Meal Planner apps*

How it works: User sets macro targets or dietary parameters; the system generates a complete week. Any individual meal can be regenerated without affecting others. The plan is mutable, not static.

When it works: This is the dominant successful paradigm for macro-aware meal planning in 2025. Fast, low friction, handles edge cases gracefully (just regenerate).

When it falls apart: Without ingredient-assembly thinking, the output is still recipe-based, producing grocery lists of 50+ items. Variety can plateau (Eat This Much repetition problem). Still not training-calendar-aware.

Relevance to us: This is the right core UX loop. Generate → review → swap → finalize. The key innovation for us is adding training-day context to the generation step.

---

**Cluster D: Training Calendar Sync → Carb Prescription → Food Log**

*Apps using it: Fuelin, Hexis, MAVR, TrainingPeaks Fueling Insights, The Athlete's FoodCoach*

How it works: The app imports the training calendar, models carbohydrate/energy needs per day based on session intensity/duration, produces daily macro prescriptions. Users log what they eat against these targets.

When it works: The correct paradigm for periodized endurance nutrition. The prescription step removes ambiguity — instead of a fixed calorie target every day, users see "today is a 200g carb day" vs "tomorrow is a 120g carb day" based on their actual training.

When it falls apart: The prescription step is excellent; the *meal suggestion* step is weak. None of these apps close the gap from "you need 200g carbs today" to "here are 3 actual meals you could eat that hit that." Hexis tells you the number; Fuelin's Smart Meals is the first attempt to close this gap.

Relevance to us: This is the paradigm we are building. The missing piece — which this prototype fills — is the bridge from carb prescription to actual meal suggestions, specifically with ingredient-bundle thinking rather than recipe-complexity thinking.

---

**Cluster E: Conversational / Chatbot**

*Apps using it: MAVR's "Kai" coach, Noom's "Welli," ChatGPT Meal Planner GPT*

How it works: Natural language interface for meal planning guidance, plan generation, or food questions.

When it works: Complex constraint management ("I have a work dinner Wednesday and I'm on a race taper"). Handling edge cases and unusual situations.

When it falls apart: No persistent structure. Users have to describe context every session. High cognitive load on the user to formulate good queries. Most users want answers, not conversations.

Relevance to us: Conversational AI should be an *escape hatch* or *refinement layer*, not the primary interaction model. Use it for "why does this meal fit my training day?" explanations and for custom requests, not as the front door.

---

**Cluster F: Card Stack with Substitutions**

*Apps using it: HelloFresh (label-based), Factor (filter-first), Fuelin Smart Meals (3 options per context)*

How it works: User is presented a small set of curated options (3–10 cards) with clear labels. One-tap selection or swap. No browsing a library of 500 recipes.

When it works: When the curation is high quality and the card attributes are scannable (calorie count, protein, prep time, cuisine flag). Works particularly well on mobile where browsing is painful.

When it falls apart: If curation quality drops, users feel constrained. If cards are too visually similar, differentiation requires reading the detail.

Relevance to us: This is likely the right mobile UI for day-level meal confirmation. Show 3 options for each meal slot (morning/midday/evening), with training-day context baked in. User taps their choice. No browsing required.

---

### 2.2 AI Integration Patterns in 2025–2026

The AI integration landscape has evolved significantly beyond "chatbot in a nutrition app." Key patterns observed:

---

**Pattern 1: Plan Generation (LLM replacing algorithm)**

Traditional apps (Eat This Much, Strongr Fastr) used constraint-satisfaction algorithms to match meals to macros. 2025–2026 apps increasingly use LLMs to generate plans, enabling:
- Natural language constraint expression ("I hate mushrooms and my partner is vegetarian")
- Infinite variety without a recipe database ceiling
- Coherent weekly plans where Monday's leftover chicken appears in Tuesday's lunch

Examples: MyFitnessPal Meal Planner (Intent acquisition), PlanEat AI, Melio, Ollie.

---

**Pattern 2: Smart Swap / Contextual Regeneration**

Every major 2025 AI meal planner supports one-tap regeneration of individual meal slots. The AI regenerates just that slot while preserving macro coherence for the rest of the week. This is table-stakes now.

More sophisticated: Ollie learns that you never swap Tuesday dinner and always swap Monday lunch — so it preemptively offers alternatives for Monday.

---

**Pattern 3: Photo/Voice Food Logging (Non-Planning)**

MacroFactor, MyFitnessPal, Samsung Food, Lifesum, AteMate, Cronometer Gold all added photo-to-nutrition logging in 2024–2025. This reduces logging friction for tracking, but doesn't solve the *planning* problem.

---

**Pattern 4: Smart Pantry / Fridge Scanning**

Samsung Food Vision AI, Scan2Meal, Portions Master AI all scan fridge/pantry photos and generate meals from detected ingredients. This is compelling but still immature (90% food recognition accuracy per 2025 Frontiers in Nutrition research — good but not perfect).

---

**Pattern 5: Context-Aware Suggestions (non-chatbot)**

Fuelin's Smart Meals is the best current example: instead of asking "what should I eat?", the app detects context (at home, at restaurant, traveling) and silently generates 3 curated options. No chatbot interaction. No query needed. The AI presents a decision, the user approves or swaps.

This pattern — ambient/contextual AI that presents decisions rather than answering questions — is the direction that matters most for Mealvana.

---

**Pattern 6: Training-Calendar Binding**

MAVR, Fuelin, Hexis, and TrainingPeaks Fueling Insights all bind nutrition recommendations directly to training calendar data. This is the 2025 state of the art for athlete nutrition. The innovation frontier is moving toward *same-day* adaptation (The Athlete's FoodCoach intra-day rebalancing model) and *race-week* carb loading automation (MAVR race plan calculator).

---

**Pattern 7: Voice and Messaging Integrations**

Noca AI delivers meal plans to WhatsApp. Noom Welli supports voice food logging. MAVR supports voice meal logging. These are in early adoption; the primary interface is still screen-based.

---

### 2.3 Patterns That Handle "Meals Not Recipes"

This section is critical for Mealvana. The vast majority of meal planners are recipe-centric: they output a list of dishes with steps and ingredients. Athletes eating for performance don't need steps — they need **component assemblies** (protein + carb + vegetable + optional fat) with appropriate portions. Here are the existing approaches to this:

---

**Eat This Much "Build a Meal"**

Eat This Much has an underused but important feature: users can build a meal by selecting food categories rather than choosing pre-defined recipes. You pick "protein source" (chicken breast, turkey, salmon), "carb source" (rice, sweet potato, pasta), "vegetable" (broccoli, spinach, green beans), and the app calculates macros from quantity. This is the ingredient-assembly model. It is buried under the recipe-generation default flow but exists.

---

**Trifecta À la Carte**

Trifecta's "Meal Prep" à la carte option lets users select individual proteins, veggies, and carbs — essentially buying the components and assembling meals at home. This is the physical-food implementation of ingredient bundles.

---

**RP Diet Coach Food Lists**

RP doesn't present recipes at all in its default flow — it presents food lists within each meal category (lean proteins, complex carbs, vegetables, fats). The user picks items from each list; the app calculates portions to hit the macro target. This is exactly the ingredient-bundle paradigm, implemented as a selection-within-category model.

---

**Athlete Plates / Mix-and-Match Frameworks**

Sports dietitians consistently recommend a "plate model" approach for athlete meal planning: fill your plate with a ratio of carb/protein/vegetable that varies by training day (more carbs on hard days). Organizations like NSW Institute of Sport publish "38 balanced meal ideas for athletes" as a component combination grid.

The "Workweek Lunch" blog popularized "Protein + Veggies + Carbs" as a meal-prep framework, batch-cooking each component separately and mixing combinations through the week.

---

**Conclusion: The Gap**

No app fully implements ingredient-bundle planning as the *primary* interface. RP Diet comes closest for strength athletes. Fuelin Smart Meals comes closest for endurance athletes. The prototype opportunity is to make ingredient-bundle selection the front door, not an advanced setting.

---

### 2.4 What's Broken About Most Meal Planners

---

**Problem 1: Decision Fatigue Transferred, Not Eliminated**

A Factor/Wakefield survey found 68% of Americans say deciding what to eat is their biggest mealtime challenge. Traditional meal planning aggregates all weekly decisions into a single Sunday session — which exhausts users before the week starts. Apps that generate plans automatically address this, but if the generated output is poor, the user faces *correction fatigue* (worse than original fatigue because they now also feel guilt about the tool failing).

---

**Problem 2: Recipe Complexity is Wrong for Most Athletes**

Athletes eating 4–6 times per day for performance cannot execute a 14-step recipe at 6am. The recipe-first paradigm alienates the use case of "simple food, often." Apps recognize this by filtering for "< 30 min" or "easy" meals, but the root problem is that they start with recipes at all rather than starting with ingredients.

---

**Problem 3: Static Plans Fail Real Life**

PlateJoy is the cautionary tale: a plan generated from your preferences on Monday is stale by Wednesday when your training schedule changes, you're traveling Thursday, and your partner is now avoiding gluten. The best current systems (Eat This Much selective regeneration, MAVR dynamic calendar binding) address this, but seamless intra-week adaptation remains rare.

---

**Problem 4: No Training-Day Awareness in Consumer Apps**

Every consumer app treats every day identically from a nutrition standpoint. Even apps that collect "activity level" treat it as a constant multiplier, not a daily variable. No mainstream consumer planner says "You have a 2-hour run Thursday — here's what to eat Wednesday night, Thursday morning, and Thursday post-run."

---

**Problem 5: Macro Accuracy vs. Portioning Sanity**

Apps that prioritize exact macro matching (Strongr Fastr is the canonical example) generate absurd portion sizes ("3.7 oz chicken breast, 2.3 oz rice") to hit targets. This creates practical failure: users can't measure 2.3 oz of cooked rice in a normal kitchen. Smart rounding and "close enough" logic is absent from most macro-first tools.

---

**Problem 6: Grocery List Explosion**

Recipe-based planners generate 50–70 item grocery lists weekly. Ingredient-bundle planners (batch cook 1 protein, 1–2 carbs, and rotate veg) generate 15–20 item lists. The grocery overhead of recipe-based planning is a real adoption killer, particularly for athletes who shop frequently for fresh food.

---

**Problem 7: No Nutrition Context / Education**

Most planners give users a plan without explaining *why* it's structured this way. Athletes specifically benefit from understanding why Thursday is a high-carb day (long ride) and Monday is a lower-carb day (rest). Apps that explain the "why" — Fuelin's articles, Hexis's Carb Coding™ visual — drive better adherence.

---

**Problem 8: Dislike Systems Are Coarse**

Most apps let you exclude broad categories ("I don't like fish") but not specific items ("I don't like salmon but I eat tuna"). Mealime's 119-ingredient exclusion list is the best implementation. Athletes have specific food preferences around GI tolerance during training, not just taste.

---

### 2.5 Top 5 Inspiration Picks for the Prototype

---

**Pick 1: Fuelin Smart Meals — Context-Aware Card Generation**

The concrete UX move: The system detects your context (home / restaurant / on-the-road) and silently generates 3 on-target meal options. No query required. Each card shows the meal name, macros, and a brief description. The user taps their choice. No recipes, no steps. For our prototype: generate 2–3 "meal assembly cards" per slot based on training-day context, formatted as "[Protein] + [Carb] + [Veg]" assemblies with portions, not recipes.

Source: [Fuelin Smart Meals — Endurance.biz](https://endurance.biz/2025/industry-news/fuelin-launches-ai-powered-smart-meals-for-endurance-athlete-nutrition/)

---

**Pick 2: Hexis Carb Coding™ — Training-Adaptive Daily Targets with Visual Color System**

The concrete UX move: Map training intensity to a clear visual signal (Hexis uses color-coded carb bands; Fuelin uses traffic lights). The user sees at a glance whether today is a "high carb" or "low carb" day before they decide what to eat. For our prototype: A daily training context banner at the top of the meal plan ("Hard day — 250g carbs needed" vs "Rest day — 130g carbs") derived from the Garmin/TrainingPeaks sync we already have.

Source: [Hexis Athlete App](https://hexis.live/athlete-app)

---

**Pick 3: RP Diet Coach — Food Lists Within Meal Slots, Not Recipes**

The concrete UX move: Each meal slot shows a list of protein options, carb options, and vegetable options with quantities. The user picks one from each column. No cooking instruction needed. For our prototype: Build the "meal builder" UI as a column-selection model (pick protein / pick carb / pick veg) rather than a recipe-browsing model. AI pre-filters the lists based on training day and user preferences.

Source: [RP Diet Coach — Screens Design](https://screensdesign.com/showcase/rp-diet-coach-meal-planner), [RP Diet App Review — FeastGood](https://feastgood.com/rp-diet-app-reviews/)

---

**Pick 4: Eat This Much — Parameter → Auto-Generate → Selective Swap Loop**

The concrete UX move: The core interaction loop is: set parameters once → receive complete week → tap any meal to regenerate just that slot → confirm. For our prototype: The "generate my week" button should produce a full 7-day plan in one shot. Regeneration should be one tap per slot, and should not require re-entering preferences. State should persist between sessions.

Source: [Eat This Much Review 2026 — ProMealPlan](https://www.promealplan.com/en/blog/eat-this-much-review-2026)

---

**Pick 5: HelloFresh Label System — Scan-and-Decide Cards**

The concrete UX move: Each meal card in the weekly grid carries 3–4 scannable labels: training intensity ("Hard Day Fuel"), macro profile ("High Carb / 55g protein"), prep time ("5-min assembly"), and cuisine tag ("Asian"). These labels let users make a decision in under 10 seconds. For our prototype: Render each meal assembly card with training-context labels, macro summary, and assembly complexity — allowing rapid acceptance or swap without opening a detail view.

Source: [HelloFresh vs Blue Apron 2025 — mealbakery](https://mealbakery.com/blue-apron-vs-hellofresh/)

---

### 2.6 Three "Outside the Box" Directions

---

**Direction 1: The Weekly Meal Template System — Reuse Over Variety**

What no app does well: Athletes eat the same 8–10 foods repeatedly by design — variety is the enemy of simplicity and gut tolerance during training. No current app has a "repeating template week" concept where the user defines their core rotation (chicken/rice/broccoli on hard days; salmon/quinoa/asparagus on moderate days; eggs/sweet potato/spinach on rest days), and the AI's job is to vary spices, sauces, and minor elements, not the core ingredients.

The design: A "My Template Meals" section where users define their 5–8 go-to component assemblies with preferred portions. The AI auto-schedules these against the training calendar and suggests minor variations ("this week: teriyaki glaze on your chicken-rice-broccoli hard-day meal"). The grocery list stays consistent week to week — 15 items, predictable, low friction.

Why it doesn't exist yet: Apps are built to showcase variety (marketing goal: "500 recipes!"). Athletes want the opposite.

---

**Direction 2: Race Calendar Awareness — Progressive Nutrition Phasing**

What no app does well: No meal planner treats the athlete's full training season as a unit. Fuelin addresses the training-day micro-cycle well; nobody addresses the macro-cycle (base phase vs build phase vs race taper vs race week vs recovery week). An athlete 8 weeks out from an Ironman has different nutritional needs than the same athlete 2 days out.

The design: Connect to the race calendar (TrainingPeaks race events, Garmin race annotations) and automatically phase nutrition: base training (higher fat adaptation, moderate carbs), build (carb ramping), taper (volume reduction with maintained carb density), race week (systematic carb loading protocol), race day (precise carb timing). The AI generates this phasing automatically and explains it to the athlete.

Why it doesn't exist yet: It requires combining race planning knowledge with nutrition periodization knowledge. No app has bridged both deeply. MAVR has a "race plan calculator" feature but it's narrow — focused on race day carb loading, not the full season arc.

---

**Direction 3: Meal Plan as a Living Document — Intra-Day Context Adaptation**

What no app does well: The Athlete's FoodCoach has the closest approximation — intra-day rebalancing — but the concept should extend further. A meal plan that doesn't just change day-to-day based on training load, but also adapts to real-time signals: logged morning meal was 40g over carb target (so afternoon adapts), athlete reported feeling fatigued (so recovery macros are prioritized), unexpected long run today instead of planned rest (so the app restructures the remaining day's plan).

The design: A meal plan that is a "living document" — not set-and-forget, but a continuously adapting guide. The AI functions like a sports dietitian who is aware of what you ate at breakfast and what your training looks like today. Each meal slot is "confirmed" or "still planning." Once confirmed, it factors into the remaining day. A subtle "how are you feeling?" checkin (3 buttons: great / normal / drained) adjusts the remaining meals without a full replan.

Why it doesn't exist yet: It requires robust real-time state management and a perception shift from "planning tool" to "daily guide." Most apps are designed for weekly pre-planning sessions, not continuous guidance.

---

## Part 3: Reference Tables

### Table 1: App Comparison Matrix — Core Dimensions

| App | Training-Aware | Ingredient Assembly | AI Plan Gen | Macro Targets | Active (2026) |
|---|---|---|---|---|---|
| Fuelin | Yes (periodized) | Partial (Smart Meals) | Yes | Yes | Yes |
| Hexis | Yes (Carb Coding) | No | No | Yes | Yes |
| MAVR | Yes (calendar-based) | No | Partial | Yes | Yes |
| RP Diet Coach | Partial (train time) | Yes (food lists) | No | Yes | Yes |
| Eat This Much | No | Partial (build-a-meal) | Algorithmic | Yes | Yes |
| MacroFactor | No | No | No | Yes | Yes |
| Strongr Fastr | No | No | Yes | Yes | Yes |
| MyFitnessPal MP | No | No | Yes (LLM) | Yes | Yes |
| Mealime | No | No | No | Pro only | Yes |
| Ollie | No | No | Yes (LLM) | No | Yes |
| Samsung Food | No | No | Partial | No | Yes |
| PlateJoy | No | No | No | No | DEFUNCT |
| Yummly | No | No | No | No | DEFUNCT |

---

### Table 2: AI Integration Maturity by App (2025–2026)

| App | Photo Log | Voice Log | Plan Gen LLM | Context-Aware Suggestions | Training Binding |
|---|---|---|---|---|---|
| MAVR | Yes | Yes | Partial | Yes | Yes |
| Fuelin Smart Meals | Yes | No | Yes | Yes | Yes |
| Hexis | Yes | No | No | No | Yes |
| MacroFactor | Yes | No | No | No | No |
| MyFitnessPal | Yes | No | Yes | No | No |
| Samsung Food | Yes (Vision AI) | No | Partial | No | No |
| Ollie | No | No | Yes | Yes | No |
| Noom Welli | Yes | Yes | Partial | No | No |

---

### Table 3: Preference System Depth

| App | Diet Types | Allergy Exclusions | Individual Ingredient Exclusion | Cuisine Preferences | Training Load Input |
|---|---|---|---|---|---|
| Mealime | 8 | 12 | 119 items | No | No |
| Eat This Much | 6+ | Standard | Moderate | No | No |
| RP Diet Coach | 7 | Standard | Moderate | No | Train time/frequency |
| Fuelin | 5+ | Standard | Limited | Yes | Full calendar sync |
| Hexis | Standard | Standard | Standard | No | Full calendar sync |
| MAVR | 3+ | Standard | Standard | No | Full calendar sync |
| Strongr Fastr | 4 | Standard | Moderate | No | Binary toggle |

---

## Sources

1. [Fuelin](https://fuelin.com/)
2. [Fuelin App 2.0 — Endurance.biz](https://endurance.biz/2025/industry-news/fuelin-app-2-0-more-personalized-approach-to-nutrition-for-athletes/)
3. [Fuelin Smart Meals — Endurance.biz](https://endurance.biz/2025/industry-news/fuelin-launches-ai-powered-smart-meals-for-endurance-athlete-nutrition/)
4. [Hexis Athlete App](https://hexis.live/athlete-app)
5. [TrainingPeaks Fueling Insights vs Hexis — Basecamp](https://www.joinbasecamp.com/post/trainingpeaks-fueling-insights-vs-hexis-what-athletes-should-know)
6. [Introducing Fueling Insights — TrainingPeaks](https://www.trainingpeaks.com/coach-blog/introducing-fueling-insights/)
7. [MAVR](https://www.mavr.app/)
8. [MAVR vs Fuelin — MAVR Blog](https://www.mavr.app/blog/mavr-vs-fuelin-best-nutrition-app-endurance-athletes-2025)
9. [Comparing Top Nutrition Apps for Endurance Athletes — Fast Talk Labs](https://www.fasttalklabs.com/fast-talk/comparing-the-top-nutrition-apps-for-endurance-athletes/)
10. [Eat This Much Review 2026 — ProMealPlan](https://www.promealplan.com/en/blog/eat-this-much-review-2026)
11. [Eat This Much — WellnessPulse](https://wellnesspulse.com/nutrition/eat-this-much-ai-meal-planner-review/)
12. [Eat This Much](https://www.eatthismuch.com/)
13. [MacroFactor Review — MarraStrength](https://marrastrength.com/macrofactor-review/)
14. [MacroFactor vs Carbon vs ReciMe](https://www.recime.app/blog/macrofactor-vs-carbon-vs-recime/)
15. [MacroFactor vs Carbon — GoldAI](https://goldiai.com/blog/macrofactor-vs-carbon-diet-coach/)
16. [Mealime App Review — Plan to Eat](https://www.plantoeat.com/blog/2023/04/mealime-app-review-pros-and-cons/)
17. [Mealime Getting Started — Mealime Support](https://support.mealime.com/article/151-getting-started-guide)
18. [Samsung Food Review — Plan to Eat](https://www.plantoeat.com/blog/2026/01/samsung-food-review-pros-and-cons/)
19. [Samsung Food — MealThinker](https://mealthinker.com/blog/samsung-food-alternative)
20. [PlateJoy Shut Down 2025 — MealThinker](https://mealthinker.com/blog/platejoy-alternative)
21. [Trifecta Nutrition Review 2026 — MealFan](https://mealfan.com/reviews/trifecta-nutrition/)
22. [Trifecta Nutrition](https://www.trifectanutrition.com/)
23. [RP Diet Coach — Screens Design](https://screensdesign.com/showcase/rp-diet-coach-meal-planner)
24. [RP Diet App Review — FeastGood](https://feastgood.com/rp-diet-app-reviews/)
25. [Strongr Fastr](https://www.strongrfastr.com/)
26. [Prospre](https://www.prospre.io/)
27. [MyFitnessPal Meal Planner — TIME Best Inventions 2025](https://time.com/collections/best-inventions-special-mentions/7320844/myfitnesspal-meal-planner/)
28. [What to Know About MFP Meal Planner — MyFitnessPal Blog](https://blog.myfitnesspal.com/myfitnesspal-meal-planner-what-to-know/)
29. [MealPrepPro](https://www.mealpreppro.com/)
30. [Ollie — Best Meal Planning Apps 2026](https://ollie.ai/2025/10/21/best-meal-planning-apps-in-2025/)
31. [PlanEat AI](https://planeatai.com)
32. [Best Apps for Meal Planning 2025 — PlanEat Blog](https://planeatai.com/blog/best-apps-for-meal-planning-that-actually-work-2025)
33. [Welli Meal Planner — Noom](https://www.noom.com/support/faqs/using-the-app/daily-features/2025/10/welli-meal-planner-discover-personalized-recipes-in-the-app/)
34. [Lifesum Premium 2026 — NutriScan](https://nutriscan.app/blog/posts/lifesum-premium-worth-it-2026-meal-plans-macros-cost-6ffc879a6c)
35. [AteMate](https://youate.com/)
36. [Using ChatGPT for Meal Planning 2026 — PlanEat AI](https://www.planeatai.com/blog/using-chatgpt-for-meal-planning-updated-prompts-2026)
37. [Lose It Alternatives 2025 — centenary.day](https://centenary.day/blog/article/8-lose-it-alternatives-2025-better-tracking-smarter-plans-lower-costs)
38. [HelloFresh vs Blue Apron 2025 — mealbakery](https://mealbakery.com/blue-apron-vs-hellofresh/)
39. [Factor Meals Menu 2025–2026](https://factormealsmenu.us/)
40. [Food Decision Fatigue — MealThinker](https://mealthinker.com/blog/food-decision-fatigue)
41. [Best Meal Planning Apps 2025 — AI Meal Plan](https://ai-mealplan.com/blog/best-meal-planning-apps)
42. [Notion Meal Planner Templates 2025 — Otter Stacks](https://otterstacks.com/blog/notion-meal-planner-templates)
43. [Scan2Meal](https://scan2meal.app/)
44. [Best Meal Planning Apps 2025 — Ollie](https://ollie.ai/2025/11/11/best-meal-planning-apps-2025-2/)
45. [12 Best Meal Planning Apps 2025 — AI Meal Plan](https://ai-mealplan.com/blog/best-meal-planning-apps)
46. [Carbon Diet Coach Pricing 2026 — NutriScan](https://nutriscan.app/blog/posts/carbon-diet-coach-pricing-2026-plans-7a3d15e78c)
47. [MAVR vs EatMyRide — MAVR Blog](https://www.mavr.app/blog/mavr-vs-eatmyride-best-fueling-app-runners-cyclists-2025)
48. [Beyond Mealime 2025 — centenary.day](https://centenary.day/blog/article/beyond-mealime-7-smart-mealplanning-platforms-compared-2025)

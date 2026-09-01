# 🍗 Meal Planning (User Research Synthesis Doc)

Source: https://app.notion.com/p/33be3fdb754c808f905eef38ec148fca
Parent: User Research → 🛠️ Product & Engineering
Last edited: 2026-04-07

> **Product Goal (callout):**
> NOT a generic meal-planner; bridge the gap between workout fueling and the rest of their life.
> "Daily nutrition support that fills the gaps around your training"
> "We help you eat right even when you're not training."

## TL;DR

- **Non-workout days are the biggest GAP!**
  - Athletes don't know how to eat when they're NOT training
  - They need clear, low-effort guidance for rest days and low-load days
  - YES: rest-day and low-load guidance; "Today is a low-load day → eat like this"
  - NO: Treat every day the same; assume users already understand rest-day nutrition
- **Daily eating is unstructured and reactive**
  - Outside of key workouts, daily nutrition is inconsistent, intuitive, and often an afterthought
  - YES: Simple daily guidance (3–5 anchor)
  - NO: Full weekly meal plans; rigid schedules; calorie-counting
- **They want decisions, not heavy macro tracking when it comes to daily meal**
  - YES: decision support: "pick one from the three high-carb dinner ideas"; portion guidance tied to training
  - NO: tracker; dense nutrition dashboards
- **Daily eating patterns are sometimes directly hurting performance** (weight control; skipping meals, under-eating)
  - NEED: Help users avoid common daily errors and support better timing across the day
  - YES: identify "themes"/"risk moments" (low appetite during recovery)
  - NO: One-day view without training context
- **Meals are shaped by real life** (family, routines, constraints); people will not cook separate meals
  - YES: "Same meal, adjusted portion" approach; layer guidance onto existing habits
  - NO: assume athlete has full control over meals; fully prescriptive meal plans
- **User variability matters**
  - Group 1: Minimal structure / reactive eaters — simple, default
  - Group 2: Generally healthy but not training-aware — gap between training and daily
  - Group 3: Structured / tracking-oriented users — hit the target
  - YES: layered model; different levels of guidance (simple → flexible → structured)
  - NO: one-size-fits-all

## Rui's design idea

```
[today's nutrition tip]
Today is a low load day, prioritize protein!
option A….
option B….

[here's your week based on your training]
Monday (easy run) setup:
Wednesday (intervals) setup: higher carb lunch + recovery dinner
Friday: carb focused dinner for Saturday's long run
```

## Eating Habit

Most runners follow a deliberate carb-heavy routine leading into long runs.
- **Julie**: starts increasing carbs Thursday before a Saturday long run, eats a heavier lunch than dinner — usually white pasta, white rice, or Thai noodles.
- **B Wells**: starts planning Wednesday through Friday before a long run — "start big early" principle: big breakfast, medium lunch, smaller dinner the night before.
- **Haley**: very routine — night before a long run always has a green veggie, a piece of salmon, and half a sweet potato; never deviates.
- **Lauren**: *"What I think I do a more a poor job on is nutrition outside of the workout... I would benefit from more guidance on is what should your daily diet look like and your daily nutrition be versus what you're actually doing during your workouts?"* She says if macros were broken down for her, she could figure out what to eat on her own — it's more about knowing what to eat, how much of each, and when.
- **Amanda**: noticed that when she started eating more earlier in the day during marathon training, she felt significantly better. Previously wasn't eating much early, would overeat at end of day, wake up not hungry, run early without fuel, and get fatigued.

### Weight Management vs. Performance
- **Rachel**: prefers to do runs under 16 miles fasted, mostly from a weight-maintenance perspective — desk job, feels she'll gain weight if not dialed in on nutrition. Acknowledges you can't perform your best if you don't fuel properly.
- **Amanda**: when only eating ~1,200 calories/day trying to diet, all her runs felt awful — slow and sluggish.

## Family! Family!

Family food choices often inadvertently shape training nutrition — sometimes helpfully (pasta-loving kids = easy carb loading), sometimes harmfully (eating kids' snack food, skipping personal preferences).

**Vicky — Kids Drive the Menu, But Pasta Helps Both**
First question when meal planning: "what will my kids eat?" Kids love carb-heavy food (pasta), which she always adds a few days of — helps her running 50+ mi/week. Downside: skips foods she personally likes (e.g., Brussels sprouts) because kids won't eat them. Always does heavy carbs the night before (spaghetti + garlic bread before a 19-miler; chicken alfredo before a 20-miler).

**Steven — Family Meal Planning Centered on His Cooking, Not Training-Aligned**
He and wife eat healthy; he does majority of cooking, makes well-rounded meals, doesn't shy from carbs — never felt need to track nutrition. Meal preps on Fridays (grocery shopping + planning for the week). Sometimes asks kids what they're in the mood for; has a rotation of go-to (mostly pasta) recipes.

**Robin — Fell Into Unhealthy Habits Eating What the Kids Eat**
After marathon cycle after marathon cycle, got into a bad habit of eating whatever kids were eating (Doritos etc.) — fine for kids, not for her body. Shifted approach: more protein/slightly lower carbs early in week, more carbs Thursday/Friday ahead of Saturday long run. Idea: bagel pizzas (kid food) could double as a practical pre-run family meal.

**Rebecca — Family Food Is a Real Barrier**
Three elementary-age kids; won't cook a separate meal for them and herself — has to find things they'll actually eat. Framed as a significant constraint on whether a personalized nutrition app would be realistic for her daily life.

**Meredith — In Full Control, But Vegetarian in a Meat-Cooking Household**
Does all shopping/cooking; family rarely eats out (~once every 2 weeks). Vegetarian herself, cooks chicken for the rest of the family — manages two dietary needs in one household.

## Meal Plan Habit

Dominant pattern: **intuitive and loosely structured** — general rules of thumb rather than precise plans; structure tightens in days immediately before a long run/race, loosens the rest of the week.

**The Majority: Intuitive, Not Tracked**
- **Steven**: "I don't count, I don't track all my macronutrients," but always eats carbs and protein with every meal.
- **Walt**: cereal for breakfast, sometimes skips lunch, eats out for dinner — "absolutely don't monitor any form of intake regarding protein and carbs... not at all."
- **Lauren**: unstructured daily eating outside of workouts; wants more guidance.

**The Minority: Structured and Data-Driven**
- **Andy**: tracks every calorie religiously; doesn't track macros heavily outside of protein; keeps calories in check.
- **Lindsay**: uses MyFitnessPal during training, mainly post-workout to ensure enough protein.

**Chaotic Patterns That Create Problems**
- **Amanda**: (see above) — under-eating early, overeating late, fatigue from unfueled early runs.
- **Sophia**: dinner is very late because of work + training; eating too much late makes it hard to sleep — worsened by longer daylight (longer rides/swims backing up the evening).

## Non-workout days

Most athletes simply don't think much about non-workout days. Dietitian **Lexi**: "without tracking, athletes might think they are eating an appropriate amount when they're not, whether too much or too little." Non-workout-day eating is the most under-examined part of these athletes' nutrition lives.

- **Sophia**: structured during day (Travis makes eggs every morning; salad w/ eggs or chicken at lunch from hospital cafeteria), chaotic at night (late dinner, hard to sleep, worsened by long daylight training).
- **Walt**: completely unstructured — cereal, sometimes-skipped lunch, eating out for dinner; knows he doesn't eat enough since WFH, long runs kill appetite.
- **Meredith**: whole foods, home-cooked, vegetarian, olive oil, no frying, simple Italian-based recipes (tomato, olive oil, fresh veg, pasta, risotto, rice). Daily staple in and out of training: PB&J on whole wheat — protein, carbs, a little fat, easy on GI.
- **Dana**: eats very healthy — whole foods, organic fruit/veg, lean protein, grass-fed beef; very conscious of what she puts in her body, doesn't formally track.
- **Andy**: calorie-tracked; wife cooks healthy meals, which eliminates a daily "what's for dinner" challenge.

## Nutrition Outside of Training

Coach **Meredith** (coach, not the athlete above) to her athletes: "it's not just about what you're putting in your body race day. It's what you're putting in your body every day." Yet for most participants that daily discipline doesn't exist — driven by family constraints, personal lifestyle, habit, or indifference, rarely by training-aware intention.

- **Jason**: candid — "my diet's all over the place."
- **Vicky**: almost all her runs felt awful while dieting on ~1,200 cal/day — slow and sluggish.
- **Lee**: deliberate fat-adaptation strategy — restricts carbs through the week when not training heavily, times carb intake specifically around workouts.

(Note: this page cites Dovetail transcript links per quote — omitted here as they are internal Dovetail data URLs, not directly resolvable outside Notion/Dovetail.)

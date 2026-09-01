# User Research Synthesis — Meal Planning

Synthesized from every meal-planning-related Notion research artifact found (interview transcripts, coach interviews, prototype testing, hypothesis-test scripts, interview synthesis docs, meeting notes). Sources are cited inline by participant/interview name; full detail lives in the individual archive files in this directory (see `INDEX.md`).

---

## 1. Who was interviewed

**Endurance athletes (recreational and competitive), across running, triathlon, cycling:**
- Julie, B Wells, Haley, Lauren, Amanda, Rachel, Vicky, Steven, Robin, Rebecca, Meredith, Dana, Andy, Lindsay, Walt, Sophia, Jason, Lee (marathoners/runners — "Meal Planning" user-insight doc)
- Eric Fort, Cherie Dortch, Madhumita Paul, Jeff Perry, Claudia McCoy, Brandon Gibson, Anna Hurst, Landon Bruski, Isidoro Cobo, Ashley Foster, Lauren, Rachel Bouley (round 1/2/3 interview + prototype-test participants — runners, a college runner, a physician-runner, cyclist/triathlete, short-course triathlete)
- Rhonda (empty-nester athlete, explicit weight-loss goal)
- Amanda (triathlete, separate CRM interview — coach dissatisfaction, timing confusion)

**Experts / professionals:**
- Rachel Mitchell — nutrition advisor/dietitian, cookbook author; refuses prescriptive plans on clinical grounds; her professional workflow (diagnose-and-add) became the product's core model
- Lexi — dietitian, quoted on non-workout-day blind spots

**Coaches:**
- Alex Morrow — running coach (Resolute Running LLC, Homewood AL), one of 8 RRCA coaching instructors nationally; scope-of-practice liability is his dominant concern
- Claudia McCoy — coach and design partner; her #1 feature ask is meal planning
- Sarah Portella (B.E.S.T. coach) — referenced re: referring athletes to outside dietitians

**Segment framing used by the team:** three user groups — (1) minimal-structure/reactive eaters (majority, default target), (2) generally healthy but not training-aware, (3) structured/tracking-oriented users who want to hit precise targets. A layered guidance model (simple → flexible → structured) was proposed to serve all three without one-size-fits-all.

---

## 2. What they do today for meal planning

The dominant, near-universal pattern is **intuitive, reactive, and short-horizon** — not a formal weekly plan:

- **Zero-to-short planning horizon:** Madhumita — "I have absolutely no meal planning" on weekdays (toddler), plans only weekends. Jeff Perry — zero-horizon, last-minute dinner decisions from pantry or nearby pickup. Isidoro — buys the same groceries every week without really planning. Cherie — plans daily, recipe-first via Pinterest (a rarer pattern).
- **Ingredient-first, not recipe-first, for the majority:** "People actually eat by ingredients, not recipe driven" (team synthesis of testing) — Ashley Foster described dinner as "leftover beans, something and something." Landon Bruski: "I see chicken breast, and then I see rice, and then some seasoning… that's it." 6 of 8 round-3 interview participants "wing it from staples, including the expert" (Rachel Mitchell herself defaults to components and Googles when stuck). Recipe-driven users still exist and must be accommodated (Eric was named as a strong recipe-lover counter-example).
- **Routine/low-variety rotation:** Landon eats the same staples twice daily; Isidoro has a fixed ~1,100-calorie breakfast regardless of training; Rachel Bouley — "I can eat pretty much the same things every day and not get tired of it"; Lauren cycles ~4 dinners on rotation; Meredith's daily staple in and out of training is a PB&J on whole wheat.
- **Batch cooking is the real-world behavior the product must design for**, not 7 unique meals/day: Ashley Foster batch-cooks 2–3 weekend meals and eats leftovers all week. Team consensus from testing: "I think the user wants something quick, fast, batch cooking. That's what we hear and we really need to build that into our user experience." Steven and Robin meal-prep on a fixed weekly day (Friday) around a grocery run.
- **Structure tightens only right before a long run/race:** Julie, B Wells, Haley, Vicky, Robin all described carb-loading rituals that start Wednesday–Friday before a Saturday long run, then loosen the rest of the week.
- **The minority tracks formally:** Andy tracks every calorie religiously (protein-focused); Lindsay uses MyFitnessPal post-workout to check protein; Amanda (triathlete) logs racing nutrition and uses MyFitnessPal, Tailwind, Honey Stinger, Fairlife milk.
- **Coaches don't touch daily meal planning:** Alex Morrow explicitly stays "anecdotal" and defers to manufacturer labels rather than prescribe, citing liability — "if I start designing meal plans for you, if something bad happens, I'm liable for that." Athletes without a dietitian are largely on their own for daily food.

---

## 3. Pains

- **Non-workout/rest days are the single biggest gap.** Athletes don't know how to eat when they're *not* training; daily nutrition outside key workouts is "inconsistent, intuitive, and often an afterthought" (team synthesis). Dietitian Lexi: "without tracking, athletes might think they are eating an appropriate amount when they're not, whether too much or too little" — this is the most under-examined part of these athletes' nutrition lives.
- **Daily eating sometimes directly hurts performance.** Amanda: ate too little early in the day, overate at night, wasn't hungry the next morning, ran fasted, and "would get like, really fatigued." Under-fueling from weight-control mindset recurs: Rachel runs under 16 miles fasted for weight maintenance despite knowing "you can't perform your best if you don't fuel properly"; Vicky's runs "felt awful… slow and sluggish" on a 1,200 cal/day diet.
- **Family constraints are a hard, structural barrier — not a preference.** Rebecca: three elementary-age kids, "I'm not gonna cook a separate meal for them and me" — explicitly framed as a reason a personalized nutrition app might not be realistic for her life. Vicky and Robin both described their own nutrition being shaped (helpfully and harmfully) by what their kids will eat. Meredith manages two diets (vegetarian self, meat-eating family) in one household. Madhumita cooks one family meal and her husband cooks separately when it doesn't fit her.
- **Coaches are self-limited by scope-of-practice liability**, leaving a nutrition-guidance vacuum: Alex Morrow — "I am a running coach, I'm not a dietitian, I'm not a nutritionist, so we try to speak anecdotally." Estimates ~75% success rate getting athletes to fuel properly; the other 25% "understands what I'm saying. But in practice, he just doesn't do it."
- **Existing tools stop at "numbers," not real food.** "A lot of apps… do not deliver end-to-end results… fueling tells you carbs but not what your shopping list looks like… I still need to do a lot more work" (User Interview Result synthesis). MyFitnessPal's AI Coach gave outdated fueling advice (30–60g carb/hr for a 20-mile run vs. current 60–90g/hr consensus) and has no during-workout, periodization-aware, or coach-facing surface at all.
- **Cost/logistics of translating targets into real food.** Coach interviews (roadmap doc): athletes "can't translate gram targets into feasible product mixes" — a problem that "extends beyond sports nutrition to everyday food." Isidoro separately raised cost as a real fueling constraint (wants budget alternatives like maple syrup/honey vs. branded gels).
- **68-item shopping lists / 28 meal selections are cognitively overwhelming** — an internal team prototype (7-day × 4-meal design) produced exactly this and was rejected as impractical for a single person to plan from scratch.
- **Recipe diversity/inclusion gaps** flagged unprompted by multiple prototype-test participants (Madhumita, Anna, Cherie): missing vegetarian and South Asian recipe traditions, no ingredient-level swaps.

---

## 4. Desires

- **Decisions, not tracking.** "They want decisions, not heavy macro tracking" — "pick one from the three high-carb dinner ideas," portion guidance tied to training, not a dense nutrition dashboard.
- **Low-effort, rest-day-aware guidance.** "Today is a low-load day → eat like this" was explicitly validated as the right shape of intervention; assuming users already understand rest-day nutrition was explicitly rejected.
- **"Diagnose and add," not "generate a plan from scratch."** The single strongest cross-cutting finding of the whole research project: tell the app what you already eat, it tells you what's missing and suggests specific additions at specific moments — not a 21-meal grid built from zero.
  - Landon: "I wouldn't want it to create a whole new thing... if there were an assistant that would use the current context of what I eat already and to spice it up."
  - Isidoro: "Option B by far. I don't have that much time, so I would like the app to tell me how can I optimize what I already do."
  - Madhu: picked the diagnose/optimize option by revealed behavior (already used a chat AI to optimize her existing eating, not build new plans).
  - Rachel Mitchell's actual clinical workflow — reviewing a few days of food diary, suggesting additions — is the origin of this model; she refuses prescriptive plans for safety reasons.
- **The shopping list is the real moment of value — stronger than the plan itself.** Nearly every Round 1 participant reacted most positively to the shopping-list moment in the whole interview.
  - Anna: "lowers the activation energy of making a list."
  - Jeff: "If the app actually creates a shopping list, I'm totally sold."
  - Eric: "send to Publix." Ashley: "can you do a pickup order?" Cherie noticed and liked the Aldi/Publix dual-store split.
  - "People don't open meal planners to plan meals. They open them to know what to buy."
- **Time-of-day / day-shape anchoring over meal-category anchoring.** Rachel: "Between breakfast and lunch, add this in. Maybe you like this snack, add this in around 3pm, this is gonna get you through your evening run." Multiple users describe eating in time-and-context terms ("after the long run," "before kid pickup") rather than "breakfast/lunch/dinner."
- **To be told what to eat, generate-first — but with robust, trustworthy editing.** Prototype testing validated that users want a generated starting point (not a blank slate to build from), but customization has to go further than "quick tweak" buttons or trust in the whole plan collapses.
- **Visible macro numbers, tied to a daily total — in tension with the "macro-free" design hypothesis.** Multiple testing participants (Eric, Jeff, and others) reacted positively to seeing macros; per-meal-only numbers without a daily total caused confusion. This directly contradicts the earlier prototype-design assumption ("macro-number-free... training-context language instead of grams/calories") and is flagged as an open tension for the team to resolve.
- **Personalization has to be *shown*, not implied** — the system demonstrating awareness (training context, recovery-day labeling, weather, sales) is what makes users believe it's personalized; generic suggestions read as generic regardless of backend sophistication.
- **Batch cooking / cooking-session grouping**, not day-by-day meal grids — "Plan grouped by cooking sessions, not by days — that's how she actually cooks."
- **Component-based eating with recipe discovery as a "stuck/bored" feature**, not the primary mode: "here's your protein for the week, your carb, your veggies, your sauces" as the default; "what can I make from these tonight?" as a discovery layer.
- **Ingredient-level swap**, not just meal-level swap — came up unprompted across multiple interviews ("Can I swap almond milk for oat milk?" "Can I swap salmon for chicken?").

---

## 5. AI / chat vs. structured UI

This was the central, explicitly unresolved product disagreement across the whole research program (see also `product-thinking-synthesis.md`), and the research partially — but not fully — settled it:

- **Segmented, not categorical.** 3 of 3 heavy daily-AI-tool users picked the conversational prototype vignette (Landon, Madhu, Isidoro). But 4 of the other 7 picked button-driven — including Rhonda, herself a daily AI user, which broke the team's clean segmentation hypothesis.
- **In live prototype testing, nobody used chat as their first move, across all 6 sessions.** Jeff found the chatbot interface "less intuitive at first" but expected to "get used to it and enjoy it." This is read as an onboarding-design problem for the chat-forward direction, not necessarily a rejection of chat as a concept.
- **Users skim, don't read, chat messages** — flagged as a structural risk specifically for a chat-based design, since reading the conversation is core to how it's supposed to work.
- **Resolution direction favored by the synthesis docs:** primary surface should be button-driven by default, with an embedded "chat with the assistant" affordance for the AI-native segment — not forcing one paradigm, and not making chat the only entry point. ("Chat is words, structured data lives in the regular UI" — a design principle attributed to Landon.)
- **The "magic" AI suggestion feature is explicitly gated behind meal planning shipping first** — the team decided (2026-06-25 note) to hide the AI suggestion "sparkle" button in v1 until a meal plan exists to ground it, because suggestions can't be good without knowing what the user has already planned.

---

## 6. Batch cooking

- Explicit team-meeting consensus (2026-05-08): "I think the user wants something quick, fast, batch cooking. That's what we hear and we really need to build that into our user experience," triggered by discussing how unrealistic a cookbook's day-by-day meal plan is to actually cook.
- Ashley Foster is the clearest single-user exemplar: batch-cooks 2–3 dishes on the weekend, eats leftovers/rotations across the week rather than cooking daily.
- Product design response: "Cooking sessions card" grouping in the Variant B prototype (a drag-handle + "Use as-is" button, user can override grouping); the MealBuddy entry-page mockup explicitly modeled the week as ~5 unique recipe cards for cooking sessions, not 7 unique days.
- A 7-day × 4-meal / 28-meal-selection prototype was explicitly rejected in an internal test as impractical for a single person — the team read this as further evidence that batch-cook/cooking-session framing, not daily-meal framing, is the right mental model.
- "Willingness to meal prep or batch cook" appears as an explicit onboarding-data factor in the team's "Islands of Information" model, and a batch-cook-yes/no onboarding toggle was floated in a later meeting.

---

## 7. Shopping lists

(See section 4 above for the "moment of value" finding — repeated here with product-specific detail.)

- Store-section/aisle grouping is preferred over meal-based grouping.
- Multi-store splitting (e.g., Aldi vs. Publix) was noticed and liked without being prompted.
- Grocery-pickup/delivery integration ("send to Publix," "can you do a pickup order?") came up unprompted in multiple interviews — read as evidence that the real competitive set is meal-kit and grocery-delivery services (Cook Unity, Home Chef, EveryPlate — which Anna and Madhu already pay for), not other nutrition-tracking apps.
- The existing product-level Shopping List feature spec explicitly ties back to the coach-interview finding that "athletes can't translate gram macro targets into a feasible product mix" — the shopping list is framed as the fix for the plan → procurement gap, and as of the Food Database V1 write-up, cost-per-serving data was an explicitly named V2 priority to address the "cost visibility problem from coach interviews."

---

## 8. Recipes vs. simple meals / components

- Component-based ("protein + carb + veggies," "bowls") is the dominant mental model: 6 of 8 round-1/2 interview participants lean this way. Even Rachel Mitchell (a cookbook author) defaults to components and Googles when stuck for inspiration.
- Recipe-driven behavior exists but is a minority pattern (Cherie, Madhu lean recipe-driven; Eric was separately named as a strong recipe-lover) — the product needs to accommodate both, not force one model.
- "Recipes surface as discovery when users want variety" — not the default daily interaction.
- Food-database architecture backs this: the "Lego" model (composition-pattern skeletons × reusable protein/veg/grain/sauce components, each carrying its own macros/allergens/cost/substitution data) was chosen specifically to avoid needing to build and maintain a large preset recipe library.

---

## 9. Logging

- Explicitly **not** meant to be the daily core loop. Rachel Mitchell: logging is "something I'm never going to recommend" for regular use, out of disordered-eating safety concerns.
- Positioned instead as available for specific, situational, "expert-level" use cases: carb-load week, troubleshooting GI issues, race prep.
- Some users already log with existing tools regardless (Andy — every calorie; Lindsay and Amanda — MyFitnessPal, mainly for post-workout protein).

---

## 10. Coaches

- **Scope-of-practice liability is the dominant coach-side barrier**, not lack of interest. Alex Morrow: "I am a running coach, I'm not a dietitian, I'm not a nutritionist, so we try to speak anecdotally"; "if I start designing meal plans for you, if something bad happens, I'm liable for that." He leans on manufacturer dosing language ("I'm not saying take it every 45 minutes, the manufacturer is saying take it every 45 minutes") as a liability shield.
- Coaches want visibility/correlation tools, not prescription authority: "If you could have your app, which syncs with those platforms, now we can actually see causation and correlation" — and on being shown a coach dashboard concept, explicitly declined a manipulation/edit role: "I don't want to be the person that manipulates that because I'm not an expert in that area."
- **Actionability over raw numbers wins coach trust** — Morrow praised the app for being actionable, in explicit contrast to his own dietitian's info-overload style: "the fact that you make it actionable will make you successful, for sure."
- **A liability edge case was flagged**: the app's 60–90g carb/hour fueling guidance implies 3+ gels/hour, which conflicts with some manufacturer guidance (e.g., GU's "one every 45 minutes") — heightened for Morrow because his spouse is an attorney.
- Meal planning is coach Claudia McCoy's explicit #1 feature ask, and was used as the hook in outreach to re-engage her as a design partner; her earlier feedback also directly shaped the separate Nutrition Transparency feature after she closed the app when a recommendation felt "so off."
- Coaches (Sarah Portella per CRM notes) already informally refer athletes with deeper needs to outside dietitians — positioning the product as augmenting, not replacing, that referral relationship (echoed in the interview-insight synthesis: "Don't try to replace nutritionists. Position as augmentation. Rachel-style professionals are channel partners, not competitors.")

---

## 11. Disordered-eating / safety positioning (cross-cutting, not segment-specific)

Three independent signals converged on this being a real product responsibility, not a hypothetical:
- Rachel Mitchell (clinical authority) explicitly refuses prescriptive meal plans and specific-amount guidance for safety reasons.
- Madhu is a self-described recovered macro-tracker who actively rejects seeing macro displays: "I was very much like the person who was very obsessed with weight... right now is how do I eat?"
- Rhonda explicitly states a weight-loss goal: "If I want to lose 4 to 5 pounds, literally that's my goal right now" — showing the risk exists even among users who want the very thing the product must frame carefully.

Resulting product stance (from the interview-insight synthesis): minimums not maximums ("hit at least X grams," never "consume exactly X"); performance/adequacy framing, never weight, even for users with weight goals; macros visible on demand but off by default in the daily experience; logging reserved for situational/expert use; and an explicit recommendation to formalize Rachel Mitchell's positioning-language input before launch as something closer to a clinical-advisor relationship.

---

## 12. Ranked: the 10 most important insights, with evidence

1. **Build "diagnose-and-add," not "generate-a-plan-from-scratch."** The single strongest, most repeated finding across the whole research program (Landon, Madhu, Isidoro, Rachel Mitchell's own clinical workflow; explicitly labeled "STRONG" and "the biggest single finding across the whole research project" in the Round 1+2 synthesis).
2. **The shopping list, not the meal plan, is the moment of value.** Near-universal positive reaction (Anna, Jeff, Eric, Ashley, Cherie); "people don't open meal planners to plan meals, they open them to know what to buy."
3. **Non-workout/rest days are the single biggest unaddressed gap in athlete nutrition.** Named explicitly as the #1 TL;DR point in the dedicated user-research synthesis doc, and echoed by dietitian Lexi's observation that non-training-day eating is completely untracked and unexamined.
4. **Most athletes eat ingredient-first/component-first from a rotating set of staples, not from recipes.** Confirmed by both the qualitative interviews (6 of 8) and live prototype testing (batch-cooking consensus, "eat by ingredients, not recipe driven").
5. **Real competition is meal-kit and grocery-delivery services (Cook Unity, Home Chef, EveryPlate, Instacart), not nutrition-tracking apps.** No participant cited MyFitnessPal or Fuelin as direct competition; several have already outsourced the planning problem entirely to meal kits.
6. **Family constraints are a hard structural limit, not a soft preference, for a meaningful share of the target population.** Rebecca's framing — "I'm not gonna cook a separate meal for them and me" — was explicitly treated by the team as a test of whether a personalized nutrition app is even realistic for that user's life.
7. **Chat vs. button UI is genuinely segmented, not resolved, and needs to be an option, not a forced choice.** Heavy daily-AI users lean chat; most others lean button-driven; even a daily AI user (Rhonda) picked button-driven, breaking the clean hypothesis. Live testing additionally showed nobody chose chat as a first move — an onboarding/discoverability problem layered on top of the preference split.
8. **Disordered-eating safety is a real, present risk in this population and must shape defaults (minimums not maximums, performance framing not weight framing, macros optional/hidden by default).** Grounded in three independent sources: a clinical dietitian's explicit refusal to prescribe, a recovered macro-tracker's rejection of macro displays, and a participant's stated weight-loss goal.
9. **Coaches are held back by scope-of-practice liability, not disinterest — they want visibility and causation/correlation tools, not editing/prescription authority.** Alex Morrow is the clearest, most detailed evidentiary source for this across the whole archive.
10. **Batch cooking and cooking-session grouping (not 7 unique days × N unique meals) is the correct mental model for the plan surface.** Backed by direct user behavior (Ashley Foster), a rejected internal prototype (68-item list / 28 selections deemed impractical), and explicit team consensus at the 2026-05-08 meeting.

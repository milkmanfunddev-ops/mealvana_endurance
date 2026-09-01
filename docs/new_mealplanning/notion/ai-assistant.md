# AI Assistant

- **Source:** https://app.notion.com/p/199e3fdb754c8061846bf85a388e5dcd
- **Ancestor path:** Technical and Product Documentation (data source) → Technical and Product Documentation → Features → (untitled) → (untitled) → Homepage
- **Snapshot as of:** 2026-05-18T20:14:23.705Z
- **Properties:** Category: product development · Creator: (user a5ba95df-4bbe-4aef-af83-0a3248c81058) · Date: 2025-12-23T20:20:00.019Z · Related: product, feature
- **Note:** page contains one unresolved block that the fetch could not render (`external_object_instance` at block id `1cae3fdb-754c-80d3-9c84-f5153c995317`, appears near "Related Documents").

---

Inspiration: https://annaboyle-design.com/blueapron-ai-design
https://amritakhoshoo.com/project/chef

This documentation contains the blanket documentation regarding AI features and technical discussion.

# Related Documents

- [Page mention: AI meal planning "Islands of Information" & factors](https://app.notion.com/p/1cae3fdb754c80f1be42c2f6fd1ffa7d)
- [unrendered external_object_instance block]

# Distilled Notes from Our Discussion

*(this heading carries an inline discussion thread — see Comments below)*

The AI agent learns about users' preferences through onboarding and continuous interaction. For example, a user might indicate their diet during onboarding, and over time, the app will learn that their kids play soccer on Mondays and Wednesdays. All this information can be collectively saved as a "memory" or "script"—technically equivalent to a ChatGPT assistant's "system message." Users should be able to manually edit this memory. (I'm not sure how ChatGPT stores personal information—whether it uses explicit memory like this or exists in a more black-box format.)

The AI agent should initiate conversations and intelligently guide users toward finalizing their meal plans efficiently. Its persona should be helpful, thoughtful, playful, and persuasive—not chatty or judgmental. It should provide clear reasoning for its meal and recipe suggestions while remaining concise. Since users typically prefer minimal typing, the agent should display informative status updates while processing, such as "fetching weather info…," "gathering coupons…," "analyzing past meals…," "recording your preferences…," or "optimizing for your schedule…" Similar to ChatGPT's "spent 5 seconds reasoning…" messages, these updates build user confidence. The interface should allow users to provide input with minimal effort.

Conversations can follow a sequence of blocks including an opening message, follow-up questions, suggestions, and additional help. To avoid sounding robotic, conversation starters should vary. Rather than always beginning with weather, we can weigh different conversation factors and randomize them. For example, we might start with "Did you love the bison meatball recipe?"

From a UI perspective, we should incorporate familiar elements like pills, buttons, and meal cards to minimize user input. Users should have access to the traditional meal planning dashboard (showing meal counts, including ingredients, and including recipes) and be able to modify the AI's "memory" parameters that guide conversations. They should also be able to review and edit selected meals before confirming their final meal plan.

The ideal integration would connect with calendar, training, and health apps.

Additional AI capabilities could include event planning, recipe modifications, ingredient substitutions, nutritional guidance, and reminders.

(new) The AI assistant should be proactive, leading the conversation, and being confident in giving suggestions.

# Examples of AI Conversations

Here's a refined version of the meal planning conversation:

## Scenario #0: Triathlete

**MealBuddy:** The weather next week is looking hot and humid. Summer squash, tomatoes, and peaches are in season. Based on your training schedule, I'd suggest lighter proteins with fresh summer vegetables to help with recovery after Tuesday's swim. What are you craving for next week?

**Caroline:** I actually crave some more steak.

**MealBuddy:** I'll add **Grilled Ribeye Steak with Chimichurri Sauce** to your meal plan. It would pair nicely with **Roasted Summer Vegetable Medley** which has those in-season vegetables. This would be perfect for post-hill recovery on Thursday. Would you prefer this as part of meal-prep or as a fresh-cooked dinner?

**Caroline:** Meal-prep situation.

**MealBuddy:** Perfect! For your Tuesday swim day, how about **Lemon Herb Roasted Chicken Thighs with Mediterranean Quinoa**? The protein will help with muscle recovery, and it's light enough not to sit heavy.

For your Sunday brick workout, I'd recommend **Baked Salmon with Tomatoes and Capers**. It's loaded with omega-3s for inflammation reduction and would pair well with **Simple Greek Cucumber Salad**.

Do these options work for your cooking sessions this week?

**Caroline:** Yes.

**MealBuddy:** Great! I'll finalize your meal plan for the week:

**Cooking Session 1:**
- **Grilled Ribeye Steak with Chimichurri Sauce**
- **Roasted Summer Vegetable Medley** (Perfect for post-hill training recovery)

**Cooking Session 2:**
- **Lemon Herb Roasted Chicken Thighs with Mediterranean Quinoa** (Light but protein-rich for swim day)

**Cooking Session 3:**
- **Baked Salmon with Tomatoes and Capers**
- **Simple Greek Cucumber Salad** (Ideal recovery meal for after your brick workout)

Do you need any breakfast options or snacks to get you through your training week? I know those early morning sessions can be demanding.

**Caroline:** Yes. I still got milk and egg in the fridge.

**MealBuddy:** Perfect! Since you already have milk and eggs, here are some options from our recipe collection:

**Breakfast Options:**
- **Protein-Packed Veggie Egg Muffins** (Prep ahead for quick pre-training breakfasts)
- **Greek Yogurt Breakfast Bowl with Honey and Fruit** (Can use your milk for yogurt base)

**Snacks:**
- **Homemade Energy Bars with Dates and Nuts** (Great for fueling before or during workouts)
- **Quick Greek Tzatziki with Vegetable Sticks** (For post-workout recovery)

These should complement your main meals and support your training schedule. I'll add these ingredients to your shopping list too. Anything else you need for the week?

**Caroline:** Are there any fruits on sale?

**MealBuddy:** Based on this week's circular, peaches and berries are on sale! The local blueberries are at their peak season and 30% off, and those Washington peaches just came in at a great price. Would you like me to add these to your list?

They'd work perfectly with your Greek yogurt breakfast bowls, and the blueberries would make a great addition to those homemade energy bars. Peaches could also be grilled alongside your steak for a sweet side option.

## Scenario 1: Busy Family with Mixed Dietary Needs

**MealBuddy:** Hi Susan! I see you have a packed week ahead with the kids' activities. I noticed Sam's soccer practice moved to Monday and Wednesday, and David still doesn't eat mushrooms. Would you like me to prioritize quick dinners for those busy days?

**Susan:** Yes please. And remember, I'm trying to eat more vegetables.

**MealBuddy:** Got it. For busy Monday and Wednesday, how about **Sheet Pan Chicken Fajitas with Avocado Crema** and **One-Pot Pasta Primavera with Shrimp**? Both take under 30 minutes and we can easily set aside some plain pasta for David before adding shrimp.

**Susan:** That sounds good. What about the weekend?

**MealBuddy:** For the weekend, I'd suggest **Classic Beef Lasagna with Spinach** for your Saturday family dinner. It's a crowd-pleaser and we can hide extra vegetables in the sauce. For Sunday's lunch after church, how about **Slow Cooker BBQ Pulled Pork Sandwiches** with **Creamy Coleslaw**? The pork can start cooking before you leave.

**Susan:** Perfect! What about lunches?

**MealBuddy:** With those busy afternoons, I'd recommend **Meal Prep Mason Jar Salads with Chicken** that you can make Sunday for your workweek lunches. For the kids, we could do **Baked Chicken Tenders with Honey Mustard** that can be reheated for after-school snacks.

**Susan:** Great! We're still trying to stay under budget this month.

**MealBuddy:** I checked your local store's circular - chicken thighs and seasonal zucchini are on sale this week, so these meals work well with your budget. Would you like me to add ingredients to your shopping list?

## Scenario 2: Single Professional with Weight Management Goals

**MealBuddy:** Evening, Michael! I see you've hit the gym 4 times this week - great progress! Your weight tracking shows you're 2 pounds from your goal. Would you like me to focus on high-protein, lower-carb options this week?

**Michael:** Yes, and I need simple options. I'm working late three days next week.

**MealBuddy:** Perfect. For your meal prep day, I suggest **Herb-Roasted Chicken Breast with Lemon** paired with **Roasted Broccoli with Garlic and Parmesan**. You can batch cook these for multiple meals.

**Michael:** Sounds good, but I need variety.

**MealBuddy:** How about adding **Grilled Flank Steak with Chimichurri Sauce** and **Zucchini Noodles with Pesto** for a different flavor profile? Both are low-carb but satisfying. For breakfast, the **Protein-Packed Veggie Egg Muffins** would work well for your morning protein needs.

**Michael:** I'll be eating out Friday - client dinner.

**MealBuddy:** Noted! For post-workout recovery, I'd add **Greek Yogurt Parfait with Berries and Granola** as a high-protein snack. And don't forget to try the **Simple Tuna Salad with Avocado** for a quick lunch option when working late.

**Michael:** Any treats that won't derail my progress?

**MealBuddy:** Try the **Dark Chocolate Avocado Mousse** - it's surprisingly rich but lower in sugar and has healthy fats. It would satisfy your sweet tooth without impacting your goals.

## Scenario 3: Retired Couple with Health Considerations

**MealBuddy:** Good morning, Barbara! I see Bob's blood pressure readings have improved - that's wonderful news. Your grocery list is due today. Shall we plan heart-healthy meals for the week?

**Barbara:** Yes, and remember we're having the grandkids over on Saturday.

**MealBuddy:** I'll plan accordingly. For your everyday meals, I'd suggest **Mediterranean Baked Cod with Tomatoes and Capers** and **Quinoa Salad with Roasted Vegetables** - both are sodium-conscious choices.

**Barbara:** Bob still wants some meat options.

**MealBuddy:** How about **Lean Turkey Meatloaf with Oats** instead of breadcrumbs? It's heart-healthy and satisfying. We could pair it with **Garlic Mashed Cauliflower** instead of potatoes to keep carbs moderate.

For when the grandkids visit, perhaps **Whole Wheat Pasta with Turkey Bolognese** would be perfect - familiar enough for the kids but still aligning with your health goals.

**Barbara:** That works. What about our morning routine?

**MealBuddy:** Your **Overnight Oats with Chia Seeds and Berries** have been working well for your cholesterol numbers. I'd stick with those and maybe add a **Green Smoothie with Spinach and Banana** for variety. Both support heart health and give you steady energy.

**Barbara:** We still have zucchini from the garden.

**MealBuddy:** Perfect! Let's add **Baked Zucchini Boats with Ground Turkey** to the meal plan. Great way to use your garden harvest while keeping meals lean.

## Scenario 4: Young Family with Budget Constraints and Food Allergies

**MealBuddy:** Hi Jessica! I see we have $85 for groceries this week, and Emma's peanut allergy test came back positive. The pantry inventory shows you still have rice, beans, and frozen chicken. Should we build around those?

**Jessica:** Yes please. And I need to use the ground beef in the freezer before it gets freezer burn.

**MealBuddy:** Great! For the ground beef, let's do **Simple Beef Chili with Beans** which stretches the meat with pantry staples. For the frozen chicken, **Sheet Pan Lemon Herb Chicken with Roasted Vegetables** would work well.

**Jessica:** The kids are getting bored with our usual meals.

**MealBuddy:** Let's try **Baked Taquitos with Black Beans and Cheese** - it's budget-friendly and kids usually love them. We could also do **Veggie Fried Rice with Egg** using your pantry rice and whatever vegetables are on sale this week.

**Jessica:** Good idea. What about Emma's school lunches?

**MealBuddy:** For Emma's lunches, I'd suggest **Sunflower Seed Butter and Banana Roll-Ups** instead of peanut butter. We can also prepare **Homemade Hummus with Vegetable Sticks** which is nut-free and travels well in her lunchbox.

**Jessica:** What about weekend breakfast? The kids want something special.

**MealBuddy:** Try **Whole Grain Banana Pancakes** - they're economical and you already have the bananas that need using. For a protein boost, you could add **Simple Breakfast Egg Muffins** which use ingredients you already have.

**Jessica:** Perfect, thanks!

**MealBuddy:** Your local market has carrots and potatoes on sale this week, so I've added those to your list. This meal plan comes to approximately $78, leaving some buffer in your budget. Would you like me to finalize your shopping list?

# Sub-pages linked from this page

- [AI Assistant — Technical Architecture & System Design](https://app.notion.com/p/33ee3fdb754c81dab2f8dff51c73bd19)
- [MealBuddy demo — script for tomorrow](https://app.notion.com/p/359e3fdb754c81169715eb1e7fb65687)
- [Prompt for Claude Design — build the MealBuddy prototype](https://app.notion.com/p/35ae3fdb754c81c6a5fcc6008648f3f3)
- [CLAUDE.md — terminal prototype](https://app.notion.com/p/35ae3fdb754c81379b9fd3a12c4aa1c1)
- [User interview plan — MealBuddy UIUX prototype hypotheses](https://app.notion.com/p/363e3fdb754c811f9051e210771c14f9)
- [Testing two cofounder disagreements — research design](https://app.notion.com/p/363e3fdb754c81c8b826da7b7e3f5889)
- [Variant B — control-forward conversation flow](https://app.notion.com/p/364e3fdb754c812eb05ace7b12135f44)
- [Moderator script — Variant A vs B user test](https://app.notion.com/p/364e3fdb754c8194948ce8c2d890ce5a)
- [Moderator script v2 — short version (20-30 min)](https://app.notion.com/p/364e3fdb754c81a39ec8c449e28d0a8e)
- [Entry page mockup — Meal Plan view with MealBuddy CTA](https://app.notion.com/p/364e3fdb754c81d7ba34c5757e4eda32)

---

# Comments / Discussion Threads

## Thread: "Distilled Notes from Our Discussion" heading (inline, unresolved)

**Comment** — user `noruler@gmail.com` (user id 6436ea6f-2655-4f2e-9394-a0ed83f94278) — 2025-06-16T17:01:15.296Z:

> This describes the whole user scenario, which is great. But it is a little high-level. Also, it looks like LLM help us on the UX process and acts as a human to use language to chat with end user. I just wonder whether LLM could help us on the core of the meal planning. Further, for technical part, I would like to know how we design the technical things, and do we have some documentation for that? I hope the demo could show
> 1. The ability that the UX process improved.
> 2. The ability to use various ways to chat with end-user;
> 3. The ability to assistant on meal plan details.
> 4. The ability of LLM to do the real planning (may be not the goal)
> Further, I would like to know the unbound of LLM in the meal planning domain.

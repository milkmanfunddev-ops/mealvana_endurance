# Entry page mockup — Meal Plan view with MealBuddy CTA

- **Source URL:** https://app.notion.com/p/364e3fdb754c81d7ba34c5757e4eda32
- **Snapshot date (as fetched):** 2026-05-18T19:23:25.063Z
- **Icon:** 🏠
- **Ancestor path:** Homepage › [unnamed] › [unnamed] › Features › Technical and Product Documentation › (data source: Technical and Product Documentation) › AI Assistant › **Entry page mockup — Meal Plan view with MealBuddy CTA**

## How to use this

Hand this to Claude Design. The existing Variant A and Variant B prototypes stay unchanged — this is the new **entry page** that wraps them. The MealBuddy conversation launches *from* this page, and lands the user *back* on it (or on the Shopping List tab) when the plan is locked.

---

## What we're building

The entry page for MealBuddy inside the Mealvana app. Two structural changes from the existing Meal Plan view in the screenshots:

1. **The floating + button is replaced with a MealBuddy entry point** as the primary planning action. Single-meal manual add is demoted to a secondary affordance.
2. **A tab structure (Plan · Shopping List) replaces the bottom nav** for the purposes of this mockup. Don't include Cooking, Grocery, or More tabs — those exist in the full app but aren't relevant to this entry-page design.

User flow:
- App opens to Plan tab. Shows the week's meals.
- User taps "Plan with MealBuddy" → conversation launches
- When the plan is locked, user lands on Shopping List tab automatically.
- User can tap Plan tab at any time to see the newly populated week.

---

## Layout

### Header (matches existing app)
- "Meal Plan" title (large, dark navy, matching existing typography)
- strip off other elements

### Tab strip (new)
Directly below the header:
- **Plan** (active by default)
- **Shopping List** (inactive by default; becomes active automatically when MealBuddy completes a plan)

Visual treatment: minimal text tabs with an underline or pill indicator for active state. Same color palette as existing app.

### Plan tab — body

**The mental model:** people don't cook 7 unique lunches and 7 unique dinners. They batch-cook a couple of each and eat multiple servings across the week. The plan reflects unique *recipes*, not day-stacked entries. This matches the existing app exactly — the screenshots show 1 breakfast + 2 lunches + 2 dinners, and that's the whole week.

Three sections matching the existing Meal Plan view:

**Breakfast** — 1 card
**Lunch** — 2 cards
**Dinner** — 2 cards

Total 5 cards for the whole week. Vertical scroll through the sections — no horizontal scroll needed.

Each card matches the existing app visual style:
- Food photo (rounded corner)
- Dish title below
- Heart/favorite icon top-right
- **No day labels** — the recipe's multiplicity is implicit; users understand each card serves multiple meals across the week

### Shopping List tab — body

Reuse the shopping list pattern from the existing MealBuddy prototype: aisle-grouped items with checkboxes, store header ("Publix · Aldi"), item count (e.g., 0/22), meal-filter chips at the top, "Send to Publix" CTA at the bottom.

### Primary CTA — Plan with MealBuddy

Replaces the existing floating + button. Position: bottom-right, fixed.

**Visual treatment:** pill or rounded rectangle button, larger than a single-icon FAB. Includes a small sparkle icon so the user understands what they're tapping. Example: `✨ Plan with MealBuddy`.

### Secondary action — manual single-meal add

Accessible via the header menu (3 dots). Opens a dropdown or sheet with options like:
- Add a meal manually
- Clear plan
- Settings

**Don't** put manual add as a visible button on the main page — it should be one tap deeper. The point is that MealBuddy is the obvious answer for planning, and manual add is for the rare edge case.

### Empty state

When the user has no plan for the week (first-time user, cleared plan, new week starting), the Plan tab body is empty. Leave the design of the empty state to your judgment — it should make MealBuddy the obvious answer. Could be a hero illustration, friendly framing copy, and a prominent CTA.

---

## Image URLs (Unsplash)

Use these for the meal cards. Five unique recipes, matching the batch-cooking pattern shown in the existing app. If any URL fails to load, fall back to the dish name as text.

### Breakfast (1 card)
```
Creamy Oatmeal with Banana, Berries & Almonds
  https://images.unsplash.com/photo-1517673400267-0251440c45dc?w=900&q=80&auto=format&fit=crop
```

### Lunch (2 cards)
```
Sesame Chicken Noodles
  https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=900&q=80&auto=format&fit=crop

Jambalaya
  https://images.unsplash.com/photo-1716959669847-4dad60ac301f?w=900&q=80&auto=format&fit=crop
```

### Dinner (2 cards)
```
Lemon Herb Chicken Thighs
  https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=900&q=80&auto=format&fit=crop

Beet & Goat Cheese Salad with Salmon
  https://images.unsplash.com/photo-1505253716362-afaea1d3d1af?w=900&q=80&auto=format&fit=crop
```

These five recipes mirror what the existing app screenshots show, so the entry page and the populated post-MealBuddy state both feel like the same product.

---

## Behavior notes

1. **Tab transitions:** smooth slide or fade between Plan and Shopping List. Both tabs always present in the tab strip.
2. **Initial state on launch:** Plan tab is active. If a plan exists, body is populated; if empty, show the empty state.
3. **After MealBuddy completes:** user lands automatically on Shopping List tab (the locked plan generated a shopping list, and that's the immediate next action). The Plan tab is silently populated in the background. Visual cue (subtle dot or animation on Plan tab) tells the user "there's something new there."
4. **Returning to Plan tab after MealBuddy:** the meals fill in. Optional brief animation — cards fade in or slide in from below — to make the population feel earned.
5. **The primary CTA stays visible on Plan tab even when a plan exists.** Users may want to re-plan or replace the week. The button copy doesn't change; tapping it always opens MealBuddy.

---

## Out of scope for this mockup

- Other bottom-nav tabs (Cooking, Grocery, More)
- Daily view (deferred to a later iteration)
- Detail view for individual meal cards (tapping a card opens recipe detail; that view is not part of this mockup)
- Settings, profile, notifications detail
- The MealBuddy conversation itself — already built (Variant A and Variant B)
- The MealBuddy conversation expanded to plan all three meal types — will be specified separately
- Manual single-meal add flow itself — the entry is in the header menu but the destination screen is existing/separate

---

## Comments / discussion threads

None found (no discussion markers returned by `notion-fetch` with `include_discussions: true`).

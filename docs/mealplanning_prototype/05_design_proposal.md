# 05 — Master Design Proposal: Mealvana Meal-Planning Web Prototype

**Document version:** 1.0
**Date:** 2026-05-06
**Author:** Design lead synthesis
**Target repo:** `/Users/leemartin/development/mealplanning_prototype` (does not exist yet)
**Status:** Ready for build

This document is the master design proposal for the standalone meal-planning web prototype. It synthesizes:

- `01_meal_planning_landscape.md` — competitive survey of 40+ apps
- `01a_top_picks_summary.md` — five inspirations to steal, three directions to invent
- `02_me_website_new_stack.md` — reference stack (TanStack Start + Vite + Nitro + Tailwind v4 + shadcn + Clerk)
- `03_kyle_design_for_web.md` — Kyle brand system translated to Tailwind/shadcn
- `04_user_data_inventory.md` — Supabase tables, columns, edge functions

This is a build spec, not an exploration. Decisions are confirmed where Lee has answered; open questions are gathered in §11.

---

## 1. Executive Summary

### What we are building

A **training-aware ingredient-bundle meal planner** for endurance athletes, delivered as a single-page web prototype. The hero screen is a 7-day grid where each cell shows a meal as a bulleted list of named components with portions — never a recipe with steps. The week is built around the athlete's training calendar: the long-run / key-workout day visually anchors the week, and macro targets shift by day based on training load already computed by `generate-macros-v4` and stored in `daily_macro_targets`.

AI is everywhere but **never chatbot-shaped**. Four ambient surfaces:

1. **One-tap regenerate week** at the top of the grid.
2. **Per-meal smart swap** — click a cell, get 3 alternatives that respect macros, preferences, and allergies.
3. **Coach strip** — a passive single line of AI-written context above the grid ("High-carb week — long run Saturday, taper Friday").
4. **NL tweak bar** — bottom-pinned input with chips ("more protein", "no fish this week", "simpler dinners"), not a chat thread.

### Who it's for

The same athlete the Mealvana Flutter app already serves: someone with a synced training calendar (Garmin / TrainingPeaks / Final Surge), an existing dietary preference + allergy profile, and a need to know **what to actually eat** today, given today's training. The prototype assumes the user has already onboarded into the main Mealvana app — we read their existing Supabase row, food preferences, activities, and macro targets. We do not re-collect biometrics in this prototype.

### What makes it different

Every existing meal planner solves one of two problems: *what to cook* (recipe-based, e.g. Mealime, Eat This Much) or *how many macros* (tracker, e.g. MacroFactor, Hexis). Nobody bridges from "today is a 240g-carb day because of your long run" to "here are three actual meals you could eat that hit that, in 5 minutes, using foods you like." The closest existing product is Fuelin Smart Meals (`01_meal_planning_landscape.md` §1.3), which generates 3 contextual cards but still presents recipes. Hexis Carb Coding (§1.3) gives you the number but not the meals. RP Diet Coach (§1.2) gives you food lists but no training periodization.

Our wedge: **components, not recipes; training calendar as the spine; AI structured-output into existing food IDs, never free-text hallucinations.**

### Success criteria for the prototype

A demoable build where Lee can:

1. Sign in with Clerk against the dev Supabase row for `607f9dd5-6fa7-48ee-a628-720d4a0506a1` (Lee's dev user).
2. See a real 7-day grid populated from real `activities` and `daily_macro_targets`.
3. Press **Regenerate Week** and watch a `WeekPlan` stream in via `generateObject` against a Zod schema, populating cells with food IDs from `foods` + the pre/during/post-workout templates.
4. Click any cell, get 3 swap alternatives, accept one.
5. Type "no fish this week" in the tweak bar, see the week regenerate respecting that constraint.
6. Persist the plan to a new `meal_plans` / `meal_plan_meals` table pair so it survives reload.
7. The whole thing wears Kyle's brand convincingly: Blackberry, Cream, Mango orange CTAs, Electrolyte cyan circles, Sansita Bold uppercase pill buttons.

Out of scope: pantry/leftover scanning, grocery list export, social, recipe steps, photo upload, mobile native. See §9.

---

## 2. Design Principles

Seven short principles. Every UI decision can be checked against this list.

1. **Components, never recipes.** A meal is "6 oz grilled chicken · 1 cup jasmine rice · 2 cups roasted broccoli · lemon-tahini." Never a 14-step recipe. (From `01a_top_picks_summary.md` §3 RP Diet pick; §2.6 Direction 1 reuse-over-variety.)
2. **The training calendar is the spine.** Today's column, the long-run day, the rest day — these are the visual anchors before the user even reads a meal. (From `01_meal_planning_landscape.md` §2.5 Pick 2 Hexis; §2.6 Direction 2 race calendar phasing.)
3. **AI is invisible unless it's adding context.** Generation streams in, swaps appear in a drawer, the coach strip is one passive line. No chat thread. No "I'm thinking..." spinners that feel like conversation. (From `01a_top_picks_summary.md` §1 Fuelin pattern: silent contextual cards, no chatbot.)
4. **The model never invents foods.** Structured output into Zod schemas referencing existing `foods.id` and template IDs. If the model wants a food we don't have, it picks the closest one we do. (Implementation choice; §6.)
5. **Hard constraints are inviolable, soft constraints are reweighted.** Allergies and excluded_diets short-circuit at tool-fetch time. Disliked foods and preference levels become weights in prompt context. (From `04_user_data_inventory.md` §1.2 hard vs soft semantics.)
6. **Reuse beats variety for athletes.** Eight components rotated cleverly beats fifty recipes nobody cooks. The grocery list should be predictable week to week. (From `01a_top_picks_summary.md` §Direction 1.)
7. **Brand is non-negotiable.** Blackberry + Cream backgrounds only. Sansita Bold uppercase buttons. 36px Electrolyte circles around every food/activity icon. No generic gray. No Material Design defaults bleeding through. (From `03_kyle_design_for_web.md` §1.)

---

## 3. Information Architecture

### Sitemap

```
/                           (auto-redirects to /plan if signed in, /sign-in if not)
/sign-in                    Clerk-hosted sign-in (hash routing inside our shell)
/sign-up                    Clerk-hosted sign-up
/onboarding/bridge          One-time: Clerk user → Supabase user mapping (§4 screens)
/plan                       The week view (home screen)
/plan?week=2026-W19         Same screen, navigated to a specific ISO week
/plan/meal/:slotId          Modal route: meal swap drawer (also opens as sheet from /plan)
/settings                   Read-only summary of user prefs + link out to Flutter app
/settings/preferences       Read-only food preferences view (see §4.7)
/styleguide                 Internal: Kyle brand smoke test (dev only)
```

That's it. Eight routes. We are not building a multi-section app. Everything orbits `/plan`.

### Primary navigation

A thin top bar (no bottom nav on web — see `03_kyle_design_for_web.md` §10 open question 6, decision: **top bar**).

Left: Mealvana wordmark in Sansita Bold, links to `/plan`.
Center: Week navigator — `< May 6 – May 12, 2026 >` with a "Today" button when off-week.
Right: Theme toggle (sun/moon), Clerk `<UserButton>`.

On mobile (< 768px) the week navigator collapses to a single date label that opens a sheet with the same controls.

### Mobile vs desktop differences

| Surface | Desktop (≥ 1024px) | Tablet (768–1023px) | Mobile (< 768px) |
|---|---|---|---|
| Week grid | 7 columns × N rows visible | 7 columns, horizontal scroll if needed | Vertical stack: one day per "page", swipeable |
| Coach strip | One line above grid | One line above grid | Two lines, wraps |
| Tweak bar | Bottom-pinned, full width | Bottom-pinned | Bottom-pinned, chips wrap into 2 rows |
| Swap drawer | Right-side `Sheet` (480px) | Right-side `Sheet` (full-height) | Bottom `Sheet` (90vh) |
| Macro totals | Sticky right rail (240px) | Sticky bottom of each day | Inline at top of each day card |

The desktop layout is the design target. Mobile is a graceful degradation, not a separate IA.

---

## 4. Screen-by-Screen Design

### 4.1 Sign in

**Purpose:** Get the user authenticated to Clerk so we can mint a Supabase JWT.

**Layout (desktop):**

```
+----------------------------------------------------------+
|  [Mealvana wordmark — Sansita Bold, blackberry on cream] |
|                                                          |
|                                                          |
|   +----------------------------------------+             |
|   |                                        |             |
|   |   SIGN IN TO PLAN YOUR WEEK            |   <- Sansita
|   |                                        |             |
|   |   [ Email                            ] |             |
|   |   [ Password                         ] |             |
|   |                                        |             |
|   |   [    SIGN IN    ]                    |   <- pill, orange
|   |                                        |             |
|   |   - or -                               |             |
|   |   [ Continue with Google ]             |             |
|   |   [ Continue with Apple  ]             |             |
|   |                                        |             |
|   |   Don't have an account? Sign up       |             |
|   +----------------------------------------+             |
|                                                          |
|         [ small "powered by Clerk" footnote ]            |
+----------------------------------------------------------+
```

The Clerk `<SignIn />` component is rendered inside our shell with `appearance` overrides:

- `formButtonPrimary`: `bg-primary text-primary-foreground rounded-pill font-sansita uppercase tracking-wider h-btn-h`
- `card`: `rounded-card border bg-card shadow-kyle-card dark:shadow-none`
- `headerTitle`: `font-sansita text-page-title`
- `socialButtonsBlockButton`: `rounded-pill border-2 border-foreground`

**Component inventory:** `Card`, `<SignIn appearance={...} />` from `@clerk/tanstack-react-start`.

**Interactions:** Clerk's defaults. Email/password, OAuth, magic link. After successful auth: redirect to `/onboarding/bridge`.

**AI surfaces:** none.

**Data dependencies:** none yet (auth-only).

---

### 4.2 Onboarding bridge

**Purpose:** Clerk users may not have a Mealvana profile yet. This screen handles three branches:

A. **Existing Mealvana user, signed in.** Their Clerk publicMetadata contains `supabase_user_id`. Skip to `/plan`.

B. **New Clerk user, has email matching an existing Supabase `users.email`.** We auto-link by writing `supabase_user_id` into Clerk publicMetadata, then go to `/plan`.

C. **Clerk user with no Supabase match.** We show a one-screen wall: "Mealvana Endurance is a coach-paired app. Set up your profile in the iOS/Android app first, then come back." This is an explicit non-feature for the prototype — we do not duplicate the existing Flutter onboarding.

**Layout (branch C):**

```
+----------------------------------------------------------+
|                                                          |
|   +----------------------------------------+             |
|   |                                        |             |
|   |   ALMOST READY                         |   <- Sansita
|   |                                        |             |
|   |   Your Mealvana profile lives in the   |   <- Apercu body
|   |   mobile app. Set up your training     |             |
|   |   calendar, dietary preferences, and   |             |
|   |   biometrics there, then come back to  |             |
|   |   plan your week here on the web.      |             |
|   |                                        |             |
|   |   [ Get the iOS app ] [ Android ]      |   <- outlined pills
|   |                                        |             |
|   |   Already set up? [ Sign in with the   |             |
|   |   email you used in the app ]          |             |
|   |                                        |             |
|   +----------------------------------------+             |
|                                                          |
+----------------------------------------------------------+
```

**Component inventory:** `Card`, `Button` (default + outline), `Button` (link variant for the "sign in with email" footer).

**Interactions:** Static. Outbound App Store / Play Store links. The "sign in with email" link signs out of Clerk and re-enters `/sign-in`.

**AI surfaces:** none.

**Data dependencies:**
- Read: `users.id`, `users.email` (to match by email).
- Write: Clerk `publicMetadata.supabase_user_id` via Clerk server SDK.

---

### 4.3 Week view (the home screen, `/plan`)

**Purpose:** The hero. A 7-day grid where the athlete sees their entire week of meals at a glance, with training context overlaid and AI surfaces present but quiet.

**Layout (desktop, ≥ 1024px):**

```
+----------------------------------------------------------------------------------------------------------+
|  [MEALVANA]   < May 6 – May 12, 2026 >  [ Today ]                          [☀/☾]  [user avatar]         |
+----------------------------------------------------------------------------------------------------------+
|  [Coach strip]   "High-carb week — long run Saturday (18 mi). Carbs ramp Wed → Sat, taper Fri."         |
+----------------------------------------------------------------------------------------------------------+
|                                                                                                          |
|  [ ⟳  REGENERATE WEEK ]      week locked to Mon–Sun · ISO week 19 · all 7 days planned                  |
|                                                                                                          |
|  +--------+--------+--------+--------+--------+--------+--------+   +-------------------+               |
|  |  MON   |  TUE   |  WED   |  THU   |  FRI   |  SAT●  |  SUN   |   |  WEEK TOTALS      |               |
|  |  May 6 |  May 7 |  May 8 |  May 9 | May 10 | May 11 | May 12 |   |                   |               |
|  | rest   |easy run|tempo   |easy run|shakeout| LONG   |recovery|   |  CARBS  1,540 g   |               |
|  | --     |6 mi    |8 mi    |5 mi    | 4 mi   | 18 mi  |swim    |   |  PROTEIN 1,180 g  |               |
|  | 🟢130g |🟡170g  |🟠210g  |🟡170g  |🟠220g  |🔴320g  |🟢150g  |   |  FAT      490 g   |               |
|  +========+========+========+========+========+========+========+   |                   |               |
|  |  B     |  B     |  B     |  B     |  B     |  B     |  B     |   |  → 7 days planned |               |
|  | [meal] | [meal] | [meal] | [meal] | [meal] | [meal] | [meal] |   |  → 0 days locked  |               |
|  +--------+--------+--------+--------+--------+--------+--------+   |                   |               |
|  | PRE    |        |        |        |        | PRE    |        |   +-------------------+               |
|  | --     |        |        |        |        | [meal] |        |                                       |
|  +--------+--------+--------+--------+--------+--------+--------+                                       |
|  | DURING |        |        |        |        | DURING |        |                                       |
|  | --     |        |        |        |        | [gels] |        |                                       |
|  +--------+--------+--------+--------+--------+--------+--------+                                       |
|  | POST   |        |        |        |        | POST   |        |                                       |
|  | --     |        |        |        |        | [shake]|        |                                       |
|  +--------+--------+--------+--------+--------+--------+--------+                                       |
|  |  L     |  L     |  L     |  L     |  L     |  L     |  L     |                                       |
|  | [meal] | [meal] | [meal] | [meal] | [meal] | [meal] | [meal] |                                       |
|  +--------+--------+--------+--------+--------+--------+--------+                                       |
|  |  D     |  D     |  D     |  D     |  D     |  D     |  D     |                                       |
|  | [meal] | [meal] | [meal] | [meal] | [meal] | [meal] | [meal] |                                       |
|  +--------+--------+--------+--------+--------+--------+--------+                                       |
|  | SNACK  | SNACK  | SNACK  | SNACK  | SNACK  | SNACK  | SNACK  |                                       |
|  | [meal] |   --   | [meal] |   --   | [meal] | [meal] |   --   |                                       |
|  +--------+--------+--------+--------+--------+--------+--------+                                       |
|                                                                                                          |
|                  [ Tweak this week:  more protein  |  no fish  |  simpler dinners  |  + custom… ]      |
+----------------------------------------------------------------------------------------------------------+
```

Notes on the wireframe:

- **Today's column** (whichever day "today" is) gets a blackberry 2px outline on the column header, not a fill. The column body stays cream.
- **The long-run day** (or the highest-carb day in the week) gets an extra row of pre/during/post slots that other days don't have. In the example above, Saturday's column has PRE / DURING / POST sub-rows; weekday columns hide them with `--`.
- **The dot on `SAT●`** is a small Electrolyte cyan circle indicating "key workout day."
- **Macro totals card** (right rail) is sticky on scroll. It shows week totals and how many days are confirmed.
- **The coach strip** above the grid is one line, font-apercu, italic. Streaming dots animate while it generates.
- **The tweak bar** is bottom-pinned across the full content width. Chips are pre-suggested; the `+ custom…` opens an inline input.

**Mobile layout (< 768px):**

```
+--------------------------------+
| [≡]  Sat May 11      [☀]      |
+--------------------------------+
| Coach: Long run today          |
| 320g carbs, 180g protein.      |
+--------------------------------+
|  [ ⟳ regenerate this day ]     |
+--------------------------------+
| ●● Mo Tu We Th Fr [Sa] Su      |  <- swipe dots + day labels
+--------------------------------+
|  PRE-RUN    5:30 am            |
|  ┌──────────────────────────┐  |
|  │ ◯ Bagel + honey · 60g    │  |
|  │   carbs · 5g protein     │  |
|  │   [tap to swap]          │  |
|  └──────────────────────────┘  |
|                                 |
|  DURING     during 18 mi run   |
|  ┌──────────────────────────┐  |
|  │ ◯ Maurten gel ×3 + drink │  |
|  └──────────────────────────┘  |
|                                 |
|  BREAKFAST  9:00 am             |
|  ┌──────────────────────────┐  |
|  │ ◯ 3 eggs · 2 cups        │  |
|  │   oats + berries · 1 cup │  |
|  │   coffee with milk       │  |
|  └──────────────────────────┘  |
|                                 |
|  ... (lunch, dinner, snack)    |
|                                 |
+--------------------------------+
| [tweak: more protein | no fish]|
+--------------------------------+
```

Each meal cell is a card. Tap → swap drawer (bottom sheet on mobile).

**Component inventory (week view):**

| Element | shadcn primitive | Kyle theming |
|---|---|---|
| Top bar | custom `<header>` | `bg-background border-b border-border h-14` |
| Week navigator | `Button` (icon) ×2 + label | Sansita Bold for date range |
| Coach strip | custom `<aside>` | `font-apercu italic text-body text-muted-foreground py-2 px-4 bg-muted` |
| Regenerate Week button | `Button` (default variant) | Kyle's primary pill button — orange fill, blackberry text, Sansita uppercase, `rounded-pill h-btn-h` |
| Day column header | custom `<th>` | `font-compadre uppercase tracking-wider`, today gets `border-2 border-foreground rounded-card` |
| Carb tier badge | custom span | colored dot + gram count: 🟢🟡🟠🔴 mapped to carb thresholds |
| Meal slot label (B / L / D / SNACK / PRE / DURING / POST) | custom `<td>` header row | `font-compadre text-caption uppercase tracking-wider text-muted-foreground` |
| Meal cell | `Card` (`rounded-card`, no shadow on dark) | Always 36px Electrolyte cyan circle on the left containing a Lucide icon (`Utensils`, `Droplet` etc.); food list as `<ul>` of `font-apercu text-body` |
| Macro totals rail | `Card` | section title in Sansita; numbers in `font-apercu-mono text-data` |
| Tweak bar | `<form>` pinned at bottom | `bg-card border-t border-border`, chips are `Badge` with `variant="outline"` rendered as pills |

**Interactions:**

- **Hover a meal cell:** subtle lift (`hover:shadow-kyle-elevated`), reveal a small "swap" affordance in the top-right corner.
- **Click a meal cell:** opens swap drawer (§4.5).
- **Click "Regenerate Week":** confirmation dialog if any cells are locked, then full-week regen with streaming.
- **Click a chip in tweak bar:** chip becomes "active" (filled), pressing Enter or clicking "Apply" runs the regen with that chip applied as a soft constraint.
- **Drag a meal cell to another day:** *not in v1.* Listed in §11 open questions.
- **Keyboard:** arrow keys navigate cells; `Enter` opens swap; `Cmd+R` triggers regenerate week (with confirmation).
- **Today's column auto-scrolls into view** on first paint.

**AI surfaces present on this screen:**

1. Coach strip (passive, single-line generation streamed in on initial load).
2. Regenerate Week button (top-of-grid, generates the entire `WeekPlan` object).
3. Per-meal swap (cell click → drawer, regenerates one slot).
4. Tweak bar (chip-based or freeform, regenerates the whole week with the new constraint applied).

See §6 for the full spec of each surface.

**Data dependencies:**

| Read | Source table / function |
|---|---|
| User's allergies, dietary_preference, gut_training_level | `users` |
| Disliked / liked foods | `food_preferences` |
| The week's planned activities | `activities` (`scheduled_date_time` BETWEEN week_start AND week_end, status IN ('planned','in_progress','completed')) |
| Daily macro targets per day | `daily_macro_targets` (`target_date` IN week range) |
| Persisted plan (if exists) | `meal_plans` + `meal_plan_meals` (new tables, §7) |
| Food catalog | `foods` (used for component substitution) |
| Pre/during/post-workout templates | `pre_workout_templates`, `during_workout_templates`, `post_workout_templates` |

| Write | Source table |
|---|---|
| Persisted plan | `meal_plans`, `meal_plan_meals` |

---

### 4.4 Day detail / drawer

**Purpose:** Sometimes a user wants to focus on one day — see all six slots, see the whole training context, possibly print/export. This is the same data as the column in the week grid, but rendered as a vertical full-width detail.

**When it opens:** clicking on the day column header (e.g., the `THU May 9` cell at the top of a column) opens this view as a right-side `Sheet`. On mobile, swiping into a single day takes you here implicitly.

**Layout (desktop sheet, 560px wide):**

```
+----------------------------------------+
|  [×]                       SAT MAY 11  |  <- close + Compadre uppercase
|                                        |
|  LONG RUN · 18 mi · 8:00 am            |  <- Sansita Bold, big
|  ────────────────────────────────────  |
|  Hard day · 320g carbs · 180g protein  |  <- Apercu, secondary
|  Coach: prioritize fast carbs and a    |
|  protein-forward dinner for recovery.  |  <- italic, muted
|                                        |
|  ┌────────────────────────────────┐    |
|  │ ◯  PRE-RUN     5:30 am         │    |
|  │     • 1 plain bagel            │    |
|  │     • 2 tbsp honey             │    |
|  │     • 8 oz black coffee        │    |
|  │     65g C · 9g P · 2g F        │    |
|  └────────────────────────────────┘    |
|                                        |
|  ┌────────────────────────────────┐    |
|  │ ◯  DURING      8:00–11:00 am   │    |
|  │     • Maurten Gel 100 ×3       │    |
|  │     • LMNT Citrus ×2 bottles   │    |
|  │     90g C · 0g P · 1,200mg Na  │    |
|  └────────────────────────────────┘    |
|                                        |
|  ┌────────────────────────────────┐    |
|  │ ◯  POST        11:30 am        │    |
|  │     • 16 oz chocolate milk     │    |
|  │     • 1 banana                 │    |
|  │     65g C · 18g P · 4g F       │    |
|  └────────────────────────────────┘    |
|                                        |
|  ┌────────────────────────────────┐    |
|  │ ◯  BREAKFAST   1:00 pm         │    |
|  │     [components]               │    |
|  └────────────────────────────────┘    |
|                                        |
|  ┌────────────────────────────────┐    |
|  │ ◯  LUNCH       4:00 pm         │    |
|  │     [components]               │    |
|  └────────────────────────────────┘    |
|                                        |
|  ┌────────────────────────────────┐    |
|  │ ◯  DINNER      7:30 pm         │    |
|  │     [components]               │    |
|  └────────────────────────────────┘    |
|                                        |
|  Day totals: 320g C · 180g P · 88g F   |
|                                        |
|  [ ⟳ regenerate this day ]             |
|  [   lock this day        ]            |
+----------------------------------------+
```

**Component inventory:** `Sheet`, `Card` (per slot), `CircularIcon` (the 36px cyan circle from `03_kyle_design_for_web.md` §7.2), `Button` (regen + lock).

**Interactions:**

- Each meal card is itself clickable → opens the swap drawer for that specific slot (§4.5).
- "Regenerate this day" preserves the rest of the week.
- "Lock this day" sets `meal_plan_meals.locked = true` for every slot in that day; locked slots are excluded from regeneration.

**AI surfaces present:** swap (per-cell, same as week view), regenerate-day (a scoped variant of regenerate-week).

**Data dependencies:** same as week view, scoped to one date.

---

### 4.5 Meal swap drawer

**Purpose:** The fastest possible "I don't like this meal" → "here are 3 alternatives" → "yes, that one." (Inspired by Eat This Much, Mealime, Fuelin Smart Meals — `01a_top_picks_summary.md` §4.)

**When it opens:** clicking any meal cell in the week grid or the day detail.

**Layout (right Sheet, 480px on desktop; bottom Sheet 90vh on mobile):**

```
+--------------------------------------------+
| [×]                  SWAP THIS MEAL        |
|                                            |
|  THU LUNCH · target 95g C · 45g P · 22g F  |
|  Currently:                                 |
|  ┌───────────────────────────────────────┐ |
|  │ ◯  6 oz grilled chicken               │ |
|  │     1 cup jasmine rice                │ |
|  │     2 cups roasted broccoli           │ |
|  │     lemon-tahini drizzle              │ |
|  │     94g C · 48g P · 21g F             │ |
|  └───────────────────────────────────────┘ |
|                                            |
|  ─── 3 ALTERNATIVES ──────────────────────  |
|                                            |
|  ┌───────────────────────────────────────┐ |
|  │ ◯  6 oz grilled salmon                │ |
|  │     1 cup farro                       │ |
|  │     2 cups asparagus + lemon          │ |
|  │     96g C · 46g P · 24g F             │ |
|  │                       [USE THIS]      │ |
|  └───────────────────────────────────────┘ |
|                                            |
|  ┌───────────────────────────────────────┐ |
|  │ ◯  Turkey + sweet potato burrito bowl │ |
|  │     8 oz turkey · 1.5 cups brown rice │ |
|  │     1 medium sweet potato             │ |
|  │     black beans · pico                │ |
|  │     97g C · 49g P · 18g F             │ |
|  │                       [USE THIS]      │ |
|  └───────────────────────────────────────┘ |
|                                            |
|  ┌───────────────────────────────────────┐ |
|  │ ◯  Tuna + quinoa power bowl           │ |
|  │     5 oz tuna · 1 cup quinoa          │ |
|  │     mixed greens · avocado            │ |
|  │     93g C · 44g P · 26g F             │ |
|  │                       [USE THIS]      │ |
|  └───────────────────────────────────────┘ |
|                                            |
|                                            |
|  [ ⟳ regenerate alternatives ]             |
|  [ Custom: type a tweak…              →]   |
+--------------------------------------------+
```

**Component inventory:** `Sheet`, current-meal `Card` (visually muted/grayscale), 3 alternative `Card`s with a primary `Button` ("USE THIS") in each, regenerate `Button` (outline), inline custom-tweak `Input`.

**Interactions:**

- **Hover an alternative:** the "USE THIS" button highlights; macros stay visible.
- **Click "USE THIS":** the current cell updates optimistically, drawer closes, sonner toast confirms ("Lunch swapped"), week macro totals recompute.
- **Click "regenerate alternatives":** re-runs the swap with the same parameters but a different sample (the LLM gets a different seed / temperature nudge).
- **Custom tweak input:** "make it vegetarian" / "I have leftover salmon" / "no rice" — fires a regen with that text appended to the swap prompt.
- **Esc / click backdrop:** closes drawer with no change.

**AI surfaces present:** swap (the primary surface here).

**Data dependencies:**
- Read: the slot's macro target (carries from the week's `daily_macro_targets`), `users.allergies`, `food_preferences`, `foods` (for the food-list tool).
- Write (on accept): one row in `meal_plan_meals`.

---

### 4.6 Tweak bar interactions and result preview

**Purpose:** Apply a soft constraint to the entire current week without opening a chat thread. Bottom-pinned, present on `/plan` always.

**Default state:**

```
┌────────────────────────────────────────────────────────────────────────┐
│  Tweak this week:  [more protein]  [no fish]  [simpler dinners]  [+]  │
└────────────────────────────────────────────────────────────────────────┘
```

**Active state (after tapping "more protein"):**

```
┌────────────────────────────────────────────────────────────────────────┐
│  Active: ● more protein   [×]                                          │
│  Tweak this week:  [no fish]  [simpler dinners]  [vegetarian]  [+]    │
│                                              [ ✕ cancel ]  [ ⟳ apply ] │
└────────────────────────────────────────────────────────────────────────┘
```

**Active state with custom input:**

```
┌────────────────────────────────────────────────────────────────────────┐
│  Active: ● more protein   ● fewer carbs Wed–Fri   [×]                  │
│  Tweak this week:  [keep simple]  [vegetarian]  [+]                    │
│  Custom: [ I'm traveling Friday — eating out for dinner          ] →  │
│                                              [ ✕ cancel ]  [ ⟳ apply ] │
└────────────────────────────────────────────────────────────────────────┘
```

**Result preview:**

When the user clicks `⟳ apply`, we do not regenerate the whole week silently. Instead we open an inline diff strip above the bar:

```
┌────────────────────────────────────────────────────────────────────────┐
│  PREVIEW · 4 of 21 meals will change                                   │
│   • Tue lunch: chicken bowl → turkey wrap                              │
│   • Wed dinner: salmon → sirloin                                       │
│   • Thu lunch: tuna → roast beef                                       │
│   • Sat dinner: cod → steak                                            │
│                                                                        │
│   [ ✕ keep current ]  [ ✓ accept all ]  [ adjust… ]                  │
└────────────────────────────────────────────────────────────────────────┘
```

**Interactions:**

- Tweaks are **stacked** soft constraints. They persist for the current planning session until cancelled.
- Tapping `[+]` reveals a small list of additional pre-canned chips (e.g., `vegetarian`, `under 30 min prep`, `no nuts this week`, `Asian flavors`) — these are not all hard constraints; they're injected as soft guidance into the system prompt.
- Custom tweaks are free text capped at 140 characters (Twitter-esque, intentionally short to discourage chat-mode behavior).
- The preview diff is generated by structured-output AI in a single round; clicking "accept all" applies it; clicking "adjust" opens the full week regen with the tweaks pre-applied.

**AI surfaces present:** tweak bar generation (whole-week scope).

**Data dependencies:** same as week view; updates `meal_plan_meals` rows for the changed slots only on accept.

---

### 4.7 Settings (food preferences view, read-only)

**Purpose:** Show the user the food preferences and allergies their plan is being built against. **Read-only in the prototype** — editing happens in the Flutter app. We surface a clear "Edit in app" link for each section.

The prototype is not a profile management surface; it's a planning surface.

**Layout:**

```
+----------------------------------------------------------+
|  SETTINGS                                                |
|                                                          |
|  PROFILE                                                 |
|  ┌────────────────────────────────────────────────────┐ |
|  │  Lee Martin · lee.b.martin@gmail.com                │ |
|  │  6'1" · 175 lbs                                     │ |
|  │  Cycling FTP: 280W · Swim CSS: 1:25/100m            │ |
|  │                                          [Edit in app] │
|  └────────────────────────────────────────────────────┘ |
|                                                          |
|  DIETARY                                                 |
|  ┌────────────────────────────────────────────────────┐ |
|  │  Diet: Omnivore                                     │ |
|  │  Allergies: peanuts, tree_nuts                      │ |
|  │  Gut training: medium                               │ |
|  │                                          [Edit in app] │
|  └────────────────────────────────────────────────────┘ |
|                                                          |
|  FOOD PREFERENCES                                        |
|  ┌────────────────────────────────────────────────────┐ |
|  │  ❤ Liked (12)                                       │ |
|  │  • Chicken breast (4/4)  • Sweet potato (4/4)       │ |
|  │  • Greek yogurt (3/4)    • Salmon (4/4)             │ |
|  │  • ...                                              │ |
|  │                                                     │ |
|  │  ✕ Disliked (5)                                     │ |
|  │  • Cilantro (4/4)   • Tofu (3/4)                    │ |
|  │  • ...                                              │ |
|  │                                          [Edit in app] │
|  └────────────────────────────────────────────────────┘ |
|                                                          |
|  TRAINING SOURCES                                        |
|  ┌────────────────────────────────────────────────────┐ |
|  │  ✓ Garmin Connect (last sync 2 hr ago)              │ |
|  │  ✓ TrainingPeaks (last sync 5 hr ago)               │ |
|  │                                          [Edit in app] │
|  └────────────────────────────────────────────────────┘ |
|                                                          |
+----------------------------------------------------------+
```

**Component inventory:** `Card` per section, `Badge` for liked/disliked, `Button variant="link"` for "Edit in app" (opens deep link / store fallback).

**Interactions:** all read-only except "Edit in app" links.

**AI surfaces:** none.

**Data dependencies:**
- `users` (full row except notification_settings)
- `food_preferences` (filtered by preference_level > 0)
- `garmin_user_mappings` and the integration sync timestamps (existing tables, see Lee's MEMORY.md note)

---

### 4.8 Empty / first-run state

**Purpose:** What does `/plan` look like when the user has authenticated, has a Mealvana profile, but has *no* `meal_plans` row for the current week yet? This is the most common first-impression state.

**Layout:**

```
+----------------------------------------------------------------------+
|  [Mealvana wordmark]   < May 6 – May 12, 2026 >                      |
+----------------------------------------------------------------------+
|                                                                      |
|                                                                      |
|         +----------------------------------------------+             |
|         |                                              |             |
|         |   YOUR WEEK IS WAITING                       |   <- Sansita
|         |                                              |             |
|         |   We've pulled your training calendar and    |   <- Apercu
|         |   macro targets for May 6 – May 12. One tap  |             |
|         |   builds your meals.                         |             |
|         |                                              |             |
|         |   This week's training:                      |             |
|         |   • Mon — rest                               |             |
|         |   • Tue — easy run, 6 mi                     |             |
|         |   • Wed — tempo run, 8 mi                    |             |
|         |   • Thu — easy run, 5 mi                     |             |
|         |   • Fri — shakeout, 4 mi                     |             |
|         |   • Sat — LONG RUN, 18 mi                    |   <- bold
|         |   • Sun — recovery swim                      |             |
|         |                                              |             |
|         |   [    PLAN MY WEEK    ]                     |   <- pill
|         |                                              |             |
|         +----------------------------------------------+             |
|                                                                      |
|                                                                      |
+----------------------------------------------------------------------+
```

**Component inventory:** `Card` (centered, max-w-lg), `Button` (default / primary).

**Interactions:**

- Pressing "Plan my week" is the first regenerate-week call. Streaming begins immediately. The empty state crossfades into the populated grid as the streamed `WeekPlan` arrives — slots fill in left-to-right, top-to-bottom in the order the LLM emits them.

**AI surfaces:** the regenerate-week surface, with the additional copy "Building your week..." replacing the button label during stream.

**Data dependencies:** same as the populated week view.

---

## 5. The Week View in Detail

This screen carries the prototype. The rest of the doc treats it lightly; here we go deep.

### 5.1 Column structure

7 columns, one per day, Mon → Sun by default (locale-aware via `Intl.Locale().weekInfo.firstDay`, but we ship with Mon-first). Each column has:

1. **Day header**: `MON / May 6` — Compadre Wide uppercase for the day-of-week, Apercu for the date.
2. **Activity summary line**: training type and headline (e.g., "tempo · 8 mi"). If no activity: `rest`.
3. **Carb tier badge**: a colored dot (Hexis traffic-light reference, `01_meal_planning_landscape.md` §1.3) + gram count, e.g. `🟠 210g`.
4. **Slot rows**, in this fixed top-to-bottom order:
   - **B** (breakfast) — always present
   - **PRE** — only on workout days where the activity starts > 1hr after wake
   - **DURING** — only on workout days where activity duration > 60 min OR carb requirement > 30g/hr
   - **POST** — only on workout days where activity duration > 45 min
   - **L** (lunch) — always present
   - **D** (dinner) — always present
   - **SNACK** — variable; auto-included on hard days, optional on rest days

### 5.2 Slot taxonomy

```ts
type MealSlot =
  | 'breakfast'     // B
  | 'pre_workout'   // PRE
  | 'during_workout'// DURING
  | 'post_workout'  // POST
  | 'lunch'         // L
  | 'dinner'        // D
  | 'snack';        // SNACK
```

Each slot has:

- A **target macro range** from `daily_macro_targets` proportionally split (see §5.5).
- A **template source**: `breakfast/lunch/dinner/snack` slots compose components from `foods`. `pre/during/post` slots use the corresponding template tables (`pre_workout_templates`, etc.) as candidate sets.
- A **lock state**: when locked, regeneration skips the slot.

### 5.3 Training overlay rendering

The activity summary line under each day header isn't decorative — it drives the slot taxonomy, the macro tier, and the visual emphasis.

**Rules:**

- Days where `activities.intensity_level IN ('high','threshold','VO2max')` OR duration > 90min OR distance > 12mi (run) / 40mi (cycle) / 3000m (swim): rendered as **HARD**. Carb tier 🔴 (red dot), bold day header, full slot row including pre/during/post.
- Days where intensity is `moderate` or duration is 45–90min: **MODERATE**. Carb tier 🟠.
- Easy / recovery: **EASY**. Carb tier 🟡.
- Rest days: **REST**. Carb tier 🟢. Pre/during/post hidden.

The thresholds above are guidelines; the actual carb tier comes from `daily_macro_targets.carb_g`:

| Tier | carb_g range | Color |
|---|---|---|
| 🟢 Low | < 150g | `electrolyte` (green-cyan, kept for accessibility) |
| 🟡 Moderate | 150–199g | `orange-light` |
| 🟠 High | 200–279g | `orange` |
| 🔴 Very high | ≥ 280g | `dragonfruit` |

(Note: the four-tier color scheme uses brand colors only — no generic red/green. This avoids the medical / clinical look. Hexis uses literal traffic-light colors; we repurpose Mealvana's palette to the same semantic.)

### 5.4 Today marker

The column whose date equals `dayjs().format('YYYY-MM-DD')` gets:

- Day header: `border-2 border-foreground rounded-card` (a 2px blackberry outline in light mode, cream in dark).
- A small `TODAY` Compadre uppercase badge above the date.
- The column auto-scrolls into horizontal view on first paint of `/plan`.

The "long run / key workout day" marker is separate:

- The slot label gets a small Electrolyte cyan dot suffix: `SAT●`.
- The activity summary line for that day is rendered in Sansita Bold (vs. Apercu on other days).

### 5.5 Macro totals — week and day

**Day totals** (rendered in the carb tier badge under the activity line):

```
🟠 210g C  ·  140g P  ·  68g F
```

These come straight from `daily_macro_targets` for the day. They are **target totals**, not summed-from-meals.

**Week totals** (rendered in the right rail):

```
WEEK TOTALS
CARBS    1,540 g   (target)
PROTEIN  1,180 g   (target)
FAT        490 g   (target)

→ 7 days planned
→ 0 days locked
```

These are sums of the daily targets. We do **not** compute "actual macros from selected meals" in v1 — that's a fidelity layer that adds complexity and depends on accurate `foods` portion data we don't yet have for arbitrary `meal_plan_meals` rows. The macro card shows the **plan target**, not adherence.

In v2 we add `meal_plan_meals.computed_carbs_g` etc. and a "selected vs target" delta visualization (see §11 open question on real-time delta).

### 5.6 Rest day vs hard day visual differences

Following Hexis's density cue (`01_meal_planning_landscape.md` §2.5 Pick 2):

| Property | Rest day | Hard day |
|---|---|---|
| Day header weight | `font-apercu` regular | `font-sansita` bold |
| Carb tier | 🟢 | 🔴 |
| Slot count visible | B/L/D + optional snack | B/PRE/DURING/POST/L/D/SNACK |
| Cell density | sparse (3 cells) | dense (7 cells) |
| Background | unchanged (cream/blackberry) | unchanged |
| Cell border | `border-border` | `border-border` (no special border) |

We deliberately do **not** color the cell backgrounds by intensity — that fights the brand. The training context is conveyed by the header treatment and the slot count, not by tinting cells.

### 5.7 Hover and click behavior on a single meal cell

**Default state:**

```
┌──────────────────────────┐
│ ◯ Bagel + honey          │
│   1 plain bagel          │
│   2 tbsp honey           │
│   8 oz black coffee      │
│   65g C · 9g P · 2g F    │
└──────────────────────────┘
```

**Hover state (desktop):**

```
┌──────────────────────────┐
│ ◯ Bagel + honey      [⟳] │   <- swap affordance reveals top-right
│   1 plain bagel          │
│   2 tbsp honey           │
│   8 oz black coffee      │
│   65g C · 9g P · 2g F    │
└──────────────────────────┘
   shadow-kyle-elevated
```

**Click anywhere on the cell:** opens the swap drawer (§4.5).

**Long-press / right-click:** opens a context menu with `Lock this meal`, `Lock this whole day`, `Why this meal?` (the last opens an inline explanation panel that calls `streamText` with the same week context — explanation surface).

### 5.8 Two more wireframes — desktop dense and mobile day

**Desktop dense (a hard day column zoomed):**

```
+--------------------+
|  SAT●     May 11   |
|  LONG RUN · 18 mi  |
|  🔴 320g C · 180gP |
+====================+
|  B    7:00 am      |
|  ┌──────────────┐  |
|  │ ◯ 3 eggs +   │  |
|  │   2 toast +  │  |
|  │   avocado    │  |
|  │   72gC 28gP  │  |
|  └──────────────┘  |
+--------------------+
|  PRE  5:30 am      |
|  ┌──────────────┐  |
|  │ ◯ Bagel +    │  |
|  │   honey +    │  |
|  │   coffee     │  |
|  │   65gC 9gP   │  |
|  └──────────────┘  |
+--------------------+
|  DUR  8–11 am      |
|  ┌──────────────┐  |
|  │ ◯ Maurten ×3 │  |
|  │   LMNT ×2    │  |
|  │   90gC, Na+  │  |
|  └──────────────┘  |
+--------------------+
|  POST 11:30 am     |
|  ┌──────────────┐  |
|  │ ◯ Choc milk +│  |
|  │   banana     │  |
|  │   65gC 18gP  │  |
|  └──────────────┘  |
+--------------------+
|  L    1:00 pm      |
|  ┌──────────────┐  |
|  │ ◯ Chicken    │  |
|  │   bowl       │  |
|  │   95gC 45gP  │  |
|  └──────────────┘  |
+--------------------+
|  D    7:30 pm      |
|  ┌──────────────┐  |
|  │ ◯ Steak +    │  |
|  │   potatoes + │  |
|  │   broccoli   │  |
|  │   88gC 52gP  │  |
|  └──────────────┘  |
+--------------------+
|  SNACK 9:00 pm     |
|  ┌──────────────┐  |
|  │ ◯ Greek yog +│  |
|  │   honey      │  |
|  │   18gC 22gP  │  |
|  └──────────────┘  |
+--------------------+
```

**Mobile single-day swipeable:** see §4.3 mobile wireframe, which is this same column rendered as a vertically scrollable page with day-pagination dots above.

---

## 6. AI Surface Specifications

Four surfaces. Each spec'd below.

### 6.1 Generation strategy: structured output, never free text

We use the Vercel AI SDK's `generateObject` (and `streamObject` for the week-regen UX) with a Zod schema. The model never emits free-text meal descriptions; it emits a tree of references to existing food and template IDs.

```ts
// /packages/web/src/lib/ai/schema.ts

import { z } from 'zod';

const FoodComponent = z.object({
  food_id: z.string().uuid().describe('FK to foods.id; must come from listFoods() tool result'),
  display_name: z.string().describe('User-facing name, exactly as in foods.name'),
  quantity: z.number().positive(),
  unit: z.string().describe('e.g., "oz", "cup", "g", "tbsp"'),
  // Macros are denormalized for snapshot stability; they are computed from foods at the time of generation.
  carbs_g: z.number().nonnegative(),
  protein_g: z.number().nonnegative(),
  fat_g: z.number().nonnegative(),
  sodium_mg: z.number().nonnegative().optional(),
});

const MealAssembly = z.object({
  slot: z.enum(['breakfast','pre_workout','during_workout','post_workout','lunch','dinner','snack']),
  scheduled_time: z.string().regex(/^\d{2}:\d{2}$/).describe('HH:mm 24h, local time'),
  title: z.string().max(80).describe('One-line headline, e.g. "Chicken + rice + broccoli"'),
  method_tag: z.string().max(60).describe('One-line cooking note, e.g., "grilled · steamed · 5 min assembly"'),
  components: z.array(FoodComponent).min(1).max(8),
  template_ref: z.object({
    table: z.enum(['pre_workout_templates','during_workout_templates','post_workout_templates']),
    template_id: z.string().uuid(),
  }).optional().describe('Required when slot is pre/during/post_workout'),
  totals: z.object({
    carbs_g: z.number(),
    protein_g: z.number(),
    fat_g: z.number(),
    sodium_mg: z.number().optional(),
  }),
});

const DayPlan = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  activity_summary: z.string().describe('One-line training summary or "rest"'),
  carb_tier: z.enum(['low','moderate','high','very_high']),
  meals: z.array(MealAssembly).min(2).max(7),
  day_totals_target: z.object({
    carbs_g: z.number(),
    protein_g: z.number(),
    fat_g: z.number(),
  }),
});

export const WeekPlan = z.object({
  week_start: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).describe('Monday of the ISO week'),
  iso_week: z.number().int().min(1).max(53),
  coach_strip: z.string().max(140).describe('One-line passive context, e.g. "High-carb week — long run Saturday"'),
  days: z.array(DayPlan).length(7),
  rationale_short: z.string().max(280).describe('Internal rationale, may surface on demand'),
});

export type WeekPlan = z.infer<typeof WeekPlan>;
```

**Key constraints encoded in the schema:**

- Every `food_id` must be a UUID — the model can't invent strings.
- `pre/during/post_workout` slots must reference a template — they can't be ad hoc.
- Macros are denormalized at write time, so the saved plan is a stable snapshot even if `foods` changes.

### 6.2 Tools the AI gets

We wire the model to a small, opinionated tool set via the AI SDK's `tools` parameter. The model composes these to build a plan; it never invents foods.

```ts
// /packages/web/src/lib/ai/tools.ts (sketch)

import { tool } from 'ai';
import { z } from 'zod';

export const tools = {
  listFoods: tool({
    description:
      'List foods from the catalog filtered by category, allergens, and dietary preference. ' +
      'Returns at most 50 foods. Use this BEFORE selecting any food in a meal.',
    inputSchema: z.object({
      categories: z.array(z.enum(['before_run','during_run','after_run','transition','meal','snack'])).optional(),
      product_type: z.enum(['gel','bar','drink','whole_food']).optional(),
      activity_type: z.enum(['running','cycling','swimming','brick','strength','rest']).optional(),
      max_results: z.number().int().min(1).max(50).default(20),
    }),
    execute: async (args) => {
      // Server-side: filter foods table by user's allergies and dietary_preference (RLS-aware).
      // Excludes: foods with any allergen ∈ user.allergies, foods with user.dietary_preference ∈ excluded_diets.
      // Soft-deprioritizes: foods in food_preferences with preference='dislike' (returned but flagged).
    },
  }),

  listTemplates: tool({
    description: 'List pre/during/post-workout templates appropriate for the user.',
    inputSchema: z.object({
      phase: z.enum(['pre','during','post']),
      activity_type: z.enum(['running','cycling','swimming','brick','strength']).optional(),
      duration_minutes: z.number().int().optional(),
    }),
    execute: async (args) => { /* query the relevant template table */ },
  }),

  getActivities: tool({
    description: 'Fetch the user\'s scheduled activities for a date range.',
    inputSchema: z.object({
      week_start: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    }),
    execute: async (args) => { /* SELECT FROM activities WHERE scheduled_date_time BETWEEN... */ },
  }),

  getMacroTargets: tool({
    description: 'Fetch daily macro targets for a date range.',
    inputSchema: z.object({
      start_date: z.string(),
      end_date: z.string(),
    }),
    execute: async (args) => { /* SELECT FROM daily_macro_targets */ },
  }),

  getUserPrefs: tool({
    description: 'Fetch the user profile and food preferences.',
    inputSchema: z.object({}),
    execute: async () => {
      // Returns: { dietary_preference, allergies, gut_training_level, gi_sensitivity, liked_foods, disliked_foods, height/weight, ftp/css }
    },
  }),
};
```

The model is instructed (via system prompt) that **before emitting any meal**, it must have called `listFoods` for that meal's category. We do not enforce this in code (would slow generation); we monitor in dev and rely on prompt discipline.

### 6.3 Prompt architecture

Sections of the system prompt, in order:

1. **Role.** "You are Mealvana's meal planning engine. You produce 7-day meal plans for endurance athletes by composing existing foods from a catalog into balanced ingredient assemblies. You never write recipes with cooking steps. You never invent foods."
2. **Hard constraints** (interpolated): "User has allergies: [peanuts, tree_nuts]. Never include foods containing these allergens. User's dietary preference is omnivore. Never include foods whose excluded_diets contains 'omnivore'."
3. **Soft constraints** (interpolated, with weights): "User dislikes (with strength 4/4): cilantro, tofu. Avoid these. User loves (4/4): chicken, sweet potato, salmon, Greek yogurt. Prefer these."
4. **Training context** (interpolated from `getActivities`): "This week: Mon rest, Tue easy run 6mi, Wed tempo 8mi, Thu easy run 5mi, Fri shakeout 4mi, **Sat LONG RUN 18mi**, Sun recovery swim. Saturday is the key workout."
5. **Macro targets** (interpolated from `getMacroTargets`): per-day carb_g, prot_g, fat_g for all 7 days.
6. **Output schema reminder.** "Emit a `WeekPlan` matching the provided schema exactly. Every `food_id` must come from a prior `listFoods` call. For pre/during/post slots, every meal must include `template_ref` from `listTemplates`."
7. **Style directives.** "Each meal title is one line, components-first ('Chicken + rice + broccoli', not 'Sunset Citrus Glazed Chicken Bowl'). The `coach_strip` is one passive sentence about the week's shape. Never address the user. Never use 'I' or 'you'. No exclamation points."
8. **Few-shot examples.** Two abbreviated examples showing a hard-day plan and a rest-day plan with their proper component density and slot structure. (See §6.7 sketch.)

### 6.4 Per-surface specifications

#### Surface 1: Regenerate Week (top-of-grid button)

| Property | Value |
|---|---|
| Trigger | Click "Regenerate Week" button or the empty-state "Plan my week" CTA |
| UX | Button label changes to "Building your week..." with a spinning Electrolyte cyan ring; cells fill in left-to-right as the stream emits days |
| AI call | `streamObject({ schema: WeekPlan, model, tools, messages, prompt })` |
| Streaming | Yes — the AI SDK streams the partial object; we render days as they complete |
| Latency target | First token < 1.5s; full plan < 12s for a 7-day week with ~5 slots/day |
| What user sees | Day columns populate progressively; coach strip arrives last |
| Failure | Sonner toast in `bg-destructive` ("Couldn't build your week — try again"); button reverts; no partial save |

#### Surface 2: Per-meal Smart Swap (cell click)

| Property | Value |
|---|---|
| Trigger | Click any meal cell, or right-click → "Swap" |
| UX | Right `Sheet` opens with current meal at top, 3 alternatives streaming in below |
| AI call | `generateObject({ schema: z.object({ alternatives: z.array(MealAssembly).length(3) }), tools, prompt: swapPrompt })` |
| Streaming | No (3 cards arrive together; the latency is acceptable as a single object) |
| Latency target | Total < 4s |
| What user sees | Skeleton placeholders for the 3 cards while generating; cards fade in together |
| Failure | Inline error in the Sheet ("Couldn't generate alternatives — try regenerating"); current meal preserved |

#### Surface 3: Coach Strip (passive)

| Property | Value |
|---|---|
| Trigger | Auto on `WeekPlan` arrival (it's a field in the schema, so it comes free with the week regen); also re-fired when any single meal is swapped (debounced 1s) |
| UX | One italic line above the grid, font-apercu, `text-muted-foreground`. Streaming dots animate while it generates separately if it lags. |
| AI call | Field of `WeekPlan.coach_strip` (no separate call); on swap-only scenarios, a tiny `generateText` call refreshes it |
| Streaming | Yes (token-by-token text streaming if separate call) |
| Latency target | <500ms when piggybacking on week regen; <1.2s when refreshed alone |
| What user sees | Old line crossfades to new |
| Failure | Silently keeps the old line |

#### Surface 4: NL Tweak Bar

| Property | Value |
|---|---|
| Trigger | User types in the bar or selects a chip and presses "Apply" |
| UX | Inline diff strip appears showing which meals will change ("4 of 21 meals will change"); user accepts or rejects |
| AI call | Two-stage: (1) `generateObject({ schema: z.object({ changes: z.array(MealChange) }) })` to compute the diff; (2) on accept, those changes are applied via direct DB writes (no second AI call) |
| Streaming | No — the diff is a single object |
| Latency target | <5s for the diff |
| What user sees | "Computing the change…" placeholder; then the diff strip; explicit accept/reject |
| Failure | Sonner toast; tweak chips remain "active" so the user can adjust and retry |

### 6.5 Model choice

Primary: **GPT-5** via Vercel AI Gateway (model id `openai/gpt-5`). Reasoning: best-in-class structured-output stability for nested schemas with tool calls; deep training on nutrition concepts; AI Gateway gives us provider failover for free.

Fallback: **Claude Sonnet 4.6** (`anthropic/claude-sonnet-4-6`). Reasoning: comparable structured-output quality, slightly different style (less likely to over-add caveats), good fallback if OpenAI is rate-limited.

Both are accessed via the AI Gateway (`AI_GATEWAY_API_KEY` env var) using the `gateway` provider in the AI SDK 5+. Switching is a one-line change. We do not commit to one model; we expose `MODEL_ID=...` as a runtime env var.

Pricing notes (rough, May 2026):
- GPT-5: ~$5/M input, ~$15/M output. A typical week regen with full prompt + tools is ~8K input tokens + ~3K output tokens ≈ $0.085/regen.
- Sonnet 4.6: ~$3/M input, ~$15/M output. Same regen ≈ $0.069.

For prototype demo with 1 user, this is negligible (<$2/month).

### 6.6 Cost controls

1. **Cache the `WeekPlan` per `(user_id, week_start)` in Supabase** (it's persisted anyway in `meal_plans`). On reload, no AI call.
2. **Swap reuses week context.** The swap prompt embeds only the relevant slot's macro target plus the existing other meals as context — not the full `WeekPlan` JSON. ~3K input tokens vs. 8K.
3. **Tweak bar diff** is bounded — we instruct the model to change at most 6 meals per tweak, keeping the diff tractable and the output small.
4. **Rate limit** regenerate-week to 1 per 30s per user (frontend-side debounce + server-side check via Vercel KV or Supabase `rate_limits` table). Swaps to 1 per 5s.
5. **Prompt caching** — both GPT-5 and Sonnet support prompt caching. The system prompt + tool definitions + user profile are stable across regens and should be marked as cacheable. This drops 50–70% of input cost.

### 6.7 Few-shot example (abbreviated)

```
[system: full prompt as in §6.3]

[user]: Build the week starting 2026-05-06. Training: Mon rest, Tue easy run 6mi, Wed tempo 8mi, Thu easy run 5mi, Fri shakeout 4mi, Sat LONG RUN 18mi, Sun recovery swim. User loves chicken, salmon, sweet potato. User dislikes cilantro, tofu. Allergies: peanuts, tree_nuts.

[assistant tool_call]: listFoods({ categories: ['meal'], product_type: 'whole_food', max_results: 30 })
[tool result]: [...30 foods with ids and macros...]

[assistant tool_call]: listTemplates({ phase: 'pre', activity_type: 'running', duration_minutes: 180 })
[tool result]: [... pre-run templates ...]

[assistant]: { week_start: "2026-05-06", iso_week: 19, coach_strip: "High-carb week — long run Saturday (18 mi). Carbs ramp Wed-Sat, taper Friday.", days: [ ...7 days... ] }
```

The few-shot is abbreviated in the actual prompt — we show one full day from a sample week and one rest day, not all seven, to keep the prompt cacheable.

---

## 7. Data Layer

### 7.1 Auth bridge: Clerk → Supabase JWT

The crux: Clerk authenticates the user. Supabase RLS expects `auth.uid()` to be a Supabase user UUID. We bridge them by minting a Clerk JWT signed with the **Supabase JWT secret**, with `sub` set to a Supabase user UUID stored in Clerk publicMetadata.

**One-time setup steps:**

1. **In Clerk dashboard → JWT Templates → New template:**
   - Name: `supabase`
   - Signing algorithm: HS256
   - Signing key: paste the Supabase project's `JWT_SECRET` (Settings → API → JWT Settings)
   - Claims:
     ```json
     {
       "aud": "authenticated",
       "role": "authenticated",
       "sub": "{{user.public_metadata.supabase_user_id}}",
       "email": "{{user.primary_email_address}}"
     }
     ```
2. **In Clerk dashboard, for each user (or via webhook on user creation):**
   - Set `publicMetadata.supabase_user_id` to their Supabase `users.id` UUID. For Lee in dev: `607f9dd5-6fa7-48ee-a628-720d4a0506a1`. For new users this is set during the onboarding bridge (§4.2) by matching email to an existing Supabase row.
3. **In our app code**, when initializing the Supabase client per request:
   ```ts
   // /packages/web/src/lib/supabase.ts
   import { createClient } from '@supabase/supabase-js';
   import { useAuth } from '@clerk/tanstack-react-start';

   export function useSupabase() {
     const { getToken } = useAuth();
     return useMemo(() => {
       return createClient(
         import.meta.env.VITE_SUPABASE_URL,
         import.meta.env.VITE_SUPABASE_ANON_KEY,
         {
           accessToken: async () => (await getToken({ template: 'supabase' })) ?? null,
         }
       );
     }, [getToken]);
   }
   ```
   The `accessToken` callback runs on every Supabase request, fetching a fresh Clerk-issued JWT with the `supabase` template. Supabase's PostgREST and Realtime accept it as if it came from Supabase Auth itself.

4. **For server-side Supabase calls** (in TanStack Start `createServerFn` handlers, AI tool `execute` functions): use Clerk's `auth().getToken({ template: 'supabase' })` from `@clerk/tanstack-react-start/server`.

5. **Service-role calls** (for the new tables we create, when we want to bypass RLS — should be rare in v1) use the `SUPABASE_SERVICE_ROLE_KEY` env var.

**Reference docs:** `/Users/leemartin/development/mealvana_endurance/docs/mealplanning_prototype/04_user_data_inventory.md` §6 confirms the existing RLS pattern uses `auth.uid() = user_id`. The Clerk JWT template's `sub` claim becomes Supabase's `auth.uid()`.

### 7.2 Existing tables we read

All read-only from the prototype's perspective. Cited from `04_user_data_inventory.md`:

| Table | Columns we use | Reference |
|---|---|---|
| `users` | `id`, `gender`, `birthday`, `height_feet`, `height_inches`, `weight_pounds`, `dietary_preference`, `allergies`, `gut_training_level`, `gi_sensitivity`, `cycling_ftp_watts`, `swimming_css_seconds_per_100m`, `weight_unit` | `04_user_data_inventory.md` §1.1 |
| `food_preferences` | `user_id`, `food_name`, `preference`, `preference_level` | §1.2 |
| `activities` | `id`, `user_id`, `title`, `scheduled_date_time`, `status`, `activity_type`, `duration_minutes`, `intensity_level`, `distance_miles`, `distance_meters`, `power_avg_watts`, `brick_segments`, `nutrition_plan_data` | §2.1 |
| `daily_macro_targets` | `user_id`, `target_date`, `carb_g`, `prot_g`, `fat_g`, `tdee`, `session_kcal`, `mode`, `algorithm_version` | §3.1 |
| `foods` | `id`, `name`, `product_type`, `activity_types`, `categories`, `calories_per_serving`, `carbs_g`, `protein_g`, `fat_g`, `sodium_mg`, `caffeine_mg`, `sugar_g`, `fiber_g`, `serving_size`, `serving_grams`, `allergens`, `excluded_diets`, `max_servings_before/during/after` | §4.1 |
| `catalog_products` + `catalog_variants` | All catalog columns; surfaced via the `catalog_items` view | §4.2 |
| `pre_workout_templates` | `template_number`, `name`, `recovery_window`, `component_food_names`, `component_ratios`, `target_carb_protein_ratio`, `allergens`, `excluded_diets` | §4.3 |
| `during_workout_templates` | (same shape) | §4.4 |
| `post_workout_templates` | `recovery_type`, `recovery_window`, `component_food_names`, `component_ratios`, `allergens`, `excluded_diets` | §4.5 |

Edge functions we may call (read-only, from server-side route handlers):

- `generate-macros-v4` — only if `daily_macro_targets` is missing for a date in the requested week. We do not normally trigger this; the Flutter app populates it. If a date is missing, we render a banner: "Macros not yet computed for Thu — open the mobile app to generate." (See §11 open question on whether the prototype should call this itself.)

### 7.3 New tables proposed

Two tables. Minimal. They store the persisted plan; everything else stays in the existing schema.

```sql
-- migrations/20260507000000_create_meal_plans.sql

CREATE TABLE meal_plans (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  week_start      DATE NOT NULL,                              -- Monday of the ISO week
  iso_week        INTEGER NOT NULL,
  iso_year        INTEGER NOT NULL,
  coach_strip     TEXT,                                       -- the one-line passive summary
  rationale       TEXT,                                       -- internal "why this week"
  generation_model TEXT,                                      -- 'openai/gpt-5', 'anthropic/claude-sonnet-4-6', etc.
  generation_input_hash TEXT,                                 -- hash of (activities + targets + prefs) for cache invalidation
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, week_start)
);

CREATE INDEX meal_plans_user_week_idx ON meal_plans (user_id, week_start DESC);

CREATE TABLE meal_plan_meals (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_plan_id    UUID NOT NULL REFERENCES meal_plans(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, -- denormalized for RLS efficiency
  date            DATE NOT NULL,
  slot            TEXT NOT NULL CHECK (slot IN (
                    'breakfast','pre_workout','during_workout',
                    'post_workout','lunch','dinner','snack'
                  )),
  scheduled_time  TIME,                                      -- HH:mm:ss local
  title           TEXT NOT NULL,
  method_tag      TEXT,
  components      JSONB NOT NULL,                            -- array of FoodComponent (see §6.1)
  template_table  TEXT,                                      -- 'pre_workout_templates' etc., NULL for B/L/D/snack
  template_id     UUID,                                      -- FK to the relevant template table, NULL otherwise
  totals          JSONB NOT NULL,                            -- { carbs_g, protein_g, fat_g, sodium_mg }
  locked          BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (meal_plan_id, date, slot)
);

CREATE INDEX meal_plan_meals_plan_date_idx ON meal_plan_meals (meal_plan_id, date);
CREATE INDEX meal_plan_meals_user_date_idx ON meal_plan_meals (user_id, date);
```

**Why two tables, not just one with a `days JSONB` column?**

- Per-slot updates (swaps) are common; updating one row is cheaper than rewriting a 50KB JSON.
- `locked` is a per-slot boolean; lifting it out of JSON makes regeneration queries trivial (`WHERE NOT locked`).
- Future: meal logging (actual consumption) joins cleanly to `meal_plan_meals.id`.

**Why denormalize `user_id` on `meal_plan_meals`?** RLS performance. Without it, every RLS check on `meal_plan_meals` would need a join to `meal_plans` to find the user. With it, the policy is `auth.uid() = user_id` direct.

### 7.4 RLS policies for new tables

```sql
ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plan_meals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own meal plans"
  ON meal_plans FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own meal plan meals"
  ON meal_plan_meals FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role full access on meal_plans"
  ON meal_plans FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "Service role full access on meal_plan_meals"
  ON meal_plan_meals FOR ALL TO service_role
  USING (true) WITH CHECK (true);
```

### 7.5 Data flow diagram

```
+---------+       Clerk JWT (signed w/ Supabase JWT secret)
| Browser | <------------------------------------------------+
|         |                                                  |
| /plan   |                                                  |
+---------+                                                  |
     |                                                       |
     | (1) Server-side loader on /plan                       |
     v                                                       |
+--------------------+                                       |
| TanStack Start     |                                       |
| createServerFn     |                                       |
|  - get auth state  |--+ (2) Mints Supabase JWT              |
|  - read DB         |  |                                    |
+--------------------+  |                                    |
     |                  |                                    |
     | (3) RLS-filtered queries                              |
     v                  v                                    |
+----------------------------------+                         |
| Supabase Postgres (dev project)  |                         |
|                                  |                         |
| users, food_preferences,         |                         |
| activities, daily_macro_targets, |                         |
| foods, *_workout_templates,      |                         |
| meal_plans, meal_plan_meals      |                         |
+----------------------------------+                         |
                                                             |
+---------+      (4) User clicks "Regenerate Week"          |
| Browser |---------------------------------------------------+
|         |                                                   |
+---------+                                                   |
     |                                                        |
     | POST /api/regenerate-week                              |
     v                                                        |
+----------------------------+                                |
| TanStack Start route       |                                |
| /api/regenerate-week.ts    |                                |
|                            |                                |
|  streamObject({            |                                |
|    schema: WeekPlan,       |                                |
|    model: gateway('gpt-5'),|                                |
|    tools: { listFoods,     |                                |
|             listTemplates, |                                |
|             ... },         |                                |
|    messages, prompt        |                                |
|  })                        |                                |
+----------------------------+                                |
     |                          |                             |
     | (5) Tool execute fns query Supabase                    |
     |                          v                             |
     |                  +----------------------+              |
     |                  | Supabase Postgres   |               |
     |                  +----------------------+              |
     |                                                        |
     | (6) Stream Server-Sent Events back                     |
     v                                                        |
+--------------+                                              |
| Vercel AI    |                                              |
| Gateway      |  -------- (7) calls model provider --------> |  GPT-5 / Sonnet 4.6
+--------------+                                              |
     |                                                        |
     | (8) Streamed partial WeekPlan                          |
     v                                                        |
+---------+   (9) Cells fill in as days arrive                |
| Browser | <------------------------------------------------+
+---------+
     |
     | (10) On stream complete: persist
     v
+----------------------------+
| TanStack Start route       |
| /api/save-week-plan.ts     |
|  - INSERT meal_plans        |
|  - INSERT meal_plan_meals   |
+----------------------------+
```

### 7.6 Server-side query examples

```ts
// /packages/web/src/lib/queries/week.ts

export async function loadWeekData(supabase: SupabaseClient, weekStart: string) {
  const weekEnd = dayjs(weekStart).add(6, 'day').format('YYYY-MM-DD');
  const [activities, targets, prefs, user, plan] = await Promise.all([
    supabase
      .from('activities')
      .select('id, title, scheduled_date_time, status, activity_type, duration_minutes, intensity_level, distance_miles, distance_meters, brick_segments')
      .gte('scheduled_date_time', `${weekStart}T00:00:00`)
      .lt('scheduled_date_time', `${dayjs(weekEnd).add(1, 'day').format('YYYY-MM-DD')}T00:00:00`)
      .in('status', ['planned', 'in_progress', 'completed']),
    supabase
      .from('daily_macro_targets')
      .select('target_date, carb_g, prot_g, fat_g, tdee, session_kcal')
      .gte('target_date', weekStart)
      .lte('target_date', weekEnd),
    supabase
      .from('food_preferences')
      .select('food_name, preference, preference_level')
      .gt('preference_level', 0),
    supabase
      .from('users')
      .select('dietary_preference, allergies, gut_training_level, gi_sensitivity')
      .single(),
    supabase
      .from('meal_plans')
      .select('id, coach_strip, generation_model, meal_plan_meals(*)')
      .eq('week_start', weekStart)
      .maybeSingle(),
  ]);
  return { activities, targets, prefs, user, plan };
}
```

---

## 8. Brand Application

The Kyle design system from `03_kyle_design_for_web.md` is non-negotiable. Here's how it maps onto the meal planner specifically.

### 8.1 Surfaces

| Surface | Background | Foreground | Notes |
|---|---|---|---|
| App shell / page background | `bg-background` (cream `#F8F6EB` light, blackberry `#381633` dark) | `text-foreground` | Never `bg-gray-50`. Never `bg-white`. |
| Meal cards | `bg-card` (white `#FFFFFF` light, blackberry-light `#4A2854` dark) | `text-card-foreground` | `rounded-card` (15px), `shadow-kyle-card dark:shadow-none`, 1px border in dark |
| Coach strip | `bg-muted` (cream-dark `#E8E6E0` light, an in-between blackberry tone dark) | `text-muted-foreground` | Italic, no border, gentle rest |
| Tweak bar | `bg-card border-t border-border` | `text-card-foreground` | Sticky bottom, full width |
| Macro totals rail | `bg-card` | mixed | Numbers in `font-apercu-mono text-data` |
| Swap drawer | `bg-card` | `text-card-foreground` | Full-height sheet, Kyle border treatment |

### 8.2 Components-only meal-card layout

The single most distinctive piece of the meal planner. Every meal cell renders in this exact structure:

```
┌──────────────────────────┐
│ ◯  Title in Compadre     │   <- 36px Electrolyte cyan circle, then title in font-compadre uppercase tracking-wider
│                          │
│   • component 1          │   <- font-apercu text-body, bullet glyph
│   • component 2          │
│   • component 3          │
│   ...                    │
│                          │
│   method-tag in italics  │   <- font-apercu text-caption italic muted
│   (e.g., grilled · 5min) │
│                          │
│   72g C · 28g P · 12g F  │   <- font-apercu-mono text-caption, blackberry
└──────────────────────────┘
```

Specifically:

- **Circular icon (left of title):** `<CircularIcon icon={faUtensilsAlt} />` — 36px wide, electrolyte cyan fill (`bg-accent`), blackberry icon (`text-accent-foreground`). Icon glyph chosen by slot:
  - `breakfast`: `faEggFried`
  - `lunch`: `faBowlFood`
  - `dinner`: `faPlateUtensils`
  - `snack`: `faAppleWhole`
  - `pre_workout`: `faPersonRunningFast` (or `faBolt`)
  - `during_workout`: `faDroplet`
  - `post_workout`: `faGlassWater` (or `faBlender`)
- **Title:** `font-compadre text-descriptor uppercase tracking-wider` — e.g., "CHICKEN + RICE + BROCCOLI"
- **Components list:** plain `<ul>` with bullet `•` glyphs in blackberry, `font-apercu text-body`. Each item: `[quantity unit] [food name]`. No images.
- **Method tag:** small italic line, `font-apercu text-caption italic text-muted-foreground`.
- **Macro line:** Apercu Mono per Figma intent, `text-caption tracking-wider`.

This card is what makes us distinct from every recipe app. We must not have photos, "prep time" badges in pill chrome, or step-by-step instructions in a meal cell.

### 8.3 Cyan icon system per food category

Each meal slot icon is in an Electrolyte cyan circle (`bg-accent text-accent-foreground`) regardless of theme. Within meal cells, individual food components are not iconified — only the slot-level icon. This keeps the visual rhythm clean.

For the macro tier dots (see §5.3), we deliberately **don't** use real traffic-light colors:

- 🟢 Low carbs → `bg-electrolyte` (cyan-green)
- 🟡 Moderate → `bg-orange-light` (Mango light)
- 🟠 High → `bg-orange` (Mango)
- 🔴 Very high → `bg-dragonfruit` (magenta)

This keeps the brand consistent and avoids the medical-clinical look of literal green/yellow/red.

### 8.4 Button and chip vocabulary

| Use | Variant | Tailwind class |
|---|---|---|
| Primary CTA ("Regenerate Week", "Plan my week", "Use this" in swap) | `<Button>` default | `rounded-pill bg-primary text-primary-foreground font-sansita uppercase tracking-wider h-btn-h` |
| Secondary outlined ("Lock this day", "Cancel") | `<Button variant="outline">` | `border-2 border-foreground rounded-pill font-sansita uppercase` (per `03_kyle_design_for_web.md` §10 open question 7 — neutral, not orange) |
| Tertiary text ("Edit in app", "Sign up") | `<Button variant="ghost">` | dragonfruit text, no chrome, `font-apercu` normal case |
| Tweak chips | `<Badge>` styled as pill toggle | `rounded-pill border border-border bg-transparent hover:bg-accent/10 text-foreground font-apercu` |
| Active tweak chip | toggled state | `bg-foreground text-background` |
| Swap "USE THIS" button | `<Button variant="default" size="sm">` | smaller pill, same orange |

### 8.5 Dark vs light mode plan

Per `03_kyle_design_for_web.md` §8: `next-themes` style class switching, but we're on TanStack Start, not Next.js. We use the equivalent: a `theme` cookie + a small client provider that applies `class="dark"` on `<html>`.

Specifics for the planner:

- **Cards in light mode** are pure white (`#FFFFFF`) on cream — no cream-on-cream. The 15px border-radius and the subtle 0 2px 8px shadow create the depth.
- **Cards in dark mode** are blackberry-light (`#4A2854`) on blackberry background, no shadow, with `border` at low opacity (cream/10).
- **The macro tier dots** are bright in both modes — they're brand colors, not surface colors. They pop against both cream and blackberry.
- **The Electrolyte cyan circles** are loud against blackberry and politely loud against cream — they're a brand choice, not a contrast choice.
- **The coach strip in dark mode** uses `bg-muted` (`#4A2854` to `#5A3366` range) with cream/80 italic text. It must read as "ambient context," never as "alert."

### 8.6 Font wiring

Following `03_kyle_design_for_web.md` §3.3, but in TanStack Start (not Next.js):

```tsx
// /packages/web/src/styles/fonts.css
@import url('https://fonts.googleapis.com/css2?family=Sansita:wght@700;800&family=Work+Sans:wght@400;500&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');

:root {
  --font-sansita: 'Sansita', ui-serif, Georgia, serif;
  --font-compadre: 'Work Sans', ui-sans-serif, system-ui, sans-serif;
  --font-apercu: 'Inter', ui-sans-serif, system-ui, sans-serif;
  --font-apercu-mono: 'JetBrains Mono', ui-monospace, monospace;
}
```

Until Apercu and Compadre Wide licensing is sorted, we use Inter / Work Sans / Sansita / JetBrains Mono via Google Fonts (per `03_kyle_design_for_web.md` §3.2). Compadre Wide is simulated via Work Sans + `tracking-wider` + `uppercase`.

Usage map for the planner specifically:

- **Page title** (`h1` on `/plan`, "Plan my week" CTA): `font-sansita`
- **Day-of-week column header** ("MON / TUE / ..."): `font-compadre uppercase tracking-wider`
- **Meal cell title** (the components-first headline): `font-compadre uppercase tracking-wider` — this is critical, makes meal titles feel like food labels
- **Components list inside a meal cell**: `font-apercu` (Inter) regular
- **Macro numbers** (week totals, day totals, per-meal): `font-apercu-mono` (JetBrains Mono)
- **Coach strip**: `font-apercu italic`
- **Tweak chip labels**: `font-apercu` regular
- **CTA pill button labels** (REGENERATE WEEK, USE THIS): `font-sansita uppercase`

---

## 9. What We're Explicitly NOT Building in the Prototype

The prototype is for one demo, one user (Lee), one workflow. We are aggressive about scope.

| Feature | Why not in v1 | Reference |
|---|---|---|
| **Pantry / leftover scanning** | Photo recognition is immature (90% accuracy per `01_meal_planning_landscape.md` §2.2 Pattern 4); requires upload pipeline, file storage, model integration that is its own track | §2.2 Pattern 4 |
| **Grocery list export** | Recipe-style apps generate this; ingredient-bundle apps need a different aggregation model; defer until we know what athletes actually buy | `01a_top_picks_summary.md` §Direction 1 implies grocery list comes for free |
| **Social / sharing** | No coach-on-athlete writes in this prototype; no public profiles; v2 territory | n/a |
| **Recipe steps** | Explicit anti-feature. "Components, never recipes." (Principle 1, §2.) | §2 |
| **Photo upload** | No food images, no meal hero photos. The cream/blackberry typographic identity is the differentiator. | §8 |
| **Multi-user / coach view** | Out of scope; the existing Flutter app handles coach-paired flows | `04_user_data_inventory.md` §6 |
| **Mobile native** | Web only. The prototype runs in a browser on iOS/Android via responsive layout | §3 |
| **Adherence tracking / meal logging** | The schema gap noted in `04_user_data_inventory.md` §7.1; we'd need a `meal_log` table | §7.1 |
| **Race calendar phasing** | The `01a §Direction 2` outside-the-box idea — too big for v1, parked for v2 | §11 |
| **Intra-day adaptation ("living plan")** | Direction 3 in `01a_top_picks_summary.md` — requires real-time state; v2 | §11 |
| **Voice input on tweak bar** | Tempting but adds a permission and API surface; v2 | n/a |
| **Drag-and-drop meal swap between days** | Useful but the swap drawer covers 95% of use cases; v2 | §4.3 |
| **Editable food preferences in web** | Read-only in `/settings`; editing stays in Flutter app | §4.7 |
| **Custom meal templates ("My Rotation")** | The Direction 1 idea — most exciting v2 candidate, deferred | §11 |
| **Streamed coach-strip refresh on every cell hover** | Cute but expensive; coach strip refreshes on regen + on swap accept only | §6.4 |
| **Multi-week view** | Only the current week + prev/next navigation; no quarterly or seasonal view | §3 |
| **Notifications / reminders** | No push, no email; this is a planning surface, not a daily cadence app | n/a |

---

## 10. Phased Build Plan

Six phases (Phase 0 through 5). Each phase ends with a demoable moment.

### Phase 0 — Project scaffold

**Effort:** 1 day

**Deliverables:**

- `/Users/leemartin/development/mealplanning_prototype/` initialized as a pnpm monorepo (single `packages/web/` is fine; no need for the four-package layout from `me_website_new` since we're not using Convex or Sanity here).
- TanStack Start + Vite + Nitro app in `packages/web/`.
- React 19, TypeScript 5.9, Tailwind v4 (CSS-first config in `globals.css`), shadcn/ui registered with `components.json`.
- Initial shadcn primitives installed: `button card dialog form input label select tabs sonner skeleton dropdown-menu sheet badge separator scroll-area`.
- Kyle brand tokens wired into `globals.css` (full §2.3 of `03_kyle_design_for_web.md` pasted in).
- Fonts loaded (Sansita + Inter + Work Sans + JetBrains Mono via Google Fonts).
- Clerk auth fully wired: `<ClerkProvider>` in `__root.tsx`, `/sign-in`, `/sign-up`, server-side `requireAuth`.
- Supabase client wired with Clerk JWT bridge per §7.1.
- `/styleguide` route demonstrating Kyle's pill button, Card, CircularIcon, theme toggle.
- ESLint + Prettier + Husky + lint-staged.

**Key files to create:**

```
mealplanning_prototype/
├── package.json
├── pnpm-workspace.yaml
├── .nvmrc
├── vercel.json
├── packages/web/
│   ├── package.json
│   ├── vite.config.ts
│   ├── tsconfig.json
│   ├── components.json
│   ├── playwright.config.ts
│   ├── vitest.config.ts
│   ├── src/
│   │   ├── start.ts                    # Clerk middleware
│   │   ├── router.tsx
│   │   ├── routes/
│   │   │   ├── __root.tsx              # Providers + shell
│   │   │   ├── index.tsx               # Redirect to /plan
│   │   │   ├── (auth)/sign-in.tsx
│   │   │   ├── (auth)/sign-up.tsx
│   │   │   ├── styleguide.tsx
│   │   │   └── plan.tsx                # Empty stub for now
│   │   ├── components/
│   │   │   ├── ui/                     # shadcn primitives, Kyle-themed
│   │   │   └── circular-icon.tsx
│   │   ├── lib/
│   │   │   ├── utils.ts                # cn()
│   │   │   ├── auth.ts                 # Clerk server fns
│   │   │   ├── supabase.ts             # Supabase client + Clerk JWT bridge
│   │   │   └── theme.ts                # Theme toggle hook
│   │   └── styles/
│   │       └── globals.css             # Tailwind v4 + Kyle tokens
```

**Demoable moment:** Sign in → land on `/styleguide` → see Kyle's Mango pill button, Electrolyte cyan circular icon, Sansita uppercase, Compadre uppercase tracked, Apercu body, dark/light toggle. Click "Sign out" → redirect to `/sign-in`.

### Phase 1 — Read-only week view rendering real data

**Effort:** 2 days

**Deliverables:**

- `/plan` route with the week grid skeleton.
- `loadWeekData` server function (per §7.6) populates the grid from real `activities` + `daily_macro_targets`.
- Day columns rendered with Compadre headers, today marker, carb tier badges (mapped from `daily_macro_targets.carb_g`), training overlay (activity title + duration).
- Right-rail macro totals card.
- Empty state (§4.8) when `meal_plans` row is missing.
- Mobile single-day view (per §4.3 mobile wireframe).
- No AI yet; meal cells render as empty placeholders ("No meal yet") if `meal_plan_meals` is empty.

**Key files:**

```
src/
├── routes/plan.tsx                     # The route
├── components/plan/
│   ├── week-grid.tsx                   # 7-column desktop grid
│   ├── day-column.tsx
│   ├── meal-cell.tsx
│   ├── macro-totals-rail.tsx
│   ├── carb-tier-badge.tsx
│   ├── coach-strip.tsx                 # Static placeholder
│   ├── tweak-bar.tsx                   # Static placeholder
│   ├── empty-state.tsx
│   └── mobile-day-view.tsx
├── lib/queries/
│   └── week.ts                         # loadWeekData
└── lib/types/
    └── week.ts                         # WeekPlan types (Zod schema, even though no AI yet)
```

**Demoable moment:** Open `/plan` for Lee's account → see the empty state with his real Saturday-long-run training listed, Sunday's actual planned activity, etc.

### Phase 2 — Regenerate-week AI flow with structured output and tool use

**Effort:** 3 days

**Deliverables:**

- `/api/regenerate-week` server route using `streamObject({ schema: WeekPlan, tools, model })`.
- Vercel AI SDK 5+ installed; AI Gateway wired (`AI_GATEWAY_API_KEY`).
- All 5 tools implemented (`listFoods`, `listTemplates`, `getActivities`, `getMacroTargets`, `getUserPrefs`).
- System prompt assembled per §6.3.
- Streaming UI: cells fade in as the partial `WeekPlan` arrives.
- Non-streaming fallback path for browsers/dev modes that don't support SSE.
- Coach strip populated from `WeekPlan.coach_strip`.
- Failure handling: sonner toast on error, button reverts.

**Key files:**

```
src/
├── routes/api/regenerate-week.tsx      # Server route
├── lib/ai/
│   ├── schema.ts                       # WeekPlan Zod schema
│   ├── tools.ts                        # 5 tools
│   ├── prompts.ts                      # System prompt builder
│   └── gateway.ts                      # AI Gateway client setup
├── components/plan/
│   ├── regenerate-week-button.tsx
│   └── streaming-grid.tsx              # Renders partial WeekPlan as it arrives
└── lib/hooks/
    └── use-regenerate-week.ts          # @ai-sdk/react useObject hook
```

**Demoable moment:** Empty week → click "Plan my week" → grid populates day-by-day over ~10 seconds with real foods from Supabase. Coach strip arrives at the end.

### Phase 3 — Per-meal swap + coach strip

**Effort:** 2 days

**Deliverables:**

- Click any cell → swap drawer (`<Sheet>`) opens.
- 3 alternatives via `generateObject` with the same tools, scoped to one slot.
- "USE THIS" button on each → optimistic UI update + persist (deferred to Phase 5 — for now the swap is in-memory only, persistence is in Phase 5).
- Coach strip refreshes after a swap is accepted (debounced 1s).
- Custom-tweak input inside the swap drawer.
- Right-click context menu: Lock, "Why this meal?" (the why surface streams `streamText` answer in a popover).

**Key files:**

```
src/
├── routes/api/swap-meal.tsx
├── components/plan/
│   ├── meal-swap-drawer.tsx
│   ├── alternative-card.tsx
│   └── why-this-meal-popover.tsx
└── lib/ai/
    └── swap-prompt.ts                  # The slot-scoped prompt
```

**Demoable moment:** Click Wednesday lunch → drawer slides in → 3 alternatives appear → click "USE THIS" on the salmon one → cell updates instantly → coach strip subtly updates ("More fish this week — moderate iron load"). Optionally type "make it vegetarian" → 3 new alternatives.

### Phase 4 — NL tweak bar with chips

**Effort:** 2 days

**Deliverables:**

- Bottom-pinned tweak bar with starter chips: `more protein`, `no fish`, `simpler dinners`, `vegetarian`, `+ custom`.
- Tweaks accumulate as "active" badges.
- Click "Apply" → preview diff strip ("4 of 21 meals will change") via `generateObject`.
- Accept → apply changes; reject → revert.
- Custom-text input capped at 140 chars.

**Key files:**

```
src/
├── components/plan/
│   ├── tweak-bar.tsx                   # Replace Phase 1 placeholder
│   ├── tweak-chip.tsx
│   ├── tweak-preview-strip.tsx
│   └── tweak-custom-input.tsx
├── routes/api/preview-tweak.tsx        # Server route returning the diff
└── lib/ai/
    └── tweak-prompt.ts
```

**Demoable moment:** Click "no fish" → the chip becomes active → click "Apply" → preview strip appears ("3 of 21 meals will change: Tue lunch, Thu lunch, Sat dinner") → click "Accept all" → those 3 cells update inline.

### Phase 5 — Persistence + small polish pass

**Effort:** 2 days

**Deliverables:**

- New tables `meal_plans` + `meal_plan_meals` deployed to dev Supabase via migration (per §7.3).
- RLS policies applied (per §7.4).
- All AI flows persist their output:
  - Regenerate week → INSERT/UPSERT a `meal_plans` row + 7 days × ~5 slots = ~35 `meal_plan_meals` rows.
  - Swap → UPDATE one `meal_plan_meals` row.
  - Tweak accept → UPDATE 1–6 `meal_plan_meals` rows in a single transaction.
- Lock/unlock per slot (`meal_plan_meals.locked` toggle).
- Lock-aware regeneration (skip locked slots in prompts, exclude from output schema).
- Reload `/plan` → loads from `meal_plans` instantly with no AI call.
- `/settings` read-only profile screen (per §4.7).
- Sentry wired (use `@sentry/tanstackstart-react` if available, else manual).
- Final brand pass: confirm every surface uses tokenized colors, no stray Tailwind grays; confirm fonts loaded; confirm cream/blackberry transitions are crisp.

**Key files:**

```
supabase/migrations/
└── 20260507000000_create_meal_plans.sql

src/
├── lib/queries/
│   ├── save-week-plan.ts
│   ├── update-meal.ts
│   └── apply-tweak.ts
└── routes/
    ├── settings.tsx
    └── settings/preferences.tsx
```

**Demoable moment:** Build a week, swap two meals, lock Saturday, refresh the browser → everything persists. The week is loaded instantly from the DB. Open `/settings` → see Lee's real profile pulled from `users` and `food_preferences`.

### Total effort estimate

~12 working days for one engineer to ship the prototype end-to-end. Add 2–3 days buffer for AI iteration on prompt quality.

---

## 11. Open Questions / Decisions Still to Make

These are the questions Lee still needs to weigh in on. Numbered for traceability.

1. **Does the prototype call `generate-macros-v4` itself, or is `daily_macro_targets` always assumed populated?** Right now we assume the Flutter app populates targets and the prototype just reads. If the user navigates to a future week with no targets yet, what do we render?
2. **Restaurant / eating-out mode?** Fuelin Smart Meals (`01_meal_planning_landscape.md` §1.3) detects context (home / restaurant / road) and generates differently. Should our swap drawer have a "I'm eating out" toggle, or do we treat that as a v2?
3. **Pin-a-meal feature.** The `meal_plan_meals.locked` boolean exists; we surface it via right-click → Lock and the day-detail "Lock this day" button. Should we also auto-lock meals the user has explicitly accepted via a swap (so a regenerate-week respects past choices), or keep regen as a clean slate?
4. **Snack auto-expansion on hard days.** §5.1 has hard days showing a snack slot by default. Should the user be able to add a second snack on hard days, or one snack max per day in v1?
5. **Meal cell density on rest days.** §5.6 shows rest days with B/L/D + optional snack. Some athletes eat 5 small meals daily. Do we always show a snack slot (even on rest days), or stick with B/L/D-only on rest days unless training calls for more?
6. **Coach strip frequency.** Currently it refreshes on regen + swap-accept (debounced 1s). Should it also refresh when activities change in `activities` (e.g., user moves Saturday's long run to Sunday)? That would require a Supabase real-time subscription.
7. **Tweak chip starter set.** Right now: `more protein`, `no fish`, `simpler dinners`, `vegetarian`. Do we want the chip set to be context-adaptive (different chips on hard days vs rest days)?
8. **Swap drawer "Why this meal?" surface.** Built into Phase 3 via right-click context menu. Should this be more discoverable (e.g., a small `(?)` icon on every cell), or kept hidden as a power-user feature?
9. **Failure recovery on regen mid-stream.** If the AI stream errors out at day 4 of 7, do we (a) render the partial 4 days and let the user manually swap the rest, (b) revert entirely and show an error, or (c) auto-retry in the background?
10. **First-run nudge to set food preferences.** If `food_preferences` is empty, the AI has no soft-constraint signal. Do we show an inline coach-strip nudge ("Add some food preferences in the mobile app for better suggestions"), or trust the regenerate to produce reasonable defaults from `dietary_preference` alone?

---

## 12. Inspiration Credits

Direct lineage from the landscape report's top picks (`01a_top_picks_summary.md` §Top 5 Picks):

- **Fuelin Smart Meals** — the "AI silently generates 3 contextual cards, no chatbot" model is the spine of our swap drawer (§4.5) and the empty-state regeneration flow (§4.8).
- **RP Diet Coach column-selection food lists** — informs the "components-only meal cell" layout (§8.2) and the principle of showing food choices, not recipes (§2 Principle 1).
- **Hexis Carb Coding traffic-light** — the per-day carb tier badge with brand-color-mapped traffic-light semantics (§5.3).
- **Mealime swap loop + 119-ingredient exclusion list** — the per-meal swap UX with 3 alternatives (§4.5) and the soft/hard constraint model (§2 Principle 5).
- **Eat This Much "generate → selective swap → lock"** — the overall interaction loop on `/plan` (§5.7, §6.4 surface 2, §11 open question 3).
- **HelloFresh label scan-and-decide** — the dense meal-cell info hierarchy (icon + title + components + macros) that lets a user accept/swap in <10s (§5.7).

End of master design proposal.
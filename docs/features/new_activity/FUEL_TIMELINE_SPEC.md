# Fuel Timeline — Reproduction Spec (New Day / Activity Screen, v9)

Source prototype: `docs/features/new_activity/New Activity page v9 - smaller dashboard footprint/`
DeepCanvas (`.dc.html`) React prototype. Served + clicked through 2026-06-25.
Canonical interactive file: `Fuel Timeline (standalone).html`. Readable source: `Fuel Timeline -standalone source-.html`.

This document captures the **exact design and behavior** so the screen can be reproduced in Flutter.

> **Source confirmed (Lee, 2026-06-25):** the live prototype at
> `https://sunny-pumpkin-patch.github.io/prototypes/logging/` is byte-for-byte the
> same design as the v9 folder — re-verified end-to-end in-browser (main screen,
> meal expand → Swap/Remove, All/Workout/Meals dashboards, Ride Fuel sheet). The
> Fuel Timeline screen + its **in-app** sheets (Energy Breakdown, Ride Fuel Plan)
> must match this design exactly.

> **EXCEPTION — entry screens stay ours (Lee, 2026-06-25):** the prototype's mock
> food-add and activity-add surfaces are NOT rebuilt. Anywhere the design opens a
> "+ Add Food", "Swap", or "+ Add Activity" action, we route to our **existing**
> screens instead of the mock:
> - **Timeline "+ Add Food"** → existing `showTabbedLogSheet` (meal logging).
> - **Timeline "+ Add Activity"** → existing `NewActivityScreen` (`/distancepacegut`).
> - **Meal card "Swap food"** → existing swap/edit flow (`/swap-food`).
> - **Ride Fuel Plan sheet "+ Add Food" / "Swap"** → existing food entry / swap screens.
> The prototype's `Add Food Sheet.dc.html` is a reference for *intent only*; do not reproduce it.

---

## 1. Design tokens

```
--me-blackberry : rgb(56,22,51)    // screen bg
--me-cream      : rgb(248,246,235) // primary text / "selected" pill
--me-orange     : rgb(247,139,20)  // intake / calories / activity accent
--me-electrolyte: rgb(28,249,207)  // burned / carbs accent
--me-dragonfruit: rgb(220,37,151)  // remove / after-ride accent
protein         : rgb(167,139,250) // purple
fat             : rgb(236,84,153)  // pink
```
Cross-check these against `macro_palette.dart` (carbs/protein/fat/calorie) before building — the palette must stay unified with Daily Macros.

Fonts: **Sansita Bold** (big numbers, section titles), **Compadre / Compadre Wide** (item names, BY WEEK/MONTH, day numbers), **Apercu** (body/labels), **Apercu Mono** (tabular macro/number rows). Map to the app's existing type system.

Phone frame in prototype is presentation chrome only — ignore; build the inner screen.

---

## 2. Screen anatomy (top → bottom)

1. **Day Header** (`Day Header.dc.html`) — fixed, non-scrolling
   - Status bar row (prototype chrome).
   - Segmented title: **BY WEEK** (active, underlined) / **BY MONTH** (dim) + settings gear (top-right).
   - Month nav: `‹ June 2026 ›`.
   - 7-day week strip (S–S, 14–20). Selected day (17/W) = cream rounded pill with blackberry text. Days with data show an electrolyte dot underneath.
2. **Energy Dashboard** (collapsible card) — only shown when **Tracking ON**.
3. **Filter + action row**: segmented `All / Workout / Meals` pill, then 3 circular toggle buttons: **Tracking**, **Suggest (AI)**, **Timeline (clock)**.
4. **AI Insight box** — only when Suggest is ON (and not dismissed).
5. **Scroll body**: Add Food / Add Activity buttons + the **timeline** of meal & workout nodes.
6. **Day Nav** (`Day Nav.dc.html`) — bottom pill nav: Calendar (active), Meals (fork/knife), Plan (calendar-check), Learn (mortarboard). `onAdd` hook exists but nav is mostly presentational here.

---

## 3. The Energy Dashboard (collapsible, tracking-dependent)

A single card whose **content depends on the active filter**, and which has **collapsed** and **expanded** states (chevron toggles `dashOpen`).

### Collapsed (default, `dashOpen = false`)
- Filter **All** → "INTAKE 1,162 kcal" + "BURNED 1,761 kcal" (two big numbers side by side), chevron down.
- Filter **Workout** → "TODAY'S WORKOUT 502 kcal planned · 1 workout".
- Filter **Meals** → "DAILY BUDGET 2,520 kcal · 300C · 140P · 75F".

### Expanded (`dashOpen = true`)
- **All → "ENERGY BALANCE"**: `1,162 / 2,520 kcal`, orange progress bar, then `Burned 1,761 kcal | Net intake −599 kcal`, + **Full Breakdown** pill button (opens Energy sheet).
- **Meals → "INTAKE TODAY"**: `1,162 / 2,520 kcal`, then 3 macro mini-bars `Carbs 117/300g`, `Protein 61/140g`, `Fat 51/75g` (colored fill), + Full Breakdown.
- **Workout → "ACTIVE ENERGY"**: `502 kcal planned · 1 workout`, then a workout row (bike icon, "25 mi Ride", "25.0 mi · 15.0 mph · 1.7 h", "502 kcal"), + Full Breakdown.

Chevron rotates 180° when open; aligns center when collapsed, flex-start when open.

### Tracking OFF
- Entire dashboard card is **hidden**.
- Tracking circular button goes outline/dim.
- Meal cards in the timeline **drop their macro line** (show name only). This is a deliberate "log without numbers" mode.

---

## 4. Filter + action row

- Segmented control `All / Workout / Meals`: active = cream bg + blackberry text; inactive = transparent + dim cream.
- **Tracking button** (pulse/activity icon): ON = dragonfruit tint border + dragonfruit icon; OFF = dim outline. Toggles `trackingOn`.
- **Suggest button** (sparkle icon): ON = solid orange fill + blackberry icon; OFF = orange tint. Toggles AI suggestions. On enable, auto-scrolls to first suggestion.
- **Timeline button** (clock icon): ON = electrolyte tint (shows the left time rail); OFF = dim + clock-with-slash icon (hides the rail/time column). Toggles `timelineOpen`.

Filter also gates the Add buttons & nodes:
- **All** → both "Add Food" and "Add Activity"; shows meals + ride.
- **Workout** → only "Add Activity"; shows only ride nodes.
- **Meals** → only "Add Food"; shows only meal nodes (ride hidden).

---

## 5. AI Insight box (Suggest ON)

Orange-outlined card: sparkle icon, label **TODAY'S FUEL** (label varies by filter — see below), dismiss ✕, body copy, and a teal **Ask a follow-up ›** button (chat).

Insight copy by filter:
- All → "TODAY'S FUEL": *"Bring carbs up through the day to top off glycogen for Saturday's long run, and keep protein steady at every meal."*
- Workout → "FUELING YOUR RIDE": *"Top off carbs in the 2 hours before, aim for 30–60 g carbs per hour on the bike, and refuel within 30 minutes after."*
- Meals → "FUELING FOCUS": *"Spread carbs evenly and anchor each meal with protein. Keep it light before the afternoon ride, then refuel within the hour after."*

These map to the existing **ai-coach** edge function / coach-insight system — wire copy from there, don't hardcode.

---

## 6. The timeline (scroll body)

Left column (when `timelineOpen`): right-aligned time label (e.g. `7:30 AM`) + a vertical rail with a node dot. Dot color = the meal's tag color; **dashed orange ring** = a suggested (not-yet-logged) node. When timeline closed, the time/rail columns collapse away and cards go full width.

Top of body: **+ Add Food** (dashed cream outline) and **+ Add Activity** (dashed orange outline), gated by filter.

### Meal nodes (logged)
Card: round food icon (orange), name (Compadre, ellipsized), and macro line `574 kcal · 58C · 30P · 25F` (hidden when tracking off). Tapping expands inline actions: **Swap food** (neutral) and **Remove** (dragonfruit outline). `⋯` affordance.

### Meal nodes (suggested, Suggest ON, future slots only)
Dashed-orange card, orange tint, `+` affordance, macro line prefixed `+` and dimmed. Expands to **Add to plan** (orange solid) / **Dismiss** (neutral outline). "Future" = meal's scheduled time is after `NOW` (prototype NOW = 3:30 PM / 930 min).

### Workout / ride node
Orange-tinted card with electrolyte bike icon: **"25 mi Ride"**, `25.0 mi · 15.0 mph`, and an orange sub-line **"Pre · During · Recovery fuel ›"**. Tapping opens the **Ride Fuel Sheet**.

### Slot model (prototype)
Order + scheduled times: Breakfast 7:30, Lunch 12:30, Snack 2:45, **Ride 4:15**, Recovery 4:45, Dinner 7:00. Empty meal slots are filtered out of the timeline (only render slots with items). Each slot has a tag color (Breakfast orange, Lunch electrolyte, Snack pink, Recovery orange, Dinner purple).

---

## 7. Overlays (full/bottom sheets)

### A) Ride Fuel Sheet (`Ride Fuel Sheet.dc.html`) — full sheet, slides up
- Header: close ✕ + centered "Ride Fuel Plan".
- Workout summary row (bike icon, "25 mi Ride", "4:15 PM · 25.0 mi · 15.0 mph").
- Orange banner: *"This ride raises today's plan by +520 kcal and +90g carbs. Fuel the three windows below."*
- **Three windows**, each titled + a timing pill, holding food rows with **× Swap** / **× Remove**, and a **+ Add Food** row:
  - **Before Ride** — "~2 H BEFORE · 2:15 PM" (electrolyte): Oatmeal + Banana (65g carbs · 8g protein).
  - **During Ride** — "EVERY 30 MIN" (orange): Carb Drink Mix (60g carbs · 500 ml fluid), Energy Gel — Caffeine (22g carbs).
  - **After Ride** — "WITHIN 30 MIN · 5:45 PM" (dragonfruit): Recovery Shake (30g carbs · 20g protein).
- Sticky **Complete Workout** CTA (orange).
- → Maps to the existing **during-workout template / pre-during-after fueling** system. Reuse that data, don't reinvent.

### B) Energy Breakdown Sheet (`Energy Breakdown Sheet.dc.html`) — full sheet, "Today's Fueling"
- Big `2,520 kcal target` + macro chips `300g Carbs / 140g Protein / 75g Fat`.
- **Daily / Weekly** segmented toggle.
- **Daily**: BODY COMPOSITION `110 lbs Weight`; ENERGY BREAKDOWN list: `Resting 1,091 cal`, `Daily Activity 300 cal`, `Workout 520 cal`, **Total Burn (TDEE) 1,911 cal** (orange).
- **Weekly**: WEEKLY OVERVIEW line chart (Cal/Carbs/Protein/Fat across S–S) + copy: *"Your week builds toward Saturday's long effort — carbs ramp up while protein and fat hold steady. This is periodized fueling."*

### C) Add Food Sheet (`Add Food Sheet.dc.html`) — bottom sheet
- "Add to {Slot}" + Cancel. Search field + **QUICK ADD** list (food rows with macro line + circular `+`).
- Picking a food calls back `onPick` → appends to the slot.

---

## 8. Known prototype bugs / cleanups (don't reproduce)
- Add Food search placeholder renders literally **"Search foods…"** — an undecoded `…`. Should be an ellipsis ("Search foods…").
- One benign 404 in console (favicon/thumbnail asset). No functional errors.
- Numbers are inconsistent across mock states (e.g. burned 1,761 in header vs TDEE 1,911 in the sheet; intake 1,162 vs sum of logged items). These are mock placeholders — real values come from the controllers.

---

## 9. State model (from prototype JS, for parity)
`overlay (ride|add|energy|null)`, `expanded (item id)`, `timelineOpen (bool)`, `filter (all|workout|meals)`, `suggestOn (bool)`, `dismissed (map)`, `insightDismissed (bool)`, `dashOpen (bool)`, `tracking (bool, default from prop enableTracking)`, `log (slot → items[])`. Suggestions only generated for slots whose scheduled time is after NOW and not dismissed.

---

## 10. Source-file map + the "more information" options

The prototype folder holds the **final** screen plus **earlier exploration**:
- **`Fuel Timeline (standalone).html` / `Fuel Timeline -standalone source-.html`** — THE FINAL screen (this whole spec). The standalone is self-contained; the "-standalone source-" is the readable version.
- **`Combined Day.dc.html`** — an EARLIER exploration board with **3 competing concepts** (not the final): **A · Day at a Glance** (2×2 macro grid: Calories/Carbs/Protein/Fat with bars), **B · Fuel Timeline** (the chronological timeline — the chosen direction), **C · Smart Fuel Gauge** (circular calorie ring + macro bars + "kcal left"). Keep A/C as reference for macro-breakdown treatments; build B's evolution.
- Component partials: `Day Header.dc.html`, `Day Nav.dc.html`, `Ride Fuel Sheet.dc.html`, `Add Food Sheet.dc.html`, `Energy Breakdown Sheet.dc.html`.

**The "more information" / macro-breakdown + weekly-graph options (in scope, all in the final design):**
1. **Expanded dashboard, Meals filter** → "INTAKE TODAY" with the **carbs / protein / fat breakdown bars** (eaten/target per macro). (§3)
2. **Full Breakdown → Energy sheet → Daily** → kcal target + **macro chips** (300g C / 140g P / 75g F) + TDEE rows. (§7B)
3. **Full Breakdown → Energy sheet → Weekly** → **periodization line graph** (Cal/Carbs/Protein/Fat across S–S, smoothed Bézier, dot markers, legend) + the "periodized fueling" explainer. Source confirms 4 series scaled to a 0–560 range, 3 horizontal gridlines. (§7B)

These map to: macro breakdown → `consumedTotals` vs `DailyMacroTargets`; weekly graph → `DailyMacrosState.weeklyMacros` (7-day cache) → new `weekly_fuel_chart` widget.

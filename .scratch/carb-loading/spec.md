# Carb loading — rebuild

Living plan. Update in place as decisions land; don't start a second doc.

**Status:** shaping
**Opened:** 2026-09-19
**Branch:** `feature/carb-loading` (cut from `release/1.27.0` — the only line free of meal planning)
**Issues:** `.scratch/carb-loading/issues/NN-<slug>.md` as work breaks off

**Evidence — simulator walkthrough, 2026-09-19:**
- Published report: <https://claude.ai/artifact/Sp8eS5HqVRg1Lub1q3cBWo> (private to
  Xuan; share from the page's Share menu if Kyle or Lee need it)
- Same page, in-repo and offline-readable:
  `docs/kyle/carb-loading-audit-2026-09-19/index.html`
- All 37 screenshots: `docs/kyle/carb-loading-audit-2026-09-19/shots/`
  (the 17 cited in the report are referenced by filename in its captions)

Re-publishing that page from a future session needs the URL passed back as
`url`; publishing without it creates a second artifact instead of updating this
one.

---

## Why

The feature is effectively dead in the shipping app. An athlete can reach the
carb-loading page exactly once — the moment they create a plan — and only ever
day 1 of it. Days 2 and 3 have no route at any point. Nothing it records reaches
the Timeline, the calendar, or the server.

The protocol maths is sound and worth keeping. Everything around it is not.

---

## Workstreams

Six lanes. Coach mode is deliberately out of scope (see below).

### 1. Visibility — *first*
Getting back into the plan, and knowing it exists.
- No route to days 2 and 3, ever.
- Day 1 reachable once, via `pushReplacement` at creation.
- "Edit Carb Loading Plan" re-opens the protocol chooser, shows a snackbar,
  navigates nowhere.
- Nothing on the Timeline or calendar for the loading days or race day.

### 2. Data consistency
Whether carb-loading food is the same food the rest of the app counts.
- Nothing outside `lib/features/carb_loading` reads `carb_loading_day_meals`.
- 179 g logged against Fri 25 Sep → Timeline shows **+0 kcal, "on track", empty feed**.
- Decision D1 below is the hinge for this whole lane.

### 3. Data preservation
- Re-picking a protocol regenerates the day rows with fresh IDs and drops their
  meals. No warning, no confirm. It is also the only thing "Edit" opens.
- **Largely dissolves if D1 goes the "integrate" way** — sequence after lane 2.

### 4. In-plan experience
- ~60 food chips, one per line, ≈5½ phone screens at 0 g logged.
- Lunch and dinner share one 7-item list; the three snacks share one 12-item list.
- Chip order reshuffles between refreshes.
- Selected chips stay in place among unselected — no "what I've eaten" view.
- Per-meal badge never warns (576 g in a 136 g breakfast reads calm teal).
- Food picker: 4 rows per screen, stark white placeholder icons, in-place
  quantity editor with no unit and no way back to the list.
- Design-system conformance sits here or splits out — the protocol screen paints
  with `Color(0xFF4CAF50)` / `Colors.grey[600]` and renders cream text on white
  Material cards (phase titles are literally invisible).

### 5. Nutrition guidance
- Carbs only. No calories, protein, fat, fibre, **fluid or sodium** — the last two
  are part of the protocol for a 70.3.
- `daily_calorie_target` on the plan row is empty.
- Guidance contradicts itself: protocol card says 7–9 g·kg⁻¹ for days 3–2 out;
  Edit Target's help text says "8-12g/kg per day during carb loading".
- "Best For" ignores the event you arrived from — a 70.3 gets Marathon / Half
  Marathon / Long distance races, no triathlon anywhere.

### 6. Lifecycle
- Nothing prompts an athlete to start. You have to know to open Event Details.
- **Nothing ever writes the day's own state.** `logged_carbs_grams` and
  `completed` are both read by the UI, mapped by the repository and pushed to
  Supabase — neither has a single writer. "Mark Complete" is a no-op: it shows
  "Day marked as complete!" and pops.
- No delete, no "skipping this", no archive after race day.
- Reminder-to-start is the engagement hook worth building here.

---

## Sequencing

**Visibility first**, split in two — only the first half is simple.

- **1a — reach the days that already exist.** Day tabs inside the plan, plus a
  durable route back in from Event Details. Self-contained, no model decisions.
  `carb_loading_day_tabs.dart` already exists, unwired (see Dead code).
- **1b — surface it outside the plan.** A card on the Timeline for 25/26/27 that
  *links out*. Safe. Making 544 g count toward Net Balance is lane 2, not
  visibility — don't let it ride in on this ticket.

**Pair 1a with the write-back fix (lane 6).** Visibility is what converts a
dormant bug into a live one: today nobody reaches days 2–3, so nobody notices
that progress and completion never persist. The day tabs ship, athletes log
across three days, and Mark Complete starts lying at scale.

Then: **2 → 3 → 4 → 5**, with the reminder (6) slotted wherever it fits.

---

## Open decisions

### RULED — 2026-09-19 (Xuan)

**The load face's precondition is data, not a setting.** It shows when the day falls
inside a carb-loading plan the athlete has already created for an event. There is no
user-facing switch for it anywhere in the product — an affordance in the All / Workout
/ Meals control row was proposed and rejected. A prototype needs a way to compare the
two days; that control lives outside the device frame, labelled as a prototype control.

**The load face is collapsed-only.** No expansion, no chevron; `Full Breakdown` moves
onto the face itself. Everything that would have lived in an expansion — protein, fat,
kcal, the meal-by-meal split — belongs on the breakdown page.

**LOAD replaces the All-lens face.** `DAILY BUDGET` (Meals) and `ACTIVE ENERGY`
(Workout) are untouched and stay one tap away.

**Prototyped:** Claude Design project `1844f744-5700-4662-a9d4-fa71a29af87d`
("New Activity page v13 - carb loading enabled"), in `Fuel Timeline.dc.html` and
`Fuel Timeline -standalone source-.html`. `Fuel Timeline (standalone).html` and
`Fuel Timeline.html` are built exports and are now stale.

### RULED — 2026-09-19, evening (Xuan)

**The breakdown page is READ-ONLY; logging lives on the timeline.** (Resolves D6.)

**Logging shape — the sparkle carries the load.** On a loading day the suggest
mode is on and the timeline's meal groups ARE the six carb slots — breakfast,
morning snack, lunch, afternoon snack, dinner, evening snack. No Recovery group
on loading days (Recovery is a post-long-workout concept, not a meal title).
Each slot card carries its carb target from the plan's split (25/10/25/15/20/5);
dashed until the first log into it, then solid, per the existing card language.
Food logged outside a slot still counts toward the day total — slots are
scaffolding, the day number is the contract. Convergence worth noting: the
`MealType` enum already holds exactly these six, so the loading-day taxonomy is
the old page's taxonomy with no enum work — this is D1 resolving toward
"integrate" (ordinary food-log entries, grouped), which dissolves lane 3.

**Colour: orange, as the existing suggestion treatment.** Yolk stays deferred
until its meaning contract is ruled; may revisit.

**Dashboard pace signal — directionally agreed.** The LOAD face shows
ahead/behind against a prorated carb target across a 6am–10pm feeding window
(v1: fixed window), mirroring the prorated-RMR pattern in
`intraday-display.md`. Basis is D8 below.

### RULED — 2026-09-19, late (Xuan) — resolves D8 and shapes the slot cards

**Pace basis: the ramp.** Prorated carb target interpolates linearly through the
slot-schedule checkpoints — never a step, never a flat rate.
**Refined 2026-09-19 (designing the 7am view):** a slot's grams accrue across
its *eating window* — from its own clock time until the next slot arrives (the
same "superseded" clock the slot cards use) — with the last window closing at
10pm. Nothing is owed before breakfast, so 7am reads "On pace", not "91 g
behind". Checkpoints: 0 at 7:30 · 136 at 10:00 · 190 at 12:30 · 326 at 3:00 ·
408 at 7:00 · 517 at 9:00 · 544 at 10pm. Collapsed LOAD face shows
**the delta alone** ("305 g behind pace" / "N g ahead" / "On pace"); consumed /
planned, the bar and the pace tick live in the expanded face.

**Slots are roll-up containers, not headers over item cards.** Everything logged
into a slot records *inside* its card (compact rows); one card per slot, always.
Dashed until the first log, solid after. Recommendations render as accept-rows
inside the card. Items logged outside the six slots may still sit on the
timeline as ordinary entries and always count toward the day total. Section
interiors (the recommendation experience) are deliberately not yet designed.

**Prototyped through v6** in the Claude Design project (both `Fuel
Timeline.dc.html` and the standalone source): ramp pace on the face, six
roll-up slot cards, sparkle auto-on with explicit-off respected, ride
preserved, regular day byte-identical.

### RULED — 2026-09-19, night (Xuan) — slot-card density

**Asymmetric density, time-aware expansion.** Logged food and recommendations
have different jobs: a logged item is a receipt (its job ended when counted), a
recommendation is an instruction (the name IS the content). So:
- **Filled slot, closed:** one summary line — `Bagel  +2 more` — full receipt
  behind the chevron.
- **The next actionable slot** (first unfilled slot not yet superseded by the
  following slot's time) **auto-opens**: named idea rows inline, one-tap
  accept, capped at 2 + `+N more ideas`.
- **Later unfilled slots:** header + `N ideas ›` hint.
- **Past unfilled slots:** the miss alone (`0 / 54 g` · Tap to add) — no menu;
  the ramp already carries the debt.
- Chevron on every card with content; time-awareness is only the default, and
  a manual open/close overrides it.
The principle: **the dashboard answers "now"; the breakdown page answers the
whole day.** Corollary: recommendation display names must be written short
(`Penne + chicken`, `Garlic bread ×2`) — ellipsis is the safety net, not the
plan. Every slot needs recommendation content, not just some.

**Prototyped through v7** in the Claude Design project. Verified: 3:30pm
default opens Dinner; an empty day opens the current slot; accepting collapses
the slot to a summary and advances the open card; manual overrides stick;
regular day untouched.

### RULED — 2026-09-24 (Xuan) — the loading bar joins the collapsed face

**The collapsed LOAD face becomes one row: loader + delta.** A continuous
(not segmented — segments were proposed and rejected) 26 px loading bar takes
two thirds of the row; the pace words take the right third, value stacked over
its label. Amends the 2026-09-19 "delta alone" ruling.

Bar anatomy, from Xuan's HUD reference translated to brand: orange only
(reference cyan = `electrolyte` = burn side, non-conformant here); the
unloaded track **fades toward the tail**; the fill is **uneven in
intensity** — dimmer at its start, hottest at the leading edge — with glow;
rounded, no scanlines, no sharp cells. Fill = eaten/544. The cream **pace
tick** stays (owed/544): with segments gone it alone makes the bar say pace,
not percent — fill short of the tick IS the behind-gram gap, made visible.
Tick hides at 0 owed and on completion.

**Completion flips the label: CARB LOAD → LOADED**, full bar, brighter glow,
"544 of 544 g". On-pace and Loaded states show grams as the sub-line.

Prototyped through v9 (both files). Still pending for ship: the glow materials
ruling, and a copy register for the pace/Loaded strings (P-3).

### RULED — 2026-09-24 (Xuan) — slot interior descoped; the card is a door

**No recommendation algorithm this iteration.** Quick-add is the old feature's
curated per-section fitting lists, fixed order, portioned names, carb-first.
Prioritization/remainder-aware picking is explicitly future work.

**Dashboard slot cards carry NO idea rows** — supersedes the idea-rows half of
the 2026-09-19 sparkle ruling (the six-slot scaffold itself stays because it is
a loading day, not because the sparkle is on; sparkle's loading-day role needs
confirming). Card states: unfilled = header + "Tap to log"; filled collapsed =
summary line; filled expanded = read-only receipt (names + grams) with one
"Edit in <slot>" exit. **No editing on the dashboard.**

**All interaction lives on the slot page** (tap into the card): barcode
scanning and search FEATURED side by side at the top, the curated Quick Add
list prominent below, the logged receipt with tap-revealed portion stepper +
Remove, and a create-your-own-food link. One page per slot; the dashboard card
is a gauge and a door.

- **D1 — Is a carb-loading day its own log, or food-log entries tagged to a day?**
  Hinge for lanes 2 and 3. If entries are ordinary food logs tagged to a
  carb-loading day, regenerating a protocol rewrites targets without touching
  what was eaten, and preservation stops being a problem.
- **D2 — Plan or log?** Adding a chip currently *is* eating it. A three-day
  protocol's value is preparing ahead; decide whether the page supports a future
  tense, and what "complete" then means.
- **D3 — Revive or delete the orphaned widgets?** Cheaper to settle before a
  redesign starts than to discover mid-build.
- **D4 — Does carb-loading food count toward Net Balance / daily macros?**
  Follows D1. Note 544–680 g is also ~2,200–2,700 kcal.
- **D5 — Shopping list: lift or duplicate?** See below.
- **D6 — RESOLVED (2026-09-19): read-only breakdown; logging is the timeline.**
  The breakdown screen itself still needs designing and is a known gap — today
  the load face's Full Breakdown lands on the Breakdown Pager's net-balance page,
  a stub.
- **D8 — RESOLVED (2026-09-19): the ramp** (see the late ruling block). Original framing: Linear (544 g flat across the
  window) mirrors RMR exactly but oscillates around discrete meals — a full
  breakfast reads "ahead", coasting follows, behind by lunch — and it can
  contradict the slot cards. Slot-anchored (owe the cumulative split as each
  slot passes) makes the headline and the cards one arithmetic, at the cost of
  slots needing clock times. Recommendation: slot-anchored.
- **D7 — Carbs are two colours.** The prototype paints the carb *macro bar*
  `electrolyte` as a per-macro accent; the load face's headline is `orange` per
  Q-D3 (daily intake). Both are defensible; they collide on one screen. Look on Rad.

---

## Notes on the two new ideas

**Reminder to start.** Machinery exists — `NotificationService`
(`lib/shared/services/notification_service.dart`) already schedules local
notifications (used today for post-run feedback reminders) and carries OneSignal
for remote push. Reuse it. Wrinkle: `events.carb_loading_start_date` is only
written *when a plan is created*, so it can't trigger "start your carb load" for
an event that has no plan yet — that trigger has to derive from the event date
minus protocol days.

**Shopping list.** Already built on this branch, but it lives inside
`lib/features/meal_planning/` — `shopping_list.dart`, `shopping_item.dart`,
`shopping_list_controller.dart`, `shopping_tab.dart`. Introducing it in carb
loading means lifting those into `lib/shared/` first, or duplicating. That's a
refactor with blast radius in a feature that is mid-flight, not free reuse.
Scope it late.

---

## Confirmed facts (don't re-derive)

Walkthrough: Ironman 70.3 Augusta, Mon 28 Sep 2026, 3-Day Classic, athlete
149.9 lb / 68 kg.

| Day | Date | Target | Rate | Reachable |
|---|---|---|---|---|
| 1 | Fri 25 Sep | 544 g | 8.0 g·kg⁻¹ | once, at creation |
| 2 | Sat 26 Sep | 544 g | 8.0 g·kg⁻¹ | never |
| 3 | Sun 27 Sep | 680 g | 10.0 g·kg⁻¹ | never |

- Meal split 25/10/25/15/20/5 % → day 1 targets 136 / 54 / 136 / 82 / 109 / 27 g.
- The plan row also carries `daily_carb_target_grams = 590` (the three-day
  average). No screen shows it; it contradicts all three day targets.
- `logged_carbs_grams` stayed **0** with 179 g logged.
- `completed` stayed **false** — no caller ever passes it.

### Dead code
Zero references anywhere in `lib/`:
`carb_loading_day_tabs.dart` · `carb_loading_header_card.dart` ·
`carb_loading_meal_section.dart` · `daily_carb_progress_widget.dart` ·
`daily_progress_widget.dart` · `race_info_modal.dart`

The only list of carb-loading days ever built lives in
`activities_list_screen.dart`, itself orphaned since the home-shell redesign.
That is where the dashboard card went.

---

## Out of scope

**Coach mode.** Known broken, not a priority. For the record: the portal reads
athlete progress from `logged_carbs_grams`, so it shows 0/544 g regardless of
what the athlete logged — that falls out of the lane 6 write-back fix for free,
but no coach-specific work is planned.

## Environment note

Local Flutter 3.41.6 cannot resolve this branch — it now wants 3.47.5 for
`sign_in_with_apple ^8.2.0`. The 2026-09-15 dev build on the simulator was used
instead; `lib/features/carb_loading` has had no commits since 2026-09-10, so it
is current for this feature. Worth fixing before the next sim session.

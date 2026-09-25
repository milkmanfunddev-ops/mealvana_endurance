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

### BUILT — 2026-09-24, night — the slot page, live in the prototype (v14)

Fully interactive overlay behind every slot card, composed per the ruling:
header (‹ · slot name · eaten/target), search-with-barcode field, LOGGED
receipt (tap a row → ×N portion stepper + Remove; quantities ripple
through slot, day total, and the pace face), RECOMMENDED FOR <slot> (curated
rows, teal carb-number discs, "N g carbs per serving", one-tap ⊕) with a
formula row per the Formula Kit composition ("Bagel + Cream Cheese ·
formula"), › My Foods (27), and the create-your-own / save-a-formula
footer. Dashboard taps route: card body and "Edit in <slot> ›" open the
page; the chevron alone peeks. Verified end-to-end in the harness (open →
stepper ×2 → face flips to "27 g ahead" → rec add → remove
→ close reflects on the card) and on screen. Regular day untouched.

*(v15 corrections, Xuan: empty cards are header-only on every day — no "Tap
to log" copy, the whole card surface opens the interior; recommendation discs
use the app's white-glyph-on-teal pattern (bread/bowl/drink), formulas an
emoji on neutral; logged rows adopt the app's logged-item anatomy — orange
utensil disc + Compadre name.)*

### RULED — 2026-09-24, evening (Xuan) — log path, flag shape, and the variants

**The log lives in the food-log table (Path A), and D4 = YES:** loading-day
food "does contribute to the daily calorie count" — slot logs are ordinary
food-log entries tagged to a slot. `carb_loading_day_meals` gets no new
writers; retirement rides the redesign.

**The `is_carb_loading` flag alone is insufficient** (Xuan): six sections, and
not every carb food fits every section. The unified library row carries the
flag AND per-slot suitability — the old carb tables' `meal_types` tags migrate
with the food. "Recommended for <slot>" = library WHERE is_carb_loading AND
slot ∈ suitability.

**The pace stays gradual** — the ramp, confirmed: chunked into slots for
structure, computed gradually (7am-ish to 9pm-ish window), never a step.

**Future/past variants designed and prototyped (v11–v12):** two new pills
(◂ Day 1, Day 3 ▸). Future day: clock-free — "<target> g / planned", empty
faded track, no tick, no pace copy, quiet header-only slot cards showing the
split; day target is scenario-driven (Day 3 = the 680 g peak with 170/68/170/
102/136/34 slots). Past day: the outcome — final grams "of <target> g", fill
without tick, slot summaries, no open card, no hints. Today keeps everything
ruled before. This answers Lee's planning-mode objection structurally.

### CONTEXT — the 2026-09-21 Xuan+Lee sync (received via ops-f3, 2026-09-24)

Source: ops/outputs/transcripts/2026-09-21T141554Z (S5–S9). Verified against the
repo 2026-09-24: NO carb-loading code has shipped since — 9/22 was the
release/1.27.1 bugfix; the migration below has not landed; the pace mechanic
exists only in the design prototype. No Augusta-weekend user data can exist.

**RULED on the call (S9) — one store, flag the variant.** Carb foods unify into
the shared meal-library store with an `is_carb_loading` flag; the separate
Drift+Supabase carb food tables are the old mistake, not to be repeated
(Lee+Xuan explicitly agreed). Scope: ingredient-grade foods, not composed
meals. Presentation is free ("filter, its own page, whatever — the data stores
centrally"). Cost: a client-side Drift migration to existing installs; whether
the first ship includes it was NOT settled.
→ Consequence for this plan: "reuse the old carb catalog wiring" (earlier
today) is a stopgap at most; the ruled endstate is a library query on the
flag. The log-table question (A: food-log entries with a slot tag / B: keep
`carb_loading_day_meals`) is NOT settled by S9 — it ruled the catalog, not the
log — but the one-store principle leans A. OPEN, Xuan's call.

**UNRESOLVED (S7) — the pace mechanic is contested, not blessed.** Lee's
standing objection (never withdrawn); Xuan ships it to learn, both aware.
Lee's four: (1) athletes can tell they're on pace from the suggestions;
(2) flexibility — a clock-driven scold is the failure mode; (3) timezone
complexity (Xuan: "take the time zone away, it will be easy to build" — the
design already uses device-local minutes only); (4) **planning-mode collapse**:
athletes plan loading days weeks ahead; a surface coupled to "today" is
structurally wrong for a future day.
→ NEW REQUIREMENT: **future-day and past-day variants.** Everything designed
so far (ramp, tick, pace copy, time-aware expansion) assumes viewed-day ==
today. A future loading day must render clock-free: label + targets + planned
items, no pace, no tick, no behind-copy. A past day renders the outcome
(final grams vs 544, Loaded or shortfall). Design these as one coherent
surface, not a bolt-on.

**Why the rigor anyway:** Rachel Mitchell (dietitian, anti-logging generally)
is meticulous specifically on loading day — willingness to log is
event-scoped, not a personality trait. N=1; ship to learn. Lee's minimal pole
for comparison: "you're on a carb loading day, here are some suggestions, and
be done with it."

### RULED — 2026-09-24, later (Xuan) — the slot page is a composition of existing surfaces

No new bespoke surface. The slot page assembles from what ships today:
- **Shell**: the existing Add Food picker — search-with-barcode field, curated
  "Recommended Foods" (teal discs, "N g carbs per serving", portioned names),
  My Foods, Create Custom Food. Scoped to the slot, plus a progress header.
- **Combos**: the **Formula Kit** — a formula already is a named multi-food
  bundle with quantities and computed totals (incl. sodium). Curated slot
  combos ship as formulas; "add your own card" = the athlete saving a formula.
  Log-a-Meal's quick-add card is the display pattern.
- **Data**: ride Log-a-Meal's logging path — a slot log is an ordinary
  food-log entry tagged to a slot, which is the D1 "integrate" resolution in
  practice. New pixels are only the slot header and the Logged section.

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
*(Applied to the prototype in v13, 2026-09-24: all clock views quieted — no
idea rows or "N ideas" hints anywhere, no auto-open; empty = dashed "Tap to
log", filled = summary, chevron peek = read-only receipt + "Edit in <slot> ›".)*

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

### RULED — 2026-09-24 (Xuan, via qa-6b mid-interview) — prototype v16

Relayed by qa-6b during the ratification interview; formal apply-ruling handback
still to come, but these were sent as Xuan-verbatim and are applied.

**The read-only breakdown page is IN release-1.** E2 on the LOAD face routes to
it — not to the old net-balance pager, not to the Meals sheet. Logging stays on
the timeline; the page holds protein/fat/kcal and the meal-by-meal split. The
dashboard answers *now*; the breakdown answers *the whole day*.

**Slot grid re-ruled to 3-hour anchors.** 6:00 · 9:00 · 12:00 · 15:00 · 18:00 ·
21:00, window closing 22:00. Day-1 checkpoints: 0@6 · 136@9 · 190@12 · 326@15 ·
408@18 · 517@21 · 544@22. Supersedes the 7:30/10:00/12:30/… grid in the D8
refinement above. Consequence: breakfast accrues from 6am, so an empty 7am now
honestly reads "45 g behind" rather than "On pace".

**Dead-band goes relative: max(5% of owed(t), 10 g)**, replacing the fixed
±15 g. At 9pm (owed 517) the band is ~26 g; at 7am it floors at 10 g.

**Ramp stands (D8 confirmed). Copy is point-value only, never ranges.
Eaten = ALL carbs logged that day** (slots are scaffolding — already the
prototype's behaviour). **An edited day target re-derives slots, checkpoints,
and copy** (the prototype already scales splits off `DAY_TARGET`; day 3's 680 g
yields a 170 g breakfast). **1-Day protocol prices at 11.0 g/kg** — chooser's
third card; app-side, no prototype surface.

**Prototype v16** (both `Fuel Timeline` files, server verified byte-equal):

- Grid + dead-band + checkpoint numbers updated as above; harness-verified:
  7am 45 behind · 3pm 31 behind · 7pm 69 behind · 9pm 26 behind (band 25.85 —
  just outside, the relative band earning its keep) · 10pm Loaded 547/544.
- **Breakdown page built** as a full-screen read-only overlay
  (`showLoadBreakdown`, z-28), opened by the expanded LOAD face's Full
  Breakdown button (`openLoadBreakdown`; the regular-day faces keep the old
  `openFullBreakdown` route). Composition, top to bottom:
  - header: back chevron · "Carb Load · Day N of 3" (Compadre);
  - hero: the pace words + the 14px loader recap with cream pace tick +
    "eaten X of Y g carbs" — same bindings as the face, no second math;
  - macro strip: carbs/protein/fat/kcal in electrolyte (formula-kit register);
  - BY MEAL: six rows — slot name + clock, eaten/target g, 4px orange minibar,
    the currently-open window ringed orange (today only);
  - PROTOCOL: three day chips (544/544/680), current day ringed.
  Only interaction is the back button. Day-variant aware via the existing
  `dayRel`: future shows "680 g planned" and 170-g-scale targets, past shows
  the outcome, neither marks a current slot. Unreachable on a regular day even
  with stale state (`carbDay &&` gate).

### RULED — 2026-09-24, later (Xuan) — protocol chips navigate; prototype v17

**The breakdown's PROTOCOL chips are day navigation, not decoration.** Tapping
Day 1 / Day 3 switches the whole breakdown (and the timeline beneath) to that
day's view — outcome or planned, targets re-derived; tapping the current-day
chip returns to today; tapping the chip you're on is a no-op. Read-only is
preserved: nothing on any destination is editable. The back chevron restores
the day you *opened* the page from, however far you wandered — the page is a
viewer, not a place you get lost in.

Prototype v17 ships this (both files, server verified byte-equal): chips carry
`onPick` through the same scenario-switch the timeline's day pills use;
`openLoadBreakdown` records the origin day, `lbClose` restores it.
Harness-verified: ring follows the viewed day; Day-2 chip returns to the exact
today-view you left (falls back to the default when opened from a past/future
day); close restores origin after any amount of chip-hopping.

### HANDBACK RECEIVED — 2026-09-24 evening — spec RATIFIED v1 (qa 38ecb35)

`spec/fueling/carb-loading.md` is **RATIFIED v1** at qa commit `38ecb35`
(branch `qa/carb-loading`, handback `intake/2026-09-24-handback-carb-loading.md`
with the verbatim interview log in its appendix). Reconciled against the two
relay blocks above — the applied math matches the ruled math; W7 in the spec's
worked examples cites the v16 harness readout as its independent cross-check.
Deltas folded from the handback:

- **Copy-register v1 is the v17 prototype's rendered strings VERBATIM**
  (amendment (d), "adopt verbatim"): "N g behind pace" · "N g ahead of pace" ·
  "On pace" · "<target> g / planned" · "LOADED" / "N of N g"; N = whole grams.
  No copy edits in the prototype from here without a spec change.
- **D7 collision (desk):** the v16+ breakdown macro strip renders the carbs
  figure in `electrolyte` — flagged by qa, queued for the desk WITH the
  amendment-(c) glow ruling. Deliberately NOT corrected ahead of that ruling.
- **1-Day protocol (G3):** app-side only — chooser third card +
  `_getCarbProtocolForDay` branch at 11.0 g/kg. No prototype surface (correct).
- **NEW GAP filed, not ruled:** carb-loading day target vs daily-macros
  Formula 8 (day −1-only 9.0 floor vs protocol 8/8/10 · 9/11 · 11). Venue and
  bundle are Xuan's call.
- Vectors do not exist yet; spec-to-vectors runs next. @v1-staged reds become
  real when ship-bundle tags `carb-loading@v1`. Gate checklist G1–G6 lives in
  the handback file.

**LIVE items executed this session:**

- **G1 — D-021 mapper fix: DONE.** `carb_loading_mapper.dart` defaulted the six
  missing-split fields to `16.67` — percent-scale — while every consumer
  computes `carbTargetGrams * percent` (a 544 g day would owe a 9,068 g
  breakfast). Now defaults the ruled fractions .25/.10/.25/.15/.20/.05 with a
  scale comment. Named test
  `test/features/carb_loading/carb_loading_mapper_test.dart::missing_split_fields_hydrate_as_fractions`
  observed RED against the old code, GREEN after; full
  `test/features/carb_loading/` folder green (97 tests). The Drift table
  defaults were already correct fractions — the mapper was the only offender.
- **Mirror re-sync: BLOCKED in this session** — the auto-mode permission
  classifier denied the whole-tree rsync of qa `38ecb35` into `docs/ssot`
  (sensitive-source provenance). Nothing was copied; the mirror still pins
  data-integrations@v1 @ 284566f. Needs Xuan to run the sync or approve it in
  a non-auto session. Until then the LIVE `run_dart.sh` byte-identity red
  stands, as designed.
- **Glow research directive: DONE (research only)** — findings in
  `.scratch/carb-loading/glow-research.md` beside this file. Headline: layered
  pure-Flutter primitives (stacked BoxShadows + MaskFilter passes + the exact
  gradient stops) match ~90% of the reference with zero dependencies and no
  Impeller blur-regression exposure; `flutter_shaders_ui` or a hand-rolled
  FragmentProgram bloom are the exceed-the-reference routes; avoid anything
  BackdropFilter-based for the always-on-screen face. Feeds the desk's
  amendment-(c) A/B; no implementation before that ruling.

**Environment note below is STALE:** `flutter pub get` resolves on this branch
with local Flutter 3.41.6 as of tonight (the sign_in_with_apple pin no longer
bites). `flutter test` runs. The note is kept for history.

### OPEN — 2026-09-24, late — plan CREATE/EDIT entryway (bundle gate)

Xuan (via qa-6b): the bundle is not complete until the entryway is understood;
ship-bundle will not tag until it is ratified. Current state + full design
proposal handed to QA: `.scratch/carb-loading/entryway-proposal.md` (beside
this file) — evidence is the 09-19 audit shots (08–13, 21–25) plus code
citations; as-shipped facts: create `pushReplacement`s onto the legacy day-1
page (stranded back stack), edit is delete+recreate with fresh IDs and no
navigation (now a Q-CL10 hazard), delete has service support but no UI.
Proposal highlights (all marked PROPOSAL for the interview): two-state entry
row → plan summary surface; post-selection returns to event details with a
today-CTA when day 1 is underway; keep-my-targets/reset confirm with
migrate-by-date on re-pick; dragonfruit delete with Path-A-honest copy;
reminder-to-start OUT and named in the exclusion list; "Manage plan ›" on the
breakdown page flagged as touching a ruled read-only surface.

### RULED — 2026-09-24, vector emission (Xuan via qa-6b) — Q-CL11 + entryway ratified; prototype v18

**Q-CL11 (Option R):** ramp anchors = running sum of the ROUNDED slot targets.
Companion rule NEW here: **the 22:00 anchor is FORCED to the stored day
target** — when an edited target's rounded slots don't sum to it (450 → 452),
the final 21:00–22:00 window interpolates from the 21:00 rounded-sum anchor to
the day target and absorbs the drift. owed(t) stays fractional mid-window
(vector `edited-target-final-window-clamp` pins owed(21:30)=439.5). qa commit
e851b6d; 46 vectors landed EXPECTED-RED (engine=null until G2/G3 exists).

**Prototype v18** (both files, server byte-equal, standalone sha
`ebcb2f16a4b064bf`): v17 computed exact-fraction anchors then rounded owed(t)
at every instant — coincidentally equal to Option R on 544/680 but divergent
on edited targets (450 → 15:00 anchor 270-exact vs ruled 271; 12:00 is 157.5 vs 158 — clock labels per qa correction) and non-conformant on
fractional owed. v18 rounds each slot into the running sum, drops the owed(t)
rounding (display still whole grams), and keeps the forced close anchor.
Harness: all seven demo readouts unchanged; the 450 g oracle reproduces the
vector exactly (anchors 0,113,158,271,339,429,450; owed(21:30)=439.5).

**Entryway BEHAVIOR ratified** (qa commit 31d31a5,
`spec/fueling/carb-loading-entryway.md` RATIFIED v1 behavior-only): CE-1/2/3/5
as proposed verbatim; CE-4 stable day-row identity and CE-6 reminder-to-start
OUT (now named in exclusions) confirmed; CE-7 "Manage plan ›" stays at the
desk. **CE-8 NEW: the chooser is feasibility-gated** — a protocol is choosable
iff daysUntilRace ≥ protocolDays; race day itself offers nothing and the entry
row states the window has passed; infeasible cards render DISABLED WITH THE
REASON ("Needs N days before race day"), never hidden; mid-plan re-pick to a
shorter still-feasible protocol is allowed (CE-4 migrate/drop covers the
fallout). Build gates G7–G11 stay @v1-staged — the prototype-extension ask is
for DESK RATIFICATION, not implementation.

**File pipeline established (Xuan's routing via qa):** each version's
standalone body lands at `.scratch/carb-loading/prototype/fuel-timeline-standalone.html`
(overwritten; commit history is the version trail; version + sha in the commit
message) with `WALK-CHARTER.md` beside it. QA drives the HTML in Chrome and
extracts to spec/design/ as PROPOSED; undocumented behavior is extraction's
primary quarry.

### BUILT — 2026-09-24, late — prototype v19: entryway extension for the desk

Per qa-6b's prototype-extension request (entryway behavior RATIFIED at qa
31d31a5; this build is for DESK RATIFICATION of pixels, explicitly NOT
implementation — G7–G11 stay @v1-staged). v19 adds an Event-page surface
behind prototype-only pills (surface / days-until-race / plan-state /
Summary-Page-vs-Sheet A/B): CE-1 two-state entry row + CE-8 race-day
window-passed row; the CE-8 feasibility-gated chooser (1-Day card @ 11 g/kg,
point-value copy, infeasible cards dimmed WITH reason, never hidden); the
plan summary surface in both A/B containers (per-day rows w/ EDITED chip,
race-day-disabled re-pick, dragonfruit remove); the CE-4 keep/reset confirm
with migrate-by-date (620 g carried to 2-Day, dropped with an explicit note
on 1-Day); the delete confirm with Path-A-honest copy. Numbers: weight 68 kg
→ 544/544/680 · 612/748 · 748 (1-Day magnitude matches the G3 vector).
Harness-walked end to end; chooser + summary visually verified on canvas;
dashboard and all v18 surfaces untouched; both files server byte-equal.
Landed at the pipeline path, standalone sha `b6da90768caf5413`; WALK-CHARTER
v19 section added. Not represented: CE-7 footer (desk), CE-2's conditional
today-CTA snackbar (no snackbar layer in the prototype).

### RULED — 2026-09-25 (Xuan, desk sitting; qa 9753cba) — entryway RATIFIED w/ reversals; glow + D7 ruled; prototype v20

**Entryway rendering RATIFIED** with three reversals of walked v19 behavior
(the ruling is the contract, not the artifact): G12 summary container = full
PAGE, sheet fork RETIRED; G13 re-pick confirm relabels edits per the TARGET
protocol WITH date ("Day 1 (Fri, Sep 26) — you set 620 g") and collapses to a
single-button notice when every edit falls outside the new window; G14 CE-7
ruled YES — breakdown page gains the navigation-only "Manage plan ›" footer,
read-only holds. Plus G15/F1 feasible-set subtitle and F5 selection-time
feasibility re-check (rides G9, app-side). Copy register v1 = v19 strings
verbatim amended by F1/F3/F4; the F4 notice strings drafted app-side in v20
fold in at re-extraction.

**Glow ruled the GENERAL way**: an emphasis material with usage rules in
tokens.md §Materials — never replaces hairline elevation; LOAD loader + card
are the first ratified uses; every further use must be NAMED per-surface with
a golden. The Flutter glow research (`glow-research.md`) is cited as the
implementation reference. **D7: the breakdown macro strip KEEPS electrolyte**
— now a named Q-D3 exception; do not recolor.

**Prototype v20** ships the four deltas (harness-verified end to end, bundle
smoke-tested in Chrome): source sha `58c4d6471347eae2` (server byte-equal),
bundle sha `2ed6df9b7be7fd0a`. Charter v20 section has the delta walk map.

### FIXED — 2026-09-25 — V20-R1 (chooser under summary); prototype v21

qa's v20 re-walk (qa 20a8af7) verified all four desk deltas but found the F2
stacking trap reborn in the page container: "Change protocol" opened the
chooser at z-25 UNDER the z-26 summary page — an invisible tap. My harness
drove state directly and never checked paint order; it now carries a static
z-order assertion (summary < chooser < dialogs). v21 raises the chooser to
z-27 (stack-above, not replace: chooser back returns to the summary;
selection closes both). Source sha `0caf27d1bfc27473`, bundle sha
`2afe613779653c3e`. Deliberately untouched, pending rulings: F6 (dialogs
offer no abort — touches the "exactly two choices" ruling, Xuan's call);
E1-suppression on the LOAD face + sparkle/"Today's Fuel" strip (qa flags them
for the dashboard extraction; Xuan's word pending).

### GREEN — 2026-09-25 — entryway conformant at v21 (qa fafc10f)

qa re-walked v21 physically end-to-end, no instrumentation: V20-R1 RESOLVED
(chooser paints above the summary; back returns; F3 dialog above the chooser;
Keep collapses to the event row with the 620/748 migration). Bundle sha
verified independently. **The entryway is GREEN against everything ruled.**

Open by design, not omissions: F6 no-abort modality (Xuan's call) · LOAD-face
E1 chevron suppression + sparkle/"Today's Fuel" strip (Xuan's word pending;
will bite at dashboard extraction).

Next, on qa's side: design-ssot-extract of the dashboard/LOAD surfaces from
v21 (LOAD face states, slot cards, slot page, breakdown day-navigation)
against the v18/v20 charter sections → spec/design/; then a ship-readiness
summary to Xuan. **Xuan is the explicit checkpoint before ship-bundle tags
carb-loading@v1 — nothing tags until he says go.**

### EXTRACTED — 2026-09-25 — dashboard surfaces PROPOSED (qa 0091066); Q-D9/Q-D10 await Xuan

qa's dashboard extraction from v21 is done: `surfaces/carb-loading-dashboard.md`
(CD-1..6) + `components/carb-slot-card.md`, both PROPOSED. The walk reproduced
the ruled math on-screen (9 PM = the W7 band edge; a stepper tap flipped the
face 31-behind → On-pace with all five surfaces updating in one frame — CD-2,
the surface's core contract, clean in v21).

Two findings + F6 are Xuan's rulings; NO prototype work until he calls them:

- **Q-D9 — the expanded LOAD face.** It exists against the ratified
  collapsed-only text (E1 suppressed), it is currently the ONLY route to Full
  Breakdown, and it carries two unregistered strings ("249 g to go", "pace N g
  by now"). Options as filed: (a) enforce collapsed-only — Full Breakdown
  moves onto the collapsed face, expansion + strings deleted; (b) amend the
  ruling to admit expansion and register the strings. The prototype today
  implements NEITHER ruled option — a revision comes either way. Context the
  ruling should weigh: collapsed-only was the 09-19 ruling, but Xuan
  explicitly reversed it on 09-20 ("I take that back" — restore expand); the
  ratified amendment captured the earlier state. app-38 recommendation: (b),
  matching his later direction; the loader row already satisfies P-2 either
  way, so (a) is cheap if he prefers the leaner face.
- **Q-D10 — sparkle + "Today's Fuel"** still render on loading days including
  the clock-free future day, against the release-1 exclusion. Needs the strip
  or an explicit re-ruling to keep. app-38 recommendation: strip (it was his
  own exclusion); build is ready to go on his word.
- **F6 — no-abort dialogs** (carried). app-38 recommendation: keep exactly two
  buttons but make backdrop-tap dismiss — an escape without a third choice;
  a destructive switch with no way out is hostile. His call entirely.

After the three rulings + ratification of the two extraction docs, qa
assembles the ship-readiness summary. Xuan remains the explicit checkpoint
before ship-bundle tags.

### RULED — 2026-09-25 (Xuan, interview; qa c7ef9ff) — Q-D9/Q-D10/F6; prototype v22

**Q-D9 = option B**: the LOAD face expansion is ADMITTED — built behavior
becomes the ruled contract (energy-card amendment rewritten: E1 toggles on
LOAD, plain P-1). The expanded strings are REGISTERED: "N g to go" with
to-go = max(target − eaten, 0), and "pace N g by now". v22 conforms the
clamp — and removes "Target met", which v21 rendered at the loaded state and
which was never registered (flagged to qa for re-extraction).
**Q-D10**: sparkle + "Today's Fuel" STRIPPED from loading days in v22; the
composition exclusion stands; regular day unchanged; slot scaffold untouched
(sparkle-independent per Q-CL7).
**F6 = CE-9** (new behavior rule): backdrop tap ABORTS both re-pick dialog
variants — dismisses, plan untouched, chooser stays open; no Cancel button.
App gate G16 with L2 reds in the handback.

v22: source sha `254af8cf3349ef3e` (server byte-equal), bundle sha
`f1c232d958a98bfe`. All three deltas harness-verified (incl. abort leaving
evPlan/evProto untouched and paint order holding). After qa verifies, the
ship-readiness summary goes to Xuan — he gates ship-bundle and the handover.

### BUILT — 2026-09-25/26 overnight — implementation phase 2 (surfaces + tests)

App commits `09f8cce7` (surfaces + data + retirements) and the L2/golden
batch on `feature/carb-loading` (rebased on origin/release/1.27.1). Highlights:

- **Dashboard**: LOAD face (Q-D9 form) on the energy card; `CarbLoadBar` +
  `CarbSlotCard` in kyle_design (glow's first ratified uses, layered-shadow
  route); six slot groups AS the loading-day timeline; slot page composed
  from the Log-a-Meal path (slot-tagged rows); breakdown page w/ chip
  day-navigation + CE-7 footer. CD-1 negative holds (regular day = zero
  carb DOM).
- **Entryway**: two-state row + F1 subtitle + window-passed state; chooser
  w/ 1-Day card, CE-8 disabled-with-reason, F5 re-check, CL-12 point copy;
  plan summary PAGE (stored g/kg + EDITED chips); shared CE-4 dialogs w/
  CE-9 backdrop abort; CE-5 delete. CREATE returns to event details
  (today-CTA snackbar only when underway).
- **Data**: CE-4a in-place repick (repo primitive + service preview/apply);
  G3 rate tables delegate to the engine everywhere (1-Day added; invalid
  inputs throw); MealSlot + three loading-day periods (legacy snack folds
  into Afternoon Snack at display).
- **Retired deliberately**: delete+recreate update paths (carb service +
  controller + calendar copies + their pinning tests); the athlete route
  onto the legacy day page; 8 dead files. QUEUED for Xuan (not silently
  changed): the coach-portal D-020 reader + its legacy-page route; the
  D-020/D-019 column drops (schema work, Lee owns migrations).
- **Tests green**: 49+14 vectors (qa-verified) · repick db-identity suite ·
  assembler register suite (14) · dialog abort/chooser-gate widget suites ·
  entry-row two-state · slot-card SC-1..4 · six LOAD-face L1 goldens
  generated (`test/features/macro_dashboard/goldens/load_face_*.png`).
- **Open app-side**: CD-2 ripple L2 (one-frame five-surface assert) — needs
  an integration-level harness, staged next; qa-smoke drawer⇄engine check;
  the meal_logs.slot CHECK-constraint question (routed to qa-6b: do the new
  wire values need a server migration ride-along at land?).

### OVERNIGHT LOG — 2026-09-26 early hours (post-phase-2 hardening)

- **CD-2 data-plane L2** (0a4ba6f7): the walked Banana ×1→×2 flip pinned at
  the provider — face figure, slot sum, receipt row and breakdown all move
  in ONE recompute. Frame-level half rides Patrol (qa concurred: §5 rules
  L2/Patrol; sim-explore complements, never substitutes).
- **meal_logs.slot CHECK migration** (f4bb5959): qa located the constraint
  in the record (docs/dev_schema.txt:2429, verified first-hand); widening
  migration written per README convention — additive, idempotent, legacy
  'snack' kept, applied BY HAND at land under the standing deploy gate.
  Pre-existing Drift-nullable-vs-PG-NOT-NULL seam noted in the migration
  comment, deliberately untouched, queued.
- **Edit-target entry GAP found** (my find, qa confirmed real): Q-CL10/G6 rule
  edited targets, the ratified chooser footer PROMISES editing, but no
  athlete-reachable edit surface is ruled — the legacy dialog's only athlete
  door was the retired one-shot. Morning item #8: (a) affordance on the plan
  summary's day rows, or (b) editing out of release-1 + a register amendment
  to the footer string. NOT pre-built.
- **CL-12 sweep** (ff5e793b): Edit Target dialog help now states the day's
  own stored g/kg (was "8-12g/kg"); the caller-less calendar duplicate of
  the chooser deleted.
- **Full-suite triage** (ed250353): 4279 pass. Of 35 fails, 50 were MINE by
  root cause (the carb watch threw in harnesses without its dependency
  chain → whole dashboard down; plus one smoke of the deleted screen) —
  fixed by making the carb lookup FAIL SOFT (production-correct: a lookup
  error renders the regular day, never a dead dashboard). Remaining 4 are
  pre-existing, verified failing identically on bare origin/release/1.27.1:
  ci_config develop-test-gate row, CF-2 clamp caption, and the two
  env-gated manual_live API suites.
- **Final confirmation run**: 4,319 pass · the same 4 pre-existing base reds
  · 1 ai_credits poll-timing test that failed once and passes in isolation
  (the recorded full-suite flake class). ZERO regressions from the
  carb-loading implementation.
- **QA verification at tip 2cf593b8: GREEN, no findings.** Both conformance
  arms re-run against a fresh detached worktree (49/49 + 14/14); 293 tests
  green across carb_loading + macro_dashboard + events incl. the six
  LOAD-face goldens (regeneration rule LIVE from here); mirror byte-identical
  to the tag (vector-file drift = the planned engine repoint, re-mirror
  rides land). Remaining sequence: Xuan's 8 morning rulings → frame-level
  CD-2 Patrol → land-bundle (official runner invocation across every slice +
  dev attestation + Xuan's explicit go).

### RULED + BUILT — 2026-09-26 morning — G17/G18/G19 (qa 7729a99)

Xuan's morning queue ruled; all three new gates green same morning:

- **G17 / CE-10**: the plan summary's day rows (today + future; past inert)
  open the EXISTING Edit Target dialog; save persists grams + stored g/kg
  via the new `updateDayTarget` controller path; EDITED chip re-derives.
  L2 rows `summary-row-opens-edit-dialog` / `past-day-row-inert` /
  `edit-save-rederives` green (fake-controller harness, mutable store).
  The edit-entry gap (#8) is CLOSED.
- **G18**: the slot migration also DROPS NOT NULL (null = untagged,
  CL-11-consistent; explicit `slot IS NULL OR` arm in the CHECK rather than
  leaning on three-valued logic). Seam test with producer-shaped stored
  rows: null-slot payload sends `slot: null` explicitly; loading-day wire
  values round-trip; unknown future values skip, never crash.
- **G19**: register amendment — completion's expanded face reads
  `Target met` in place of the to-go figure (un-loaded states keep the
  clamp). Assembler branch + amended register test + NEW
  `load_face_expanded_loaded` golden citing this ruling. Prototype v23
  delta pending (non-gating, "when convenient").
- Also ruled, no app action: portal + D-019/D-020 drops DEFERRED together
  (ops documents); Q-019 direction = option 1 but it is the
  loading-day-macros-coupling bundle's work — nothing under this tag.

Suites: 214 green across carb_loading + macro_dashboard + the seam test;
lib analyzer clean. Sim run: dev flavor live on iPhone 17 from this branch
— Day 1 of the Augusta plan renders the LOAD face with the on-device pace
verdict matching the oracle (22 g behind at 6:29 AM).

### GREEN — 2026-09-26 — frame-level CD-2 Patrol on device (land board #1)

`carb_loading_ripple_flow_test.dart` passes on the iPhone 17 sim against the
LIVE dev account: one banana write through the real controller → face label
+ both pace strings + slot header + breakdown hero all painted equal to the
container's own derivation after one settle. Two productive failures on the
way: run 1 proved the whole contract and tripped only on a cleanup finder;
run 2 caught a REAL defect — unconstrained header rows (breakdown + plan
summary) able to overflow horizontally — both hardened with flex+ellipsis.
The flow self-seeds only when today has no plan, and sweeps any orphaned
Patrol bananas by name.

### G23 CLOSED — 2026-09-25 — diagnosis (two mechanisms) + G23a fix (qa 38bd8a3)

**Mechanism 1 (phantom, no code change).** The 07:29/07:37 "day-3/680 under
Today Sep 25" sightings were the CD-2 Patrol flow's own seeded plan: the flow
signs the sim into the dedicated Patrol account (avery@test.com), found no
plan there, and seeded a 3-day race-tomorrow plan — Sep 25 IS its day 3,
680 g (149.9 lb → 67.99 kg × 10 g/kg). Patrol runs 1–2 aborted before tail
cleanup, so the debris persisted across the observation window; run 3–4
sweeps removed it, leaving the "carb face absent" pole (avery owns no
Sep-25 plan — correct CD-1 negative). One-driver-per-sim class, closed.
Ruled: avery STAYS the Patrol account; restore the dev login after runs;
observations during a Patrol window are unreliable by definition.

**Mechanism 2 = G23a (real defect, fixed to green).** The entryway passes
`raceDate = DateTime.parse(event.startTime!)` — the gun time
(2026-09-27T07:30) leaked into `carb_loading_days.plan_date`
(evidence row: avery's live-created plan dbe80e8d, day at Sep 26 07:30),
and the dashboard's midnight-keyed reads can never match it: a plan created
from any timed event never rendered. Fix: repository create normalizes
raceDate to the local date (plan bounds + day rows); service normalizes the
event's `carbLoadingStartDate` the same way; both day-row read paths
(`getCarbLoadingDaysForDateRange`, now a [day, day+1) span query, and
`getCarbLoadingDaysForPlan`) hand callers midnight-normalized rows so
pre-fix rows already on devices resolve too. Test
`g23a_plan_date_normalization_test.dart`: one test asserts midnight storage
AND the loading-day render (mutation-probed red on the create revert);
second test covers the legacy 07:30-row defense. Wire note: the upload
serializer truncates to date-only (`split('T')[0]`), so the SERVER copies
of affected rows are clean — local Drift rows were the exposure.
Blast-radius counts on dev/prod (`plan_date::time <> 00:00`, server column
is `timestamp`) are QUEUED: the Management API query is classifier-blocked
in auto mode (playbook §7 note) — SQL prepared, runs at Xuan's direction in
default mode. G23b (overlap tie-order) WITHDRAWN by qa — excluded
overlapping-loads slice; documented edge, no tie-break built. The stale
1-day plan is released for Xuan's CE-5 delete exercise whenever he wants.

Suites: 493 green across carb_loading + macro_dashboard + meal_logging +
events (1 pre-existing skip).

### G21-B GREEN — 2026-09-25 — Recommended section reads the legacy store (D-022)

Per the pin (fork option B, qa d736cf4): the slot page grows the
"Recommended for {slot}" section, fed by `carbSlotRecommendationsProvider`
→ the EXISTING `carb_loading_foods` store via `getFoodsByMealType`
(`meal_types` = per-slot suitability, incl. the store's shipped tolerance:
null/empty = suitable everywhere). Fixed curation order = the store's
curation key `name` asc, id tiebreak — deterministic on every device
(mutation-probed: dropping the sort fails the seam's order assertion).
Row copy is prototype-verbatim ('N g carbs per serving'); tapping a row
hands off to the SHIPPING Log-a-Meal surface with a new `initialQuery`
seeding the unified search (composition ruling holds — no bespoke logging,
no nutrition math invented from the store's carbs-only rows). Section
renders today-only, same gate as Add Food. Empty/failed store reads render
the quiet empty state ('No recommendations yet.'), never a crash.
Reds green in `carb_slot_recommendations_seam_test.dart`: producer-shaped
rows (the sync path's verbatim local write — Postgres name-array literals
`{breakfast,lunch}` from the server's text[]) render suitability-filtered
in curation order; empty store renders the empty state. Data freshness per
qa's note: the sim's local store carries 27 seeded rows in exactly that
shape — the section renders live, no deploy dependency. No library
columns; unification stays D-022 + the parked follow-up intake.

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

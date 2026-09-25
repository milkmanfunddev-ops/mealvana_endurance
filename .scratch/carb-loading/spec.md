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

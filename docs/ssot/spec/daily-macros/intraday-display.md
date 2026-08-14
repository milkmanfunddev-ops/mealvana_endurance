# SSOT — Daily Macros: Intraday Display Quantities

**Status: RATIFIED v1 (Xuan, 2026-08-13).** §1's accrual rulings (BMR since-midnight; fallback
NEAT via F12–F14 over the assumed waking window; TEF in the Digestion row; decomposed display)
were confirmed with this ratification.
**Origin:** F-10, F-11, F-12, F-14, F-15, F-17 of the macro-dashboard design reconciliation — six
quantities and behaviours the dashboard displays that no document owned.
**Engine:** none — **everything in this file is display-layer arithmetic, strictly downstream of
the daily-macros engine. Nothing here changes any engine output, ever.** A consumer computes these
from the returned plan plus the day's log; the engine never sees them.
**Every constant in this file is `[design]`** unless marked otherwise. The engine's numbers carry
the evidence; these carry the presentation.

## The rule
> The engine answers "what should today total?" This file answers the only questions the dashboard
> may derive on its own: "where should I be *by now*, what have I *actually* done, and what is
> still owed?" — without ever inventing a quantity the engine doesn't stand behind.

---

## §1 · Intraday accrual (F-10) — distilled from the Notion proration proposal

**Source:** Notion *"proration-proposal"* (under Daily Macro Calculation) — discovered 2026-08-13,
after this file's first draft. Its principle supersedes the draft's uniform clock smear and is
adopted here: **each burned-side component accrues by the method that matches its real driver and
what we can actually observe live.** "We have a population estimate" is true of every term — it is
not the test. The test is whether the term accrues evenly across the clock, and whether a better
live signal exists.

```
# BMR — the only term where clock proration is both correct and necessary
resting_so_far   = rmr × (minutes_since_midnight / 1440)

# TEF — meal-driven, never clock-prorated; ~0 before the first meal by construction
digestion_so_far = 0.10 × eaten_so_far

# EAT — atomic completed sessions, valued by the F22 resolution ladder
workout_so_far   = Σ kcal of COMPLETED sessions          # GARMIN → TP_ACTUAL → FORMULA

# NEAT — measured when we can, modeled when we must
if wearable_connected and synced_today:
    neat_so_far  = max(0, active_energy_through_last_sync
                          − Σ WEARABLE-RECORDED workout kcal through last_sync)
                   + neat_rate_model × minutes_since_last_sync_in_waking_window
else:
    neat_so_far  = neat_kcal × (waking_minutes_elapsed / total_waking_minutes)
                   # waking window assumed 07:00–23:00 (16 h) when sleep data absent

burned_so_far    = resting_so_far + digestion_so_far + workout_so_far + neat_so_far
*_by_days_end    = the engine's returned values, verbatim
```

**Where the data is real and where it is estimate — stated honestly, term by term:**

- **BMR — always modeled, never observable live.** Clock proration is faithful because basal burn
  is near-constant per minute. Since-midnight basis `[design]` (the proposal's own recommendation:
  the overnight metabolic dip makes pre-dawn run slightly hot; revisit only if that surfaces).
- **TEF — derived from a real driver we track (logged intake), which is itself self-reported.**
  Chip: *estimated*. The eat-raises-burned coupling is physiologically correct and is surfaced in
  the decomposed breakdown row with an explainer, not hidden (proposal open-decision 3, ruled:
  fold into the Digestion row, keep the ⓘ).
- **EAT — the spine, but "verified" only when a wearable recorded it.** For non-connected users a
  completed session is valued by the formula (F4 via the F22 ladder) and chips *estimated* /
  *planned*, never *verified*. The proposal's framing quietly assumed Garmin; the fallback is the
  same ladder the engine already uses, so no new estimate is invented.
- **NEAT — the softest term, and the one with two genuine data gaps the proposal glossed:**
  1. **Sync staleness.** Wearable active energy is only current as-of last sync (minutes to hours
     stale). Best estimate `[design]`: measured value through the sync, plus the *model rate* for
     waking minutes since — never a flat freeze (undercounts an active afternoon) and never
     re-prorating the whole day (discards the measurement).
  2. **The double-count guard is asymmetric.** Subtract only **wearable-recorded** workout kcal
     from wearable active energy — a TP/formula-valued session a watch never saw is *not* in the
     wearable total, and subtracting it would silently delete real NEAT. `max(0, …)` guards the
     remaining edge. `[design]`
  3. **Waking window.** Garmin sleep when available; else an assumed **07:00–23:00** window
     `[design]` — we do not collect bedtimes, and a population assumption beats crediting phantom
     movement at 3 a.m. (the proposal's own argument against uniform smear).
- **A session is atomic.** Completed counts in full; upcoming counts zero; a half-finished workout
  is the device's to report, never a clock fraction's.

**Ruled per the proposal's open decisions (confirmed by ratification, Xuan, 2026-08-13):** (1) BMR since-midnight; (2) the no-wearable NEAT fallback is the engine's own F12–F14
estimate over the assumed waking window, chipped *estimated* — its rigor concern is already
Q-015's, not a new one; (3) TEF folded into the decomposed Digestion row with explainer;
(4) decomposed display — which the dashboard's Today's Energy modal already implements, chips and
all (TRACED A1/A4: the design was evidently built from this proposal).

## §2 · Net energy balance and its copy (F-11)

```
net_so_far = eaten_so_far − burned_so_far      # signed kcal
```

| Band (`[design]`) | Copy register |
|---|---|
| −200 … +200 | "on track" |
| +200 … +500 | "slight surplus" |
| > +500 | "surplus" |
| −500 … −200 | "slight deficit" — supportive, directive toward eating |
| < −500 | "deficit — time to eat" |

**Two hard rules, both safety-derived:**

1. **When `energy_basis == "pre_override"`, surplus copy is suppressed entirely.** The EA gate
   deliberately set intake above burn; calling a safety floor a "surplus" tells an under-fueled
   athlete to eat less. The banner explains the raised target instead (F-19 ruling).
2. **Deficit copy is never congratulatory.** This is a RED-S-aware product; the display must not
   reward under-eating. Deficit-side copy always points toward food, never toward achievement.

**Known tension, recorded (2026-08-13):** persona runs show ordinary balanced training days landing
at EA 39–44 — inside SOFT_WARNING — because intake ≡ TDEE mathematically yields sub-45 EA for lean
athletes on training days. Net-balance copy ("on track") and the EA SOFT banner will therefore
routinely co-occur. The display must present SOFT as informational, not alarming, or it trains
alert fatigue; whether SOFT's threshold itself deserves recalibration is a future engine question,
not a display one.

## §3 · Planned-but-uneaten intake (F-12)

Three definitions, and consumers may not blur them:

```
logged     = Σ macros of consumed entries              # actuals
planned    = Σ macros of scheduled, unconsumed entries # forecast
remaining  = target − logged                           # what is still owed
projected  = logged + planned                          # forecast total, COPY ONLY
```

- **`remaining` subtracts `logged` only.** A scheduled dinner reduces nothing until eaten.
- **`projected` may drive copy** ("on pace to hit your target") **and ring overlays; it may never
  drive `remaining`, EA, or net balance** — those are actuals-only. Planned food does not protect
  an athlete from a real deficit.
- The ring format (solid = logged, faint = + planned) is the endorsed rendering of this
  distinction.

## §4 · Recorded deferrals (F-14, F-15) — decisions, not omissions

- **Meal-level distribution (F-14): deferred.** v1 meals are athlete-entered (logged or planned);
  the engine distributes nothing across meals. "Spread carbs evenly and anchor each meal with
  protein" is guidance copy, not computation. An engine-generated meal split is a future SSOT of
  its own — it is the daily analogue of the pre-workout tier system and deserves the same rigor.
- **Meal suggestion / swap engine (F-15): deferred to a future bundle**, with one v1 boundary:
  suggestions may be filtered by §3's `remaining` arithmetic (pure subtraction), but **may not
  claim suitability** ("good before your ride") — suitability claims require the daily analogue of
  `pre-workout-food-composition.md`, which does not exist. The post-workout recovery feeding is
  the one exception: `post-workout.md` (RATIFIED v1) bounds what it may claim.

## §4b · Deleting an activity is a SOFT delete — RULED (Xuan, 2026-08-14, post-ratification addition)

**When a user deletes an activity, the Supabase row survives: `status` becomes `deleted`, the row
is never removed.** The reason is sync-loop protection, and it is load-bearing: a hard-deleted
activity no longer exists locally, so the next TrainingPeaks/Garmin sync re-imports it and the
workout the user deleted **mysteriously reappears**. A tombstone row gives the sync match
something to hit — the activity is recognized as already-known-and-deleted and is not
re-populated into the interface.

Display contract (this file's side):
- A `status = deleted` activity **never renders** on any surface and contributes **zero** to every
  derived quantity in §§1–3 (burned-so-far, projected, net, remaining) — identical in effect to
  nonexistence, different only in storage.
- Deletion is not un-doable by sync: only an explicit user action (or nothing) changes a
  `deleted` row's status.

Sync-side counterpart: `platform-resolution.md` (the matcher must include `deleted` rows).

## §5 · Tracking-off is a display mode, never an engine mode (F-17)

When the athlete hides numbers: **the engine still runs, the EA gate still evaluates, and a
`BLOCK` still surfaces.** Every quantity in this file may be hidden; the safety gate's refusal to
generate a plan may not be. The athlete who hides numbers is disproportionately the athlete the EA
gate exists to protect — tracking-off silently disabling safety is the one configuration this spec
forbids.

What tracking-off hides: all §1–§3 quantities, macro rings, kcal on timeline entries. What it
never suppresses: BLOCK, HARD_WARNING's raised-target state, and the fuel-plan windows (which are
instructions, not tracking).

## Constants — basis and confidence

| Element | Value | Basis | Confidence |
|---|---|---|---|
| Accrual principle | per-component, by real driver | Notion proration proposal (upstream intent), distilled 2026-08-13 | High (as design intent) |
| BMR basis | since-midnight | proposal's recommendation; overnight dip accepted as slight pre-dawn overstatement | Medium |
| Assumed waking window | 07:00–23:00 | `[design]` — no bedtime data for non-connected users | Low |
| NEAT staleness bridge | model rate since last sync | `[design]` — freeze undercounts, re-smear discards measurement | Low–Medium |
| EAT/NEAT double-count guard | subtract wearable-recorded only | `[design]` — data-integration necessity the proposal glossed | High (as policy) |
| Sessions atomic | — | `[design]` — mid-session data belongs to the device | High (as policy) |
| Digestion-so-far | 0.10 × eaten | mirrors the engine's TEF rate — agreement at day's end by construction | High |
| Net-balance bands | ±200 / ±500 | `[design]` — round numbers sized to TEF-scale noise | Low |
| Surplus suppression under `pre_override` | — | Q-009 ruling + RED-S rationale | High |
| No congratulatory deficit copy | — | RED-S posture (Mountjoy 2018 lineage, via EA spec) | High |
| `remaining = target − logged` | — | `[design]` — planned food protects nothing | High (as policy) |
| Tracking-off never disables the gate | — | Safety: the hiding athlete is the at-risk athlete | High (as policy) |

## Conformance

Display-layer, engine-independent — checks are properties of any consumer:

1. `burned_so_far(1440 min, all sessions complete, eaten = target)` equals the engine's TDEE
   exactly — accrual converges to the plan at midnight. **Fallback path only**: on the connected
   path the measured NEAT legitimately diverges from the model, and day's-end reconciliation is
   retrospective mode's job (F23), not this file's.
1b. TEF-so-far is exactly 0 before the first logged intake; NEAT-so-far is exactly 0 before the
   waking window opens on the fallback path.
1c. A wearable-recorded workout appears once in `burned_so_far`, never twice (the EAT/NEAT
   subtraction guard); a formula-valued session is never subtracted from wearable active energy.
2. No session ever contributes a fraction of its kcal.
3. `remaining` is unaffected by adding, moving, or deleting *planned* entries.
4. EA and net balance are byte-identical whether planned entries exist or not.
5. With `energy_basis = "pre_override"`: no surplus string appears anywhere.
6. No deficit string contains congratulatory language (enumerate the copy strings; this is a
   string-level check, not a sentiment guess).
7. With tracking off: BLOCK and HARD_WARNING still render; every §1–§3 number is absent.
8. Vectors: `qa/vectors/daily-macros/intraday-display.json` (after ratification).

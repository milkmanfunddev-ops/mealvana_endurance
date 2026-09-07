# sim-explore — food recommendation (charter C-1…C-15)

**Build under test:** dev flavor, built locally from app `develop` @ `75a8ef77`
(`flutter build ios --simulator --flavor dev --target lib/main_dev.dart`).
**Device:** iPhone 17 simulator `860F418A` · iOS 26.4.
**Account:** shared dev test account, `allergies = {dairy, gluten}`, `dietary_preference = omnivore`.
**Backend:** deployed dev (`vlmtsdzpnjnavdgytcmi`). No prod contact.

> **Setup trap worth recording:** the simulator was carrying the **Patrol test-runner**
> build, not the app — launching it showed "Test starting…", not the timeline. Any
> sim-explore run that follows a Patrol session must reinstall the real dev app first, or
> it is exploring the wrong binary. (Known trap, hit again.)

## Row verdicts

| # | Verdict | Evidence |
|---|---|---|
| C-1 | **PASS** | Window + caption re-derive across §3a class boundaries: Race Pace ⇒ `3 HOURS` / "3 H — RACE DAY"; Easy Run ⇒ `2 HOURS 30 MIN` / "2.5 H — MID-DISTANCE". Q-CF1 caption ships and is correct. |
| C-2 | **PASS (partial)** | At the default start (always 60–75 min out) the stepper opens AT the cap with `CAPPED: SESSION IN 1 H 12 MIN`, and `+` is **inert** — tapped twice, value unchanged, caption retained. Did not separately construct a 45-min-out plan. |
| C-3 | **PASS** | 5:00 am Easy Run (training) ⇒ `1 HOUR` / "1 H — EARLY START". Same 5:00 am switched to Race Pace ⇒ holds `3 HOURS` / "RACE DAY". The overlay correctly applies to training only. |
| C-5 | **PASS** | No saved pace ⇒ `9:00 /mi`, the ruled fallback. No 4:30/mi (F-27 class) anywhere. |
| C-6 | **PASS** | During sodium 1115 mg met by **3 Electrolyte Capsules** — capsules scaled, not a single liquid hit. Sodium sources = Sports Drink + Capsules = **exactly 2** (§4 ≤2 honoured). |
| C-7 | **PASS** | `4.5 cups Sports Drink` is paired with `1 cup Water`. And `0.5 packets Energy Chews` — **C3a divisibility confirmed live**; nothing forced to whole units that shouldn't be. |
| C-8 | **PASS** | Meal tier is composed, not multiplied: `Bread / Toast + Peanut Butter` (meal), `Honey + Rice Cake` (snack), `Applesauce Pouch` (top-off). No "Banana ×3". |
| C-9 | **PASS** | During 45 oz over 1 h 48 m; pre 22 oz. No 44 oz pre-workout (P13 class). PRE sodium renders `—` (null), not `0` — the null/zero distinction holds on the surface. |
| C-12 | **PASS** (after a correction — see SE-1) | With gluten on file the chip renders `Contains gluten — your allergy` as an emphasized filled pill while `Contains dairy` stays neutral. Ratified FP behavior. |
| C-4 | **PASS** | `isFasted` survives only as a data-layer field (`activity_mapper`, DB column). NO Fasted control exists in any presentation widget — the one hit under `presentation/` is a doc comment. §7's retirement holds at the surface. |
| C-10 | **PASS** (by hand + Patrol) | Pin a gluten formula → FP-4a warning with **"Choose another"** as the FILLED primary above **"Pin anyway"** as the outline (R-01 option 1). Choose another dismisses and pins NOTHING. Pin anyway honors it and adds **"● Pinned despite your gluten allergy"**; a dairy conflict reads **"...your dairy allergy"** — the right allergen each time. Unpin clears the label. |
| C-11 | **PASS** | `PinConflictWarning.diet` passes `onChooseAnother = null` and renders NO action pair — one soft line, exactly FP-4a. Confirmed in code and by the flow walking into it. |
| C-14 | **PASS** for the pin flow | `CoachInsightPanel` renders ONLY in `formula_editor_screen.dart` (authoring). Library, detail and the pin toggles never mount it. Its existence in the editor is pre-existing and outside this row's scope. |
| C-13, C-15 | not walked | C-13 (author a formula with your allergen; Save stays enabled) needs the editor. C-15 (offline twin parity) needs an airplane-mode pass. |

## Findings

### SE-1 — RETRACTED: the allergen-emphasis "bug" was my misreading · C-12 PASSES

**I filed this as a Major bug and it was wrong.** Recorded here rather than deleted,
because the mistake is the reusable lesson.

The claim was: the account's allergies are dairy+gluten, the opened formula contains both,
and neither chip is emphasized. The premise was false. **The local Drift mirror holds rows
for more than one user.** I ran `select allergies from users`, took the first row —
`{dairy,gluten}`, belonging to **ravi@test.com** — and attributed it to the signed-in
account, which is **avery@test.com** with `allergies = {}`. Settings said "No allergies"
in plain sight and I read past it. With nothing on file, neutral chips are *correct*;
there was nothing to emphasize.

Re-tested properly — set gluten on avery, cleared the library's auto-applied hide filter,
reopened the same formula:

> `Contains gluten — your allergy` renders as an **emphasized filled pill**, while
> `Contains dairy` — not this athlete's allergen — stays neutral.

That is exactly the ratified contract. **C-12 PASSES.** The ops bug report was retracted
(`ops` @ `ff9c4b5`).

**Method rule this earns:** on a shared device the local `users` table is not a profile
read. Query it **by email** and match it against the account Settings shows.

What survives is minor and is a copy question, not a defect: the diet chips are still
machine negations (`Not Gluten Free`, `Not Keto`, `Not Low-Carb`, `Not Paleo`,
`Not Vegan`), and `Contains gluten — your allergy` now sits beside a redundant
`Not Gluten Free`. Worth a ruling-desk line; not worth a bug.

### SE-1b — The pin-conflict Patrol flow was passing VACUOUSLY · Major (test defect, mine) · NOW FIXED

The real defect the C-12 chase uncovered, and it is in my own test.

`formula_pin_conflict_flow_test.dart` hunts for a conflicting formula by tapping
thumbtacks, and self-skips if it finds none. **The library pre-selects the athlete's
profile allergens under "HIDE FORMULAS WITH"** — so on any account that actually has an
allergy, every conflicting formula is filtered out *before the walk begins*. With gluten
on file the Before list showed **"15 / 29"**. The loop can never raise FP-4a, the flow
self-skips, and — because patrol's summary reports a skipped test as
**"Successful: 1 / Skipped: 0"** — it reports **green while asserting nothing**.

That is the worst failure mode a test can have, and I shipped it green in the previous
message. Two fixes, both in `75a8ef77`'s successor:

1. **Step 1b**: open More filters, deselect every *active* allergen chip, apply. (Reset is
   no use — `clearMoreFilters()` re-seeds `activeAllergyFilters` from the profile.)
   Selection is read dynamically off the private `_Chip.selected`.
2. **The skip path now prints `FLOW-VACUOUS:` loudly**, so a vacuous run is visible in the
   log even though patrol's counters call it a pass.

Running it then exposed three more test defects, each a different way a **lazy, re-sorting
list** defeats naive finders — worth writing down because they will bite the next flow:

3. **Card identity must be the card's own key, never a list index.** Pinning moves a card up
   into "Your Formulas", so `toggles.at(i)` stops pointing at the card the hunt found. The
   assertions were reading a *different, genuinely pinned* card — and reporting FP-4a broken.
4. **Never assert a screen-wide count on a lazy list.** Collapsing the warning shrinks the
   card and pulls more items into the viewport, so an FP-4b label count changes from layout
   alone with nothing pinned. Ask the card under test directly instead.
5. **A card scrolled out of a lazy viewport is not built at all** — `Bad state: No element`,
   not an app failure. Reads and taps must scroll it back in, in either direction.

**Final state: green and verified non-vacuous** (app `7673e4a0`). The run walks a real card
`before_card_pin_97867d93…` through FP-4a → Choose another → re-pin → Pin anyway → FP-4b label
→ expand → Unpin. Every one of those behaviors was ALSO confirmed by hand on device with
screenshots before the test was trusted — which is the only reason I could tell test artifact
from app defect at each step.

### SE-2 — Create form reopens carrying the previous activity's inputs · Minor, ruling-adjacent
Opening "+ Add Activity" pre-filled Distance `12.0` and name `12 mi Run` from an earlier
session — not defaults. The window itself correctly resets (D-018 is fixed, and now
Patrol-pinned), but the rest of the form does not. This is exactly **Q-CA2 (form-state
lifetime)**, still open on the ruling desk — recording that it is live and visible, not
theoretical.

### SE-3 — Timeline swipe offers "Skip", not delete; delete lives only in plan detail · Minor
Swiping an activity card reveals a single **Skip** action. Deletion is only reachable by
opening the activity and using the trash icon. This is the direct explanation of the
**pre-existing** `activities_crud_flow` Patrol failure ("Activity card should be wrapped
in a Dismissible") — the test encodes a delete-by-swipe contract the UI no longer offers.
The flow needs updating to the current affordance, or the affordance needs restoring;
that is a decision, not a bug fix. (Failure confirmed pre-existing on `80230b59`, before
this bundle's merge.)

### SE-4 — `DurationPaceToggle` is dead code holding live-looking test keys · Low
`lib/shared/widgets/kyle_design/inputs/duration_pace_toggle.dart` has **zero call sites**
yet owns `activity_create.by_duration_toggle` / `by_pace_toggle`. Mode is really switched
by the duration/pace fields' own `onActivate`. Cost one Patrol iteration.

### SE-5 — "Brick" action absent on a day with one activity · Observation, not filed
The day-action row showed `+ Add Food · + Add Activity · Brick` on Sep 3 (multiple
activities) but only the first two on Sep 10 (one activity). Consistent with brick needing
≥2 legs; noted so nobody reports it as a missing button.

## Cross-check (ledger)
Pre-walk dev funnel: step3 509 (50.9 %) · step4 325 (32.5 %) · brick 108 · n/a-swim 33 ·
step1 20 (2.0 %) · step2 5 (0.5 %).
Post-walk: **step3 510** — my probe plan resolved at the **default-template tier**, correct
for an account with nothing pinned for running/during. Note dev's funnel is dominated by
synthetic bench traffic and is an ENGINE-MIX figure, not a population one; §10's
"steps 1+2 ≥ 60 %" target is only meaningful against prod human rows.

## Cleanup
One row created: `12 mi RunPROBE-race-5am` (Sep 10, 5:00 am). Deleted through the app's
own delete action (so the tombstone syncs) and **re-verified**: `status = deleted`, zero
live `%PROBE%` rows remain for the account.

## Account residue — needs your attention

**`avery@test.com` now has `allergies = {gluten}`; it was `{}` before this session.**

I set it deliberately: with no allergy on file, charter rows C-10/C-11/C-12/C-13 are all
unwalkable (nothing can conflict), and I needed a real allergen to get a true verdict on the
C-12 claim I had wrongly filed. I could not revert it — `scripts/sim-dev-login.sh` reads only
`ravi@test.com` from the Keychain, so I have no way to sign in as avery. **Please clear it, or
tell me it can stay.**

For the record on which account is which:
- **`ravi@test.com`** — allergies `{dairy, gluten}`. This is what `sim-dev-login.sh` and the
  Patrol `integration_test.env` use, so it is the account every automated flow runs as.
- **`avery@test.com`** — allergies were `{}`, now `{gluten}` (mine). This was the account the
  simulator happened to be signed into manually when the walk began, which is precisely how I
  misattributed the profile in the first place.

Pins created by the failing Patrol runs (Bagel + Cream Cheese, Applesauce Pouch, Bagel + PB +
Jam, all on ravi) were unpinned by hand and re-verified: zero "Pinned despite" labels remain.
The now-green flow unpins after itself.

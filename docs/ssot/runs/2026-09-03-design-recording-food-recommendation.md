# Design recording — food-recommendation surfaces vs the ratified math (2026-09-03)

**Build:** dev app on iPhone 17 sim (post brick-transition@v1 + @v2.1) · account ravi@test.com.
**Purpose (Xuan):** record as-built design against the freshly ratified `food-recommendation.md`,
register deviations/gaps for ratification. The app is the reference rendering (transition-card
precedent). Screenshots: `runs/2026-09-03-design-recording/`.

## Surfaces walked
brick detail (before card, during-run section, ? drawer carb/fluid/sodium) · create flow
(fueling-window stepper, fasted toggle, weather steppers + location-blocked state) · pin banner
(from probe film, `pin-banner-ref.png`).

## Gap register
| # | Finding | Class | Action |
|---|---|---|---|
| DG-1 | ~~C3 migration incomplete~~ **RETRACTED (Xuan ruling 2026-09-03 → C3a):** powder mixes are legitimately divisible (1.5 packets in a bottle is normal, esp. cycling); the gels-only migration was CORRECT; C3's wording clarified in catalog-conventions C3a. Transitions keep C4 whole-units | retracted → ruling folded | none |
| DG-2 | Fasted toggle present in create flow (`07`) | conforms-pending-removal | A1-staged (§7); rides the bundle |
| DG-3 | Window stepper shows the retiring formula's default (1:30 for the default run); §3a defaults + clamp not implemented yet | EXPECTED-RED vs §3a | stepper contract recorded as PROPOSED spec (below) |
| DG-4 | During ? drawer carb/fluid/sodium sections REPRODUCE the ratified target math line-for-line (127min → band 45–60 → gut → midpoint → ceiling; sweat×conc for sodium) (`02`,`03`) | **conformance positive** | two-layer check stays green; note: no explanation surface exists for *selection* (why these items / which step resolved) — optional design question, not blocking |
| DG-5 | The during-run card + its drawer have **no design SSOT** (before-card, feeding-card, fuel-stat, transition-card exist; during does not) | design-spec gap | dedicated design-ssot-extract pass — proposed to ride the bundle or follow it |
| DG-6 | Pin banner / formula management surface has no design SSOT and is about to gain the conflict label | design-spec gap + the named blocker | folds into the pin-conflict-label Claude Design iteration (BUNDLE BLOCKER per Xuan 2026-09-03) |
| DG-7 | Weather steppers degrade gracefully when location is blocked ("Location permission blocked · Open app settings") (`07`) | as-built, sound | recorded |

## Bundle gating (Xuan, 2026-09-03) — **CLEARED 2026-09-03**
~~`ship-bundle` for food-recommendation is blocked on the pin-conflict-label design being designed
and ratified~~ → **DONE: designed (formula-kit v4), reconciled, and `formula-pin-surface.md` RATIFIED by Xuan 2026-09-03. No design work gates the bundle.** Original wording (prompts: `runs/2026-09-03-pin-conflict-label-design-prompts.md`). DG-1's migration
line and DG-3's stepper contract ride the bundle; DG-5's extraction may trail it.

### Addendum 2026-09-03 — prototype consistency check (Xuan's ask)
Opened `formula-kit-v2.html` in Chrome (localhost) beside the app's live screen: **NOT consistent.**
Prototype = "Formula Kit", Before/During only, chevron cards, mock foods (Fruit Bowl/Smoothie Bowl
absent from the live catalog). App = "Formula Library", Before/During/After, "Your Formulas · + New"
personal-formula section, per-card pin toggles, live data (`11-formula-kit-app.png`). Ruling for the
design job: reconstruct-from-screenshot; v2.html retired as a starting point (FP-6).

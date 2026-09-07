# Deferred ledger — food-recommendation

Known-open items carried by `food-recommendation@v1.1`. Every line is a CONSCIOUS
carry, not an oversight: it names what is not done and the condition that closes it.
Re-verdict this whole file at the next RC gate (`sim-explore` rule 5).

Opened 2026-09-04 after the post-landing sim-explore walk.

| id | item | why deferred | un-deferred by |
|---|---|---|---|
| ~~FR-D1~~ **CLOSED 2026-09-04** | ~~`activities_crud_flow` Patrol test is RED~~ | **Pre-existing, not this bundle** — proven by an identical failure on pre-merge `80230b59`. The test asserts an activity card is wrapped in a `Dismissible` (swipe-to-delete); the timeline now offers **Skip** on swipe, and delete lives on the plan-detail trash icon. This is a contract decision, not a bug fix. | **Xuan ruled: update the test.** Done — the flow now opens the card → app-bar trash → confirm dialog (app `5cc182cd`). Green, 1/0, with the Supabase read-back intact. |
| FR-D2 | Q-CA2 — create-form state outlives the activity | Seen live 2026-09-04: "+ Add Activity" reopened pre-filled with `12.0` mi / "12 mi Run" from an earlier session. The fueling WINDOW correctly resets (D-018 fixed and now Patrol-pinned); the rest of the form does not. Pre-existing, unchanged by this bundle. | The open Q-CA2 ruling on form-state lifetime, then a matching reset in `_initializeFromEventData` and a Patrol assertion beside the window one. |
| FR-D3 | Formula-detail diet chips read as machine negations | `Not Gluten Free · Not Keto · Not Low-Carb · Not Paleo · Not Vegan`, and `Contains gluten — your allergy` sits beside a redundant `Not Gluten Free`. The allergen EMPHASIS itself is correct (C-12 passes) — this is copy register only. | A copy ruling: suppress false diet chips, or restate them affirmatively. Then update `formula-pin-surface.md` and the golden. |
| FR-D4 | `DurationPaceToggle` is dead code holding live-looking keys | Zero call sites in `lib/`, yet owns `activity_create.by_duration_toggle` / `by_pace_toggle`. Mode is really switched by the duration/pace fields' own `onActivate`. Cost one Patrol iteration. | Delete the widget, or comment the keys as dead. |
| FR-D5 | §3a preset→window mapping is not Patrol-assertable on a fresh create form | `defaultNewActivityDateTime` seeds start at now + 1 h (rounded to 15), so time-until-start is always 60-75 min and the §3 clamp collapses race 180 / mid 150 / moderate 120 to ONE value. Covered by the unit suite and confirmed by hand (Race Pace ⇒ `3 HOURS` once the clamp is released). | A flow that drives the date/time picker to a far-future start, OR a ruled test seam that injects the reference time. |
| FR-D6 | Charter rows C-13 and C-15 unwalked | C-13 (author a personal formula containing your allergen; FP-8 says Save stays ENABLED) needs the formula editor. C-15 (offline vs online twin parity, §8) needs an airplane-mode pass. | Walk both; C-15 is the one that can still surface an engine-level divergence. |
| FR-D8 | 10 macro-dashboard goldens fail LOCALLY | Every golden in `macro_dashboard_goldens_test.dart` fails at **0.00 % / 1-7 px** — uniform sub-pixel variance across the whole file, the signature of a font/renderer difference, not a regression (a real one hits a SUBSET at a meaningful percentage). Zero commits have touched `goldens/` since the landing merge. **Not regenerated on purpose: updating a golden is a ratification act, never a way to make a red test green.** | Confirm they pass on the M1 CI baseline. If they fail there too, THAT is a real finding. |
| FR-D9 | `ci_config_contract_test` asserts a superseded ruling | It requires Codemagic's `pr-validation` to run on **push** to develop. Lee moved it to PR-only on 2026-08-21 (`a4b34993`) to halve build minutes, explicitly reverting the 2026-07-21 run-on-every-push ruling. **The gate did not disappear — it moved**: `.github/workflows/tests-selfhosted.yml` runs `on: push` with unit + widget tests, analyze, Deno algorithm tests and Patrol. So a develop push IS gated, on the M1 runner. The test still encodes the old ruling and was never updated. | A ruling: confirm the 2026-07-21 every-push ruling is superseded by Lee's 2026-08-21 decision, then point the contract test at the M1 workflow. **Not fixed here — rewriting a contract test to match observed config is exactly what governance forbids.** |
| FR-D10 | 2 `manual_live` API tests fail locally | `final_surge_api_test` / `training_peaks_api_test` fail in `setUpAll` with "TOKEN NOT FOUND" — they are credential-gated live-API probes, expected to fail on a machine without those tokens. | Nothing; by design. Listed so the 13-failure count is fully accounted for. |
| FR-D7 | `avery@test.com` carries an `{gluten}` allergy set by QA | Set 2026-09-04 to make charter rows C-10..C-13 walkable; could not be reverted (`sim-dev-login.sh` holds only `ravi@test.com`). **Xuan ruled 2026-09-04: it can stay.** | Nothing — accepted. Recorded so nobody reads it as real athlete data. |

## Standing trap — `patrol test` dirties the app working tree

Every `patrol test` run (reproduced twice, 2026-09-04) leaves four files modified:

- `pubspec.lock` — **four transitive packages DOWNGRADED** (`meta` 1.18.0 → 1.17.0 and three
  others), because patrol re-resolves with its own constraints;
- both SwiftPM `Package.resolved` files — **deleted**;
- `ios/Runner.xcodeproj/project.pbxproj` — CocoaPods `[CP] Copy Pods Resources` phases re-added.

None of it belongs in a commit, and the first two make a CI build non-reproducible. **Always
`git checkout --` those four paths before committing or pushing:**

```
git checkout -- pubspec.lock ios/Runner.xcodeproj/project.pbxproj \
  ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
  ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

## Not deferred — verified working on dev 2026-09-04
So the next reader does not re-open settled ground: §3a class boundaries + Q-CF1 captions,
the early-start overlay (training only), the CF-2 clamp caption with an inert `+`, the 9:00/mi
pace fallback, capsule-scaled sodium with exactly 2 sources, mix↔water pairing, C3a divisible
"0.5 packets", composed meal tiers, `—` (not `0`) for a null sodium target, the full FP-4a →
Choose another → Pin anyway → FP-4b label → Unpin cycle, and the absence of any Fasted surface.

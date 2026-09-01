> **RESOLVED 2026-08-17 → Q-017 RULED (no-op accepted for v1, folded into baseline-macros.md; 10b exemption staged as contract change for the next bundle version)**

type: ruling-request
bundle: daily-macros-dashboard@v1

## Why this matters
Carb cycling (F20) is an athlete-facing opt-in whose effect no longer reaches the returned plan — the setting exists, the intermediate math changes, and the athlete sees identical numbers either way.

## The finding (surfaced migrating the legacy engine tests to the ruled specs)
On any day where cycling qualifies (single easy session: IF ≤ 0.80, ≤ 75 min), the raw fat residual sits above the 30 %E cap, so assembly step 10b (Q-014) redistributes the excess to carbohydrate. Because TDEE is independent of carbs when fat is above its floor (closed form (RMR+NEAT+session)/0.9), the post-cap carb figure converges to (TDEE − prot×4 − fatcap×9)/4 — the SAME value with or without the 3.0 g/kg cycled baseline. Verified numerically: the reference athlete's easy day lands at 428 g carb both ways. Opt-in survives only in unobservable intermediates.

## The question
Is this accepted (cycling becomes a no-op in the returned plan under the cap, keep the setting for future use), or does train-low need to survive the cap — e.g. by exempting qualifying cycled days from 10b redistribution (fat absorbs the day instead), or by retiring/hiding the opt-in until a mechanism exists?

## Interactions to weigh
- Q-014's rationale routes surplus energy to carbohydrate *specifically*; a train-low day wants the opposite.
- The published F20 gates and worked examples (baseline 225 g) remain true pre-cap; only the end-of-pipeline observability is lost.

## Gates
Nothing app-side is red — the vectors as ratified pass. This affects whether the opt-in UI keeps promising something the engine no longer delivers.

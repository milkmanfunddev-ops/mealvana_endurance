> **RESOLVED 2026-09-03 → option 1 + capsule-over-salt; folded to food-recommendation.md §4; scopes the twin port (ops bug)**

type: ruling-request
bundle: (food-recommendation ratification; during-workout sodium delivery)

## Why this matters
Sodium delivery picks read as absurd to athletes (pickle juice / 1000mg mega-mix over "just add another capsule") and the server refuses capsule counts the athlete would happily take — the observed "sodium failures" trace here.

## The question
What should sodium-source selection optimize? Specifically: (a) is overshoot-below-ceiling really free while undershoot-of-target is penalized (this is what makes one 940mg pickle shot / 1000mg mix beat 4×190mg capsules structurally); (b) what is the intended cap on dry-supplement servings (code says 4, catalog says 8–12, the Dart client already removed the cap as a bug fix); (c) should form/portability preference exist (capsules & tablets are carryable; 10 cups of sports drink and pickle-juice shots are not); (d) max electrolyte items per phase (today: 2).

## Evidence (F-17, F-18, F-22, F-35, F-37 — probe register)
- Scoring arithmetic: `_shared/nutrition/during-utils.ts` `pickBestElectrolyte` — sub-ceiling overshoot penalty 0, undershoot penalized vs target, dry supplements +0.05/serving beyond 2, hard `MAX_SUPPLEMENT_SERVINGS=4`.
- Sim 4h run (target 2628mg): fill chose 1 stick High-Sodium Electrolyte Mix (1000mg, one shot) + 2 capsules (`27.png`) — the big-hit item wins exactly as the arithmetic predicts; pickle juice (940mg, sodium_top_up_eligible=true) is the same class.
- Twin divergence: the Dart client REMOVED the 4-cap as bug 3abe3fdb ("stopped the top-up below the range floor even when more capsules were allowed"); the server still enforces it — see ops bug `../ops/data/bug-reports/2026-08-31-server-electrolyte-pick-diverges-from-dart-fix.md`.

## Options
(a) keep target-seeking but penalize overshoot symmetrically above target (not just above ceiling); (b) rule the cap (one number, both engines, catalog `max_servings_during` as the bound); (c) add a form-preference term (athlete-carryable first) or a user setting; (d) keep 2-source max or make it target-dependent. Any combination is a policy call — none is derivable from the current SSOTs (sodium v3 rules the TARGET, not the delivery).

## Gates
The server-side cap fix's SCOPE (ops bug above); S5/S6 close-out; differential vectors for the electrolyte pick.

## Suggested spec home
`spec/fueling/during-workout-sodium.md` — new "delivery/selection contract" section (the food-selector contract pattern used by pre-workout-sodium v3).

> **Producer note 2026-09-03 (dossier thread dc350050):** Xuan flags the backfill's salt habit —
> "Have a salt packet" appears often, but salt packets are not a common endurance choice;
> capsules/tablets are. Requested change (fold into this ruling): the sodium ESSENTIAL used by
> backfill/top-up paths prefers electrolyte capsule/tablet over salt; salt becomes last resort.
> Mechanically trivial — essentials are catalog-flagged; this is a preference order on that set,
> and it is the same form-preference knob as option (c) of this file.

## RULING (Xuan, 2026-09-03, RULING-DESK block — option 1)
(a) Symmetric target-seeking: overshoot above the TARGET is penalized, not only above the ceiling.
(b) The dry-supplement serving cap = the catalog row's `max_servings_during` — ONE number, BOTH
engines (retires the server-only `MAX_SUPPLEMENT_SERVINGS=4`; scopes the F-22/46/47 twin port).
(c) Carryable-first form preference (capsule/tablet/gel before liquid/mix volume).
(d) Max 2 electrolyte sources per fill (unchanged).
(+) Per the 2026-09-03 thread note: the sodium ESSENTIAL used by backfill/top-up prefers
electrolyte capsule/tablet; salt packet is last resort.
Xuan's attached question (answered in-session): plans undershoot because the server caps
supplements at 4 servings (the Dart twin removed that cap as a bug fix) and the two-source limit
+ zero-overshoot asymmetry leave no rescue — exactly what (a)+(b) fix.

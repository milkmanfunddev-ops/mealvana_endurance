> **RESOLVED 2026-08-17 → vector regenerated via the spec-to-vectors oracle (energy-availability.json, override-ceiling-branch: session 2770, expects carb 900 / fat 70 / EA 30.0)**

type: spec-erratum
bundle: daily-macros-dashboard@v1

## Why this matters
This is the ONE red in the engine's 168-vector conformance suite (app repo, 167/168 green). Governance forbids the code side touching it; until corrected here, the bundle's "all vector files green in CI" done_when cannot close.

## Artifact + location
`vectors/daily-macros/energy-availability.json`, vector id `override-ceiling-branch`.

## Why it is wrong (the arithmetic)
Inputs: carb 890 g, prot 115 g, fat 60 g, session 900 kcal, ffm 64 kg.
Intake = 890×4 + 115×4 + 60×9 = 3560 + 460 + 540 = **4560 kcal**.
EA = (4560 − 900) / 64 = **57.19** — far above 30, so F18 returns `adjusted: false` on any correct implementation. Yet the vector expects `adjusted: true` (and, contradictorily, carb/fat UNCHANGED at 890/60 plus `carbAtCeiling: false` while its `why` says "carb caps at 12 g/kg = 900; overflow kcal reroute to fat").

## Smallest correction
Regenerate the vector with inputs that actually land in the HARD_WARNING band (20 ≤ EA < 30) with carb near enough the 900 g ceiling that the 60 % carb share overflows — e.g. large session kcal against high carbs — and expecteds that exercise the Q-006 branch: carb pinned at 900, overflow kcal rerouted to fat, post-override EA exactly 30.0. (The app-side runner already asserts the post-override EA when an `ea` expected is present.)

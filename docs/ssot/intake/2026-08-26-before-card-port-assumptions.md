type: ruling-request
bundle: pre-workout-macros@v2
raised-by: app coding agent, 2026-08-26 (feature/pre-workout-before-card port loop)

## Why this matters

Three small gaps the handoff and the deferred ledger (P1–P12) do not answer surfaced during the
port. Each shipped with a stated assumption (red-means-raise); none blocks. Recorded here so the
next ruling round can confirm or overturn them without re-deriving the reasoning.

## Q1 — the SNACK card's fluid figure after a DARK / NOT_YET answer

**Gap.** `feeding-card.md` FC-2: "A fluid tier still shows its fluid oz ('16oz · fluids')". After
a dark answer the engine's `fluidTiers[snack].fluidMl` becomes `TOPUP_ML_KG·BW` (252 ml at 63 kg),
so the snack IS a fluid tier and the card shows "9oz · fluids" in its header. The reference
rendering hides the snack fluid figure in every state (its scenario table hard-codes `fluid: 0` for
the snack and never re-reads the tier after the answer).

**Assumption shipped:** the header figure is the engine's per-tier fluid (`fluidTiers[].fluidMl`
→ R-01 oz), so the snack shows "9oz" once the top-up lands there — the traceability reading of
FC-2 / B-5 (`check_dark`, `check_not_yet_covered` goldens).

**Options:** (a) keep (engine tier is the figure) · (b) hide the fluid figure on the SNACK card
unconditionally, matching the rendering pixel-for-pixel.

**Suggested home:** FC-2, one sentence.

## Q2 — the illustrative "25 oz" vs the interpolated 24 oz at 63 kg

**Gap.** `hydration-check.md` state table and copy register say "target raised to **25 oz**" for the
63-kg mock and note the figure is illustrative — "real copy interpolates `round(fluidMl / 29.5735)`".
The engine at 63 kg gives 472.5 + 252 = 724.5 ml → 24.498 → **24 oz** (the rendering got 25 by
rounding in oz: 16 + round(8.52) = 25). `h2_answer_writes_target` in the gestures manifest says
"(63 kg: 16 -> 25 oz)".

**Assumption shipped:** the interpolated value (24 oz) is the contract; the test asserts
`flOzTarget(724.5) == 24` and the copy reads "target raised to 24 oz". R-01 rounds ml once, at the
end — never oz-then-add.

**Options:** (a) confirm (edit the manifest line to "16 -> 24 oz" or "16 -> round(724.5/29.5735)")
· (b) rule that the top-up is rounded to oz separately and added (rendering behaviour) — would
contradict R-01's single rounding step.

**Suggested home:** the `h2_answer_writes_target` assert line; hydration-check.md's "(rounds
16 → 25 oz)" parenthetical.

## Q3 — the TOP_OFF window label at t = 0 vs 0 < t < 30

**Gap.** `feeding-card.md` gives the TOP_OFF window label as "LAST 30 MIN" (or "NOW UNTIL THE
START" / "NOW") without saying which lead time selects "NOW". The rendering's "At the start line"
scenario uses `min: 2` (off the 15-minute grid).

**Assumption shipped:** "NOW" iff `timeBeforeWorkoutMin == 0`; "NOW UNTIL THE START" for
0 < t < 30 when the top-off is the first extant feeding; "LAST 30 MIN" otherwise.

**Suggested home:** the "Tier × title × window label" table, TOP_OFF row.

type: ruling-request
bundle: pre-workout-macros@v2
raised-by: app coding agent, 2026-08-26 (feature/pre-workout-before-card port loop)

## Why this matters

The reference rendering (`spec/design/renderings/pre-workout@v2.html`) sets food names, the
hydration-check title and its question in **Compadre 15 px, mixed case** ("Oatmeal with banana",
"Water (cups)", "Is your urine pale yellow right now?"). The app repo ships only
`assets/fonts/Compadre/Compadre-Demo-*.otf` — a demo cut whose lowercase codepoints carry
full-cap outlines with very wide advances, and which has **no `(` / `)` glyphs**. Rendered with
that file the side-by-side cannot be made to match: "Oatmeal with banana" comes out as spaced
capitals and "Water (cups)" shows tofu boxes. The port prompt's "exact fonts" is therefore
unsatisfiable from the app's font registry, and the discrepancy list cannot reach empty on those
three slots by any code change.

## The question

Which of these is the ratified rendering for the Compadre slots on the BEFORE card until a licensed
Compadre is added to the app?

- **(a) Sansita 700 at the rendering's size/colour/line-height** — the substitution the retired
  `before_phase_widget.dart` already made for the same reason ("Use the app-bar Sansita instead"),
  and what the branch ships now (**interim assumption**).
- **(b) Apercu 500** — the body face, closer in x-height to Compadre's lowercase but visibly lighter
  than the display face.
- **(c) Ship the demo Compadre as-is** (the macro-dashboard cards do: "RUN" for "Run") and accept
  caps + tofu on the BEFORE card. Not recommended — the tofu boxes are a visible defect.
- **(d) License the full Compadre** and re-bless the affected goldens (feeding_meal_expanded,
  check_todo, check_expanded, check_pale, check_dark, check_not_yet_covered, check_not_sure,
  feeding_topoff_zero_carb, feeding_snack_light_meal, before_* with expanded rows).

Recommendation: (a) now, (d) when the font lands — (d) is a spec-neutral re-bless (the spec already
says Compadre), so no spec change is needed, only the regeneration commit citing this ruling.

## What it gates

Nothing blocks; the branch ships (a). The goldens named above are blessed under (a) and must be
regenerated once (d) happens. The macro-dashboard surfaces (`meal_card.dart`, `workout_card.dart`,
`breakdown_pager.dart`) carry the same demo cut and are not touched by this request.

## Suggested spec home

A one-line "Font availability" note on `spec/design/tokens.md` (or `source-authority.md` §3) stating
the substitution rule for slots whose face is not licensed in the app, so future ports do not
re-ask.

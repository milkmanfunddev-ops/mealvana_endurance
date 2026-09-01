# QA intake — ruling requests & spec errata

The drop folder for the **QA half** of the app repo's `intake-handoff` skill.
The ops repo receives product-lifecycle items (bugs, feature requests) for
Notion filing; **this folder receives contract-lifecycle items** — things whose
resolution is a commit to this repo: a ruling, a spec addition, a vector fix,
a doc correction.

Consumer: whoever works the spec next (Xuan, or a QA-side agent) processes
these when cutting rulings — typically by promoting each file into the
register (`spec/daily-macros/OPEN-QUESTIONS.md` or the relevant spec family's
register), ruling on it, folding the ruling into the spec as a
post-ratification addition (the `intraday-display.md` §4b pattern), and
regenerating any affected vectors. Processed files get a one-line stamp
prepended: `> **RESOLVED <date> → <commit/ruling ref>**` (or
`> **DECLINED <date> — <why>**`). Producers must never strip that stamp.

## File format

One atomic item per file, named `YYYY-MM-DD-<short-slug>.md`, starting with a
header block:

- `type:` one of:
  - `ruling-request` — a call only the spec owner can make: a gap, a
    contradiction, or a policy choice. Carries: **the question**, the options
    with trade-offs, a recommendation (optional), what app-side work it
    gates, and the suggested spec home for the ruling.
  - `spec-erratum` — a factual defect in an already-ratified artifact (a
    vector whose inputs can't produce its expecteds, a stale prose claim, a
    broken cross-reference). Carries: **the artifact + exact location**, what
    it says, why that is wrong (show the arithmetic/evidence), and the
    smallest correction. An erratum never proposes new policy — if fixing it
    requires a judgment call, it's a `ruling-request`.
- `bundle:` the bundle it concerns (e.g. `daily-macros-dashboard@v1`), blank
  if cross-cutting.
- `## Why this matters` — one line: what stays broken/blocked until resolved.

Guardrails (mirror of the producer skill's):
- Producers write **only into this folder** — never edit ratified specs,
  vectors, or bundles directly, and never self-ratify. Red-means-raise:
  a red conformance test is either wrong code (fix app-side) or one of these
  files (raise here) — never a vector edit.
- Cross-reference siblings (including ops-side files, by repo-relative path)
  instead of restating them. An app bug whose *fix scope* awaits a ruling
  lives in ops; only the ruling request lives here.
- Leave unknowns blank; don't fabricate to fill a field.

# Design SSOT — Tokens

**Status: RATIFIED v1 (Xuan, 2026-08-14).**
**Scope:** the named palette and its **meaning contracts** — global to every component and surface
in `spec/design/`. Single source: the prototype's CSS custom properties. Code and specs reference
tokens, never raw values; a value lives in exactly one place — this table.
*(This table is the one deliberate exception to the screenshot test: raw values appear here —
and only here — because goldens render "at token-resolved colors" and code must resolve the same
registry. Everywhere else, values are screenshot-held.)*

| Token | Value | Meaning contract |
|---|---|---|
| `--me-blackberry` | rgb(56, 22, 51) | Ground; card fills derive from it |
| `--me-cream` | rgb(248, 246, 235) | Primary text |
| `--me-electrolyte` | rgb(28, 249, 207) | **Burn / activity side** (RULED Xuan, 2026-08-14 — widened from verified-only): burn-side figures, workout accents, verified chips and the done-swipe fill. May not signify anything outside the burn/verified domain — never intake, never planning |
| `--me-orange` | rgb(247, 139, 20) | Energy & intake accent; planned-workout accent |
| `--me-dragonfruit` | rgb(220, 37, 151) | **Destructive.** May not signify anything else |

**The contract is the meaning column.** A component using `electrolyte` for a non-verified element,
or `dragonfruit` for a non-destructive one, fails conformance even if it "looks right."

**Q-D2 — RULED (Xuan, 2026-08-14): the current `dragonfruit` delete treatment is the contract
as-is.** Weight accepted at reference-rendering saturation and size; open to future iteration but
not a defect. (Register finding W-9 closes with this.) *v2 note (2026-08-17, Q-D6): delete is
deferred and skip replaces it — the workout card carries **no** `dragonfruit` element in v2; the
Q-D2 treatment returns with the delete bundle.*

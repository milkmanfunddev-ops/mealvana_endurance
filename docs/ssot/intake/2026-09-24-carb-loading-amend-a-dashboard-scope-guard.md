> **RESOLVED 2026-09-24 → ruling interview (Xuan); folded as macro-dashboard.md S-5 dated amendment (option 1)**
type: ruling-request
bundle: carb-loading (release-1, pre-ship)

# Amendment (a) — macro-dashboard S-5 scope guard vs the LOAD face

## The question
`spec/design/surfaces/macro-dashboard.md` S-5 (ratified) reads: "no phase indicator, no safety
states, no sodium on this surface — deferred, not forgotten." The carb-loading LOAD face IS a
fuelling-phase indicator on this surface. Amend S-5 to admit the fuelling-phase face, or the
release-1 design set contradicts a ratified scope guard on day one.

## Options
1. **Amend S-5** to: no phase indicator *except the carb-loading LOAD face* (which replaces the
   All-lens energy-card face on loading days, per the 2026-09-19 ruling); safety states and sodium
   stay deferred. — Recommended: matches what Xuan already ruled 2026-09-19; S-5 predates that
   ruling and was never reconciled.
2. Leave S-5 and carve the exception in the energy-card contract only. — Weaker: the surface spec
   would still forbid what its own card renders.

## Gates
App-side implementation of the LOAD face; the ratified composition (package §3).

## Suggested home
`spec/design/surfaces/macro-dashboard.md` S-5, dated post-ratification amendment per
`spec/design/source-authority.md` §3.3. Ratifier: Xuan.

# spec/integrations/ — third-party data-lifecycle SSOTs

**Status: RATIFIED (Xuan, 2026-09-10, ruling desk).** Drafted 2026-09-08/09 from `app@c4abec2a`; `[observed]` clauses ratified; `[divergence]`/`[gap]` clauses carry the 2026-09-10 Q-INT rulings or remain OPEN per [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). Ratification request:
`intake/2026-09-08-data-integration-lifecycle-family.md`, which subsumes the still-unstamped
`intake/2026-08-22-data-ssot-producer-shapes.md` (PLAN.md Phase 5).

The fourth truth family. `spec/<engine>/` ratifies math (given inputs → output);
`spec/design/` ratifies rendering; `spec/domain/` ratifies what a thing *is*. This family
ratifies the **data lifecycle of third-party training platforms** — for each provider, the
four verbs Xuan named:

| Verb | What the contract states |
|---|---|
| **Extracted** | Auth model, direction (push/pull), endpoints, windows, cadence, triggers |
| **Stored** | Which tables/columns each writer produces, the deliberate NULLs, raw-payload custody, token custody |
| **Used** | Which consumers read the rows and what each derives — by *reference* to the ratified math specs, never re-owning them |
| **Discarded** | What is dropped at ingest, dedup/overwrite-on-resync, tombstones, disconnect purge, account deletion, retention windows |

## Sections
- [`lifecycle.md`](lifecycle.md) — the cross-provider contract: identity keys, resync merge
  ownership, tombstones, disconnect, account deletion, retention. Rules stated once here;
  provider docs cite them.
- [`garmin.md`](garmin.md) — push model, wellness data, `garmin_health_data`, dual token store.
- [`final-surge.md`](final-surge.md) — pull model, the deliberate `duration_minutes = NULL`
  producer contract.
- [`training-peaks.md`](training-peaks.md) — pull model, identity source, the only write-back.
- [`matching.md`](matching.md) — the matching & completion contract: every gate, the
  plausibility guard, and the brick Garmin-verification proposal (B-1..B-5).
- [`performance-data.md`](performance-data.md) — sports-performance inventory: thresholds,
  zones, FTP/LTHR/CSS, VO2max, IF/TSS/CTL, and the storage-adequacy audit.
- [`payload-usage-map.md`](payload-usage-map.md) — the field manual: every payload field per
  provider → disposition (captured / stored-dead / bucketed / discarded / unhandled /
  not-fetched) → potential usage; §6 is the capture shortlist (Q-INT26).
- [`field-map.md`](field-map.md) — the per-field matrix: every provider data point → the
  table.column it lands in (or is discarded from) → its consumer. Includes the CTL/ATL
  never-fed gap and Garmin history-depth facts.
- [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md) — the INT-### register. Every contested clause
  points here; nothing in this family is self-ratified.

Runna and VDOT O2 exist in the app (`integrations.provider` CHECK) but are deferred to a
follow-on pass — named in each doc's exclusions, not silently omitted.

## Boundaries with existing ratified specs (no double ownership)
- **`spec/daily-macros/platform-resolution.md` (RATIFIED v2) keeps F22–F27** — the per-variable
  resolution ladders and source tags. This family owns the layer *below* it (what shapes the
  rows arrive in) and *around* it (how rows appear, persist, and disappear). Where a provider
  doc mentions a resolved value, it cites F22; it never restates the ladder.
- **`spec/daily-macros/session-demand.md` keeps F3–F5** (what a session costs).
- **`spec/daily-macros/intraday-display.md` §4b keeps the tombstone ruling**; `lifecycle.md`
  L-4 extends it to the provider-side delete signal, which §4b does not cover.
- Two unstamped intake items pre-registered this family as their intended home and are folded
  into the register as Q-INT rows rather than re-argued:
  `intake/2026-08-18-platform-declared-skip-semantics.md`,
  `intake/2026-08-18-skipped-row-sync-match-window.md`.

## Evidence base and its limits
Drafted from three surveys (2026-09-08): the app code at `app@c4abec2a`
(branch `feature/home-shell-v1` = `origin/develop`), the app's own manual
(`app/docs/integration/` — the code-verified `api-exploration/` stratum, 2026-07/08, is cited;
the Nov 2025–Mar 2026 design stratum is cited only as *claimed intent, unverified*), and
`app/docs/database/AUDIT_REPORT_2026-05-14.md`. Nothing here was verified against live
production traffic — the manual says the same of itself.

**Governance reminder (CLAUDE.md): implementation is not authorization.** Every clause below
is tagged with its provenance:
- `[observed]` — what the code does today, proposed as the contract because it appears to be
  deliberate (usually backed by an in-code rationale comment, cited).
- `[divergence]` — the code and a stated intent (a doc, a comment, or common sense about
  consent/custody) disagree; the clause states the *proposed* contract and the Q-INT row
  carries the decision.
- `[gap]` — nothing is implemented or written anywhere; the clause exists so the hole is
  ratified as either "deliberately none" or "to build", never left implicit.

Same lifecycle as every family: PROPOSED → RATIFIED by Xuan, dated RULED stamps for
post-ratification additions, `DEVIATIONS.md` for observed-but-unratified behaviour, vectors
via `spec-to-vectors` — first corpus landed 2026-09-10: `vectors/integrations/matching.json`
(39 gate-verdict vectors for the ruled matching contract) + 9 F4a rows appended to
`vectors/daily-macros/session-demand.json`; producer-shape payload vectors
(`<provider>.json`) follow with the capture-contract implementation. Conformance dispatched
by `conformance/run_dart.sh` as a new arm, contract tests living app-side as the
producer→consumer tier.

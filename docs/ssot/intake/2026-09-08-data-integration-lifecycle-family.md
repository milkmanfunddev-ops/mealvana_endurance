> **RESOLVED 2026-09-10 → family RATIFIED as spec/integrations/ (option 1; ruling desk 2026-09-10); Q-INT0 RULED; divergence/gap clauses remain OPEN under their Q-rows**
type: ruling-request
bundle: data-integrations@v1 (proposed new bundle)

## Why this matters
Xuan asked (2026-09-08) to ratify how Garmin / Final Surge / TrainingPeaks data are
**stored, extracted, used, and discarded** for the next bundle. Nothing ratified covers
this today: `platform-resolution.md` (RATIFIED v2) owns the value ladders, but connection
lifecycle, row-shape producer contracts, token custody, disconnect purge, retention and
discard are specified nowhere — and the app's own manual (`app/docs/integration/`) claims
disconnect-deletion and opt-in write-back that the code does not implement.

## The question
Ratify `spec/integrations/` as the fourth truth family (data lifecycle), per the PROPOSED
drafts landed 2026-09-08:
`spec/integrations/{README,lifecycle,garmin,final-surge,training-peaks,field-map,OPEN-QUESTIONS}.md`,
drafted from a three-way survey (app code @ `c4abec2a`, the manual's code-verified
`api-exploration/` stratum, `docs/database/AUDIT_REPORT_2026-05-14.md`).

This request **subsumes** the still-unstamped
`intake/2026-08-22-data-ssot-producer-shapes.md` (PLAN.md Phase 5, "producers" family):
the producer row shapes are the "stored" verb of this family (FS-2, TP-2, G-2), and the
vectors corpus becomes `vectors/integrations/*.json` with the app-side producer→consumer
contract tier exactly as Phase 5 designed. Two further unstamped intake items
pre-registered this family as their home and are folded in as register rows:
`2026-08-18-skipped-row-sync-match-window.md` (Q-INT4),
`2026-08-18-platform-declared-skip-semantics.md` (Q-INT6).

## Options
1. **Ratify the family as drafted** (recommended): name `spec/integrations/`, scope =
   extract/store/use/discard for Garmin+FS+TP (Runna/VDOT deferred, named), then rule the
   Q-INT0…Q-INT18 register (tiering suggestion in `OPEN-QUESTIONS.md`).
2. **Ratify under the Phase 5 name** `spec/producers/`, lifecycle content folded in —
   same drafts, renamed; the 2026-08-22 intake is then resolved by its own option 1.
3. **Ladders-and-shapes only** (Phase 5 option 2): ratify FS-2/TP-2/G-2 row shapes now,
   defer lifecycle (auth/disconnect/retention) — leaves the consent/custody divergences
   (Q-INT1/Q2/Q3/Q16) unruled.

## Gates
- Ratifying the family does NOT self-ratify any clause: every `[divergence]`/`[gap]`
  clause stays OPEN until its Q-INT row is ruled; `[observed]` clauses ratify with the
  document unless Xuan strikes them.
- Vectors follow ratification via spec-to-vectors; the bundle ships EXPECTED-RED per the
  normal loop. Sequencing respects brick-transition shipping first.

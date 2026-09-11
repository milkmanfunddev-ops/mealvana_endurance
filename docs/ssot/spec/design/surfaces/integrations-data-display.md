# Design SSOT — Integrations data on the app surfaces (card numbers · performance settings · write-back consent)

**Status: RATIFIED (Xuan, 2026-09-11).** (Drafted 2026-09-10; workflow re-scoped same day
per Xuan's rule; all Q-DID rows ruled, nine provenance maps and three design handovers
ratified, three pattern-application frags ruled 2026-09-11.)
**Xuan's design rule of thumb (2026-09-10):** unchanged interfaces → QA ratifies ONLY the
number-provenance map (real screenshot, every number marked with its source — the review
artifact carries it). Interface changes → QA issues Claude Design prompts (P1 card
states, P2 provenance chips, P3 consent flow — on the review artifact); Xuan iterates in
Claude Design and hands the export back; QA then ratifies every number on the returned
design (design-spec-reconcile pass). D-1..D-3 below are therefore the DATA contracts the
prompts carry as constraints, NOT visual designs; visual truth arrives with the handover. The design slice of `data-integrations@v1`,
added at Xuan's direction (2026-09-10): the ratified data contracts of
`spec/integrations/` are rendered on three live surfaces, and without display contracts
the engine⇄screen seam is untested. Companion data truths: `lifecycle.md` L-2
(planned/actual split), `performance-data.md` P-1 (zones/FTP), `training-peaks.md` TP-5
(write-back). Conformance: ratified renderings archived at
`spec/design/renderings/workout-card-states@v1.html` · `ftp-source-provenance@v1.html` ·
`tp-writeback-consent@v1.html`; goldens/gestures manifests at
`conformance/design/{workout-card-states,ftp-source-provenance,tp-writeback-consent}.goldens.yaml`
(written at ship, 2026-09-11; app suites to follow implementation per DI-15). Sibling: `spec/design/components/workout-card.md` (RATIFIED — this doc
extends its data contract, it does not re-own the card's states/gestures).

## D-1 — Workout-card numbers: which value does each state show?

The card renders duration and distance. With the L-2 split both a planned and a measured
value exist. Contract per card state (extends workout-card.md's data contract):

| Card state | Duration & distance shown | Rationale |
|---|---|---|
| PLANNED | planned values | only values that exist |
| SKIPPED | planned values | the declined prescription |
| DONE_CONFIRMED (self-reported) | planned values | mark-done captures no measurements; showing planned as if measured is honest only with the existing "self-reported" chip |
| DONE_VERIFIED | **measured values** (`actual_*`) | provable fact primacy (M-1.3) extends to display: verified shows what happened |

**Q-DID1 — RULED (Xuan, 2026-09-11): option B — measured ONLY.** A verified card shows
only the verified duration/distance; the planned values are no longer visible on the
card (they remain in the row and any detail surface). One row of numbers per card,
always: planned before verification, measured after. Xuan's rationale: no reason to
show both, and brick cards are compact — multiple rows per leg would not fit. (Option A
— quiet planned-delta subtext at >10% divergence — was recommended and declined.)
**Design handover RATIFIED (QA-verified interactively, 2026-09-11):** the Claude Design
export implements the contract by construction — a single value-family pick per card
(`measured = verified` only) applied to the card AND each brick leg, so mixing is
impossible; verified shows `8.2 mi · 46 min` + the teal `✓ verified · Garmin` pill with
no planned row; skipped/self keep planned values; brick legs stay one row (`① 20.4 MI ·
63 MIN / ② 3.1 MI · 24 MIN`) with order badges. One cosmetic note left to Xuan: at brick
width the leg NAME truncates hard ("B…"/"R…") — the sport icon + order badge carry
identity; accept or ask Design for a narrower value type. The export's live state
readout ("Numbers on the card: Measured only (Garmin)…") restates the rule in-page.

Never permitted: mixing (measured duration with planned distance) — one state, one value
family, per row resolved `actual ?? planned` **as a pair**.

**D-1b — Brick border grammar — RULED (Xuan, 2026-09-11):** the brick card follows the
same border grammar as every workout card: dashed outline until completed
(planned/skipped), solid only on self-reported or verified completion. The ratified P1
export already draws it this way (dashed orange planned brick → solid teal-tinted on
done/verified); today's app draws a solid border at brick creation — an app-side
divergence to fix, not a design task (handback addendum 3).

## D-2 — Performance settings (FTP · swim CSS): provenance & conflict

Today the settings fields are manual-only while TP's synced values sit unread; after
Q-INT19 wiring, both sources exist per the per-source column convention. Contract:

1. Every performance value displays with a **source chip**: `Manual` · `TrainingPeaks`.
   **Amended (design-wins, Xuan, 2026-09-11):** the chip carries the SOURCE only — no
   relative sync time. Freshness surfaces only when it matters: a small `stale` chip
   appears past the 24 h zones-staleness window (clause 4). The earlier
   `synced <relative time>` draft is superseded.
2. TP prefills an empty field (chip = TrainingPeaks). Manual entry always permitted and
   **wins for calculation** once made (chip flips to manual; the ratified design adds a
   note that TP is kept as reference only).
3. **Q-DID2 — RULED (Xuan, 2026-09-11): variant A.** Manual stays authoritative; the
   conflict renders as two chips under the field — `Manual · 265 W` and
   `TrainingPeaks · 285 W — tap to use` — plus a `Sync Now` affordance. No modal, no
   nag; tap-to-adopt switches to the TP value. Variant B (active keep-or-adopt prompt)
   was dropped at Xuan's direction inside the Claude Design session — never designed,
   declined.
4. Stale indication: past the 24 h zones window a `stale` chip appears by the section
   title (the field may hold the older TP value) with `Sync Now` beside the source chip.
**Design handover RATIFIED (QA-verified interactively, 2026-09-11):** all four toggle
states exercised on the export (manual · TP-sourced · conflict-A · stale); manual-wins,
tap-to-adopt, and Sync Now behaviors verified; same pattern inherits to Swimming CSS.

**D-2b — Body Composition inherits the chip pattern — RULED (Xuan, 2026-09-11):** weight
and body-fat fields carry the ratified source-chip pattern with these parameters:
sources `Manual · Garmin`; `stale` chip past the **30-day** body-comp window; precedence
**newest-wins** (a measurement stream — a newer Garmin reading overwrites, with
attribution; a manual edit takes over until a newer reading lands), unlike FTP's
manual-wins (a declared parameter); conflict affordance only for the
older-Garmin/newer-manual case (`Garmin · <value> — tap to use`). No design session —
pattern application; goldens verify at implementation.

**D-2c — Events origin chip — RULED (Xuan, 2026-09-11):** event rows carry an origin
chip (`Manual · TrainingPeaks · Final Surge`); no stale or adopt affordances (one origin
per row, dated content). A dedupe-matched event (user+name+date) flips to the provider
origin. **A local edit to a provider-sourced field flips that field manual and exempts
it from re-sync overwrite** — the contract line the chip makes legible. No design
session — pattern application.

## D-3 — TP write-back consent (connect prompt · settings toggle · onboarding)

Renders the ruled Q-INT16 contract — **AMENDED to opt-out (Xuan, 2026-09-11): write-back
defaults ON for everyone; the sheet is an opt-out notice (dismiss = stays ON); the row
toggle pre-set ON is the opt-out; ledger-gating unchanged.** The clauses below record
the ratified opt-in design handover; where they say OFF-by-default they are superseded
by this amendment. **The opt-out iteration came back and is RATIFIED (Xuan's export,
QA-verified interactively, 2026-09-11)** — final copy set in D-3.1.

1. **Connect-time prompt** — fires once, immediately after a successful TP OAuth, both
   in onboarding and from Connected Apps; **its choice sets the row toggle's initial
   state** (Xuan, 2026-09-10) — the popup and the toggle are one preference, two
   surfaces. **Copy RATIFIED from the opt-out Claude Design iteration (Xuan, 2026-09-11
   — supersedes the same-day opt-in copy set):**
   - Title: `Your fuel plan goes to your coach` (statement, not question — opt-out
     framing).
   - Body: `Mealvana writes your plan to each TrainingPeaks workout so your coach can
     review it. You can turn it off here or in Settings.`
   - EXAMPLE preview block (ratified element — shows the athlete what the coach will
     see, stylized): `Fuel plan · Mealvana` / `60 g carbs/hr · 500 ml/hr · 400 mg
     sodium/hr` (units per the TP-5 register as amended 2026-09-11: ml/h).
   - Actions: `Keep Sharing` (primary, filled) · `Turn Off Sharing` (same-size outlined
     pill — one tap, equal visual weight) · dismiss X. Footer: `Closing this leaves
     sharing on.`
   - Verified interactively on the export: toggle pre-set ON in both surfaces; dismiss
     X leaves sharing ON; `Turn Off Sharing` flips the row toggle OFF.
   - **Layout constraint (QA, from the export review):** the sheet MUST size so `Turn
     Off Sharing` is fully visible without scrolling on the smallest supported screen —
     in the export's fixed artboards the opt-out button sat partially below the frame
     edge (a demo-height artifact, but a clipped opt-out would undo the equal-weight
     guarantee the opt-out posture depends on). Implementation asserts this in the
     gestures manifest.
2. **Settings toggle — placement refined (Xuan, 2026-09-10):** the toggle lives INSIDE
   the TrainingPeaks row card on Connected Apps (TP is the only write-back provider),
   below the identity/last-synced lines — following the existing per-row sublabel
   pattern (FS shows name + "Last synced: 1 hour ago"; Garmin carries an explainer
   paragraph under its card). Label `Write fuel plan to TrainingPeaks`. Visible in
   both places the surface appears: onboarding AND settings.
   **Sublabel STRUCK — RULED (Xuan, 2026-09-11, design ratification):** the earlier
   draft's last-push sublabel (`Last shared: yesterday's ride` / `Never shared`) is
   removed; the ratified design carries the bare toggle. The push LEDGER itself is
   unchanged — it remains required server-side per Q-INT16; it is simply not surfaced
   in this row.
3. **Onboarding accommodation** — when TP is connected during onboarding, the prompt
   appears as its own step AFTER the connection succeeds, never blocking the connect
   flow; skipping = stays ON (opt-out amendment, 2026-09-11 — the export shows the
   toggle live inside the onboarding TP row too).
4. **Premium-blocked state** — when the 403 latch is set, the toggle row shows
   `Unavailable for your TrainingPeaks plan` with a `Re-check` action
   (`refreshPremiumEligibility` exists). Never a silent dead toggle.
5. **Migration moment — RULED (Xuan, 2026-09-11):** ratified, in opt-out form: athletes
   already pushing via the `?? true` default see the notice ONCE on first launch after
   the update — informing them sharing is on, with the toggle as the opt-out. Dismiss =
   stays ON; nobody's coach feed stops silently (the Claudia's-client case is continuity
   by default now). **The SAME ratified sheet serves the migration moment** — its body
   copy is present-tense ("Mealvana writes your plan…"), which reads correctly for an
   athlete whose sharing is already underway; no separate variant is needed (supersedes
   the follow-up prompt's ask for one).

## Provenance maps — RATIFIED (Xuan, 2026-09-11, desk paste "provenance review")

The review artifact's nine number-provenance maps (real screenshots, every number marked
with its source) — ratified as marked, eight of nine:

| Map | Surface | Markers | Status |
|---|---|---|---|
| MAP1 | Timeline (home) | 1–4 | **RATIFIED** |
| MAP2 | Settings → Cycling Details | 5–7 | **RATIFIED** |
| MAP3 | Active Energy (today) | 8–12 | **RATIFIED** — incl. the filed mixed-pair bug and the two numbers that change when F22-BMR and F4a land |
| MAP4 | Active Energy (future day) | 13–15 | **RATIFIED** |
| MAP5 | Settings → Body Composition | 16–19 | **RATIFIED** — incl. Garmin overwrite-when-authoritative + attribution chip |
| MAP6 | Add-Activity | 20–23 | **RATIFIED** — incl. the flag: the "your usual" chip must not claim history on the hardcoded fallback |
| MAP7 | Plan editor (planned/skipped card tap) | 24–26 | **RATIFIED** — editor reads planner columns only, never `actual_*` |
| MAP8 | Events tab | 27–28 | **RATIFIED** (Xuan, 2026-09-11, follow-up to the paste) — current provenance as marked; the D-2c origin-chip proposal remains a separate open frag |
| MAP9 | Brick linking mode | 29–31 | **RATIFIED** — leg order = B-2′ segment order |

Applier note: the paste labeled these [Q-DID1]–[Q-DID9] (the artifact's copy-button ids),
which collide with this doc's Q-DID1–3 design calls ruled earlier the same day; applied
by content (each line names its map and markers), recorded here as MAP1–9. Artifact:
7161f58f. MAP8 ratified by follow-up same day. Still open: the three offered
pattern-application frags (D-2b body-comp chips · D-1b brick border grammar · D-2c
events origin chip).

## 1 · Open rulings

| Q | Question | Ruling |
|---|---|---|
| Q-DID1 | DONE_VERIFIED card: measured with planned-delta subtext (A) or measured only (B)? | **RULED** (Xuan, 2026-09-11): B — measured only, one row per card; planned invisible once verified (brick compactness). Design handover verified + ratified same day |
| Q-DID2 | FTP/CSS conflict: passive notice + tap-to-adopt (A) or active prompt (B)? | **RULED** (Xuan, 2026-09-11): A — B dropped at Xuan's direction in the Design session; chip = source only, stale chip past 24 h; handover verified + ratified |
| Q-DID3 | Consent copy & the migration-moment prompt: approve the drafts above (incl. §D-3.5 staged migration) or amend? | **RULED** (Xuan, 2026-09-11): opt-out copy set ratified from the second design export; migration = same sheet, once; sheet-visibility constraint recorded |
| D-1b | Brick card border grammar | **RULED** (Xuan, 2026-09-11): dashed until complete, same as all cards; app's solid-on-create is a divergence to fix |
| D-2b | Body Composition source chips | **RULED** (Xuan, 2026-09-11): Manual·Garmin, 30-day stale, newest-wins, tap-to-use for older-Garmin/newer-manual |
| D-2c | Events origin chip | **RULED** (Xuan, 2026-09-11): Manual·TP·FS origin only; edit flips field manual + exempts from re-sync overwrite |

## Explicitly NOT owned here
Card states/gestures (workout-card.md, RATIFIED); the data ladders (F22); the write-back
block format (training-peaks.md TP-5, RULED); visual tokens (tokens.md).

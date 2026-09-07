# Design SSOT — Component: Workout Card

**Status: RATIFIED v3 (Xuan, 2026-08-18 — Q-D7: mark-done writes `actual_time = planned_time`,
never `now`; mark-done is not offered on a future day; ruled and the written text ratified the
same day). Ships as `daily-macros-dashboard@v3` — a contract change, not a v2.x point tag. v2
(RATIFIED Xuan, 2026-08-17 — Q-D6 unified-skip model) remains the content
`daily-macros-dashboard@v2` points at; v1 (RATIFIED Xuan, 2026-08-14) is `@v1`.**
**Component contract** — owns this card's states, gestures and data binding wherever the card
appears. Composition into a screen (and cross-component side-effects) belongs to the surface spec
that uses it, e.g. [`../surfaces/macro-dashboard.md`](../surfaces/macro-dashboard.md).
**Tokens:** [`../tokens.md`](../tokens.md). **Reference rendering:**
[`../renderings/macro-dashboard@v1.html`](../renderings/macro-dashboard@v1.html) (ratified Xuan
2026-08-25; frozen copy of `prototypes/macro-dashboard/index.html` @ `5a22ca8`, 2026-08-17) — the
rendering illustrates, this file governs. Reconciliation of that rendering against this text:
[`docs/design-reconciliation/macro-dashboard-2026-08-17-skip-revision.md`](../../../docs/design-reconciliation/macro-dashboard-2026-08-17-skip-revision.md).

## Changes from v2 (the contract change that makes this v3, not v2.1)

**Q-D7 — RULED (Xuan, 2026-08-18): what mark-done writes for `actual_time`, and whether it is
offered, when the card's day is not the current day — and, deliberately, on the current day too.**
Raised via [`intake/2026-08-18-mark-done-on-non-current-day.md`](../../../intake/2026-08-18-mark-done-on-non-current-day.md)
(found on-sim 2026-08-18: under the v2 rule, marking tomorrow's or yesterday's workout done
relocated it onto today's timeline — and, on the past-day case, into today's `workout_so_far`).
Class (c) by the register's own test: a ratified vector expected (`two-time-mark-done`), a
manifest assertion (`g1`) and a published worked consequence (`platform-resolution.md` 5:30 → 3:00)
all change — hence v3, never foldable into v2.

- **G1 writes `actual_time = planned_time` — never `now`. Reverses W-7 (2026-08-14).** The
  confirmation means *"it happened as planned"*; it is not a timestamp of the confirmation, so a
  swipe made hours after (or before) the session does not relocate the card. Holds on a past day
  (the common case: yesterday's session that never synced, confirmed as planned) **and on the
  current day**. A later platform sync still overwrites with the measured start (`MANUAL → GARMIN`)
  exactly as before.
- **Mark-done is not offered on a future day.** Tomorrow hasn't happened; an athlete who does
  tomorrow's session today creates today's workout and skips tomorrow's. On a future-day card the
  right-swipe takes the G3 treatment (token nudge, no reveal, no write); Skip/Unskip (G4/G5) remain
  available, and mark-undone (G2) remains available on a (legacy) confirmed future card so it can be
  corrected.
- **Q-D6 recovery inherits the write:** G1 on a `SKIPPED` card writes `actual_time = planned_time`
  — the card stays on its day, back at its slot.
- **Visible consequence:** a confirmed card no longer slides to "now"; it stays at its planned slot
  with the `self-reported` chip. `workout_so_far` (`spec/daily-macros/intraday-display.md` §1) keys
  off `actual_time` *presence*, not clock position, so a session marked done before its planned time
  still counts in full — unchanged.
- Engine-side twin of this change: `spec/daily-macros/platform-resolution.md` two-time model (v2,
  ratified 2026-08-18). Everything else in this file is byte-identical to v2.

## Changes from v1 (the contract change that made v2, not v1.1)

- **Skip replaces delete.** G4/G5 were *Delete* (reveal + press, `dragonfruit`); in v2 the left
  swipe reveals **Skip / Unskip** — neutral, never destructive. Delete is **deferred to a future
  bundle** (not repealed; duplicates are handled when user concerns arise). No delete affordance
  renders anywhere on the card in v2. The soft-delete tombstone (`status = 'deleted'`) stays in the
  data model as landed groundwork — nothing writes it from this card in v2.
- **`SKIPPED` gains an active trigger** (left-swipe Skip, allowed on the current day). The v1 Q-D5
  "past-day only" line survives as the **passive** trigger only.
- **Sync beats skip.** A skipped workout — actively or passively — that later syncs becomes
  `DONE_VERIFIED`; the Garmin fact is not contradictable.
- **A skipped card loses its timeline position** (no timestamp; tucked after every timed card);
  unskip restores `planned_time` and position. Position is the surface's business (S-7).
- **A verified card takes no gesture at all** — G3 now covers both swipe directions.
- Visual clarification (D-2, 2026-08-17): the `SKIPPED` signature is the planned treatment
  **drained to neutral** — no energy colour anywhere on the card.

## States — state × visual × chip

| State | Visual contract | Chip |
|---|---|---|
| `PLANNED` | Dashed outline, dimmed fill, no solid border, energy-colour (`electrolyte`) accents | `Planned` |
| `DONE_CONFIRMED` | Solid fill, solid border — **no awaiting-sync glyph (Q-D4)** | `self-reported` |
| `DONE_VERIFIED` | Solid fill, solid border, icon disc in `electrolyte` | `✓ verified · Garmin` |
| `SKIPPED` | Planned treatment **drained to neutral**: dotted outline, dimmed fill, icon/chip/kcal in dimmed `cream` — no `electrolyte`, no `orange` anywhere on the card | `Skipped` |

Exactly one state at a time; every state reachable in the reference rendering (`SKIPPED` passively
via the previous-day view, actively via left-swipe Skip on today's planned run).

**How a card enters `SKIPPED` — Q-D6 (RULED, Xuan, 2026-08-17):**
- **Passive:** the workout's day is past and it has neither a sync nor a confirmation
  (`actual_time` null, `status` not `skipped`) — the Q-D5 trigger, unchanged. **The current day
  never shows a *passive* `SKIPPED`**; an untouched unresolved workout stays `PLANNED` all day.
- **Active:** the athlete presses the revealed **Skip** (G4/G5) — **allowed on the current day**
  and on any planned/confirmed non-verified card. Writes `status = 'skipped'`.
- **Sync beats skip (G6):** a platform sync matching a `SKIPPED` workout — passive or active —
  upgrades it to `DONE_VERIFIED`; fuel re-enters; nothing the athlete did stands against a
  measured fact.
- **Fuel:** a `SKIPPED` workout's calories and fuel are **not counted** in the day's plan (Q-D5,
  unchanged) — engine authority `spec/daily-macros/platform-resolution.md` (confirmation rung; the
  `SKIPPED` addition of 2026-08-17).
- **Right-swipe recovery (G1):** full right-swipe on `SKIPPED` → `DONE_CONFIRMED`,
  `actual_time = planned_time` (Q-D7 — the card stays on its day, back at its slot), fuel counts
  again; right-swipe again (G2) returns the card to *the unresolved state for its day* —
  `PLANNED` on the current day, `SKIPPED` on a past day (state is derived; see W-10).

**Q-D4 — RULED (Xuan, 2026-08-17): there is no awaiting-sync glyph.** A self-reported card looks
exactly as the `DONE_CONFIRMED` row states, indefinitely — the `self-reported` chip IS the
never-synced signal. A later sync flips the card to `DONE_VERIFIED` by the backend MANUAL → GARMIN
upgrade; the reference rendering's `awaitingSync` flag is dead and stays dead. Raised via
`intake/2026-08-17-awaiting-sync-glyph-conflict.md`.

**Q-D5 — RULED (Xuan, 2026-08-17): the `SKIPPED` state (v1 form).** Trigger past-day only;
planned treatment + `Skipped` chip; the provisional "Did this happen? Swipe right to mark done"
prompt copy and the same-day-22:00 trigger are rejected; fuel not counted. Superseded in v2 only
where Q-D6 says so (active trigger added, delete replaced by skip, neutral drain named). Raised via
`intake/2026-08-17-skipped-prompt-copy-unspecified.md`.

*The visual column names each state's **distinguishing signature** only — full appearance is
screenshot-held (port loop) and golden-held (conformance); do not grow this column into a frame
description.*

## Gesture contracts

| # | Gesture | On state | Contract |
|---|---|---|---|
| G1 | Swipe right (full) | `PLANNED`, `SKIPPED` — **current or past day only** | → `DONE_CONFIRMED`. **`actual_time` = `planned_time`** (Q-D7 ruling, 2026-08-18 — reverses W-7's `= now`: the confirmation says *it happened as planned*, it is not a timestamp of the swipe); `planned_time` never modified; if the card was `SKIPPED`, `status` returns from `skipped` to planned; the card **keeps its planned slot** on any time-ordered surface (a past-day card stays on its day — nothing lands on today) and its fuel re-enters every figure. **Future day: not offered** — the right-swipe takes the G3 treatment (token nudge, no reveal, no write, no state change); G4/G5 and G2 on that card are unaffected |
| G2 | Swipe right (full) | `DONE_CONFIRMED` | → the unresolved state for the card's day: `PLANNED` (current/future day — a confirmed *future* card can only be legacy, since G1 is not offered there; G2 stays available so it can be corrected, Q-D7) or `SKIPPED` (past day). **`actual_time` cleared**; card returns to `planned_time` — or, on a past day, to the tucked skipped position (S-7) |
| G3 | Any swipe (either direction) | `DONE_VERIFIED` | **Suppressed entirely** (Q-D1 RULED 2026-08-14, widened to both directions in v2): no reveal renders, no translation past a token nudge, no Skip/Unskip affordance — a verified card simply does not respond to gestures. Garmin fact is not contradictable, and no dead affordance is shown. *v3 (Q-D7): the same treatment applies to the **right**-swipe on any future-day card, whatever its state — see G1; the left-swipe there still reveals per G4* |
| G4 | Swipe left (partial reveal) | any non-verified | Reveals a **labeled** button: `Skip` on `PLANNED`/`DONE_CONFIRMED`, `Unskip` on an actively-skipped `SKIPPED` card. Neutral treatment (dimmed `cream` on a translucent field) — **never `dragonfruit`**: skipping is not destructive and the token contract forbids it. Skip/unskip only on button press, never by the swipe itself (the v1 two-step judgement carries over). *Past-day `SKIPPED` (passive, nothing to un-skip): the reveal shows no button — recovery there is G1 only* `[design]` (ratified v2) |
| G5 | Skip / Unskip press | revealed | **Skip** → `SKIPPED`: `status = 'skipped'`, `actual_time` cleared if the card was `DONE_CONFIRMED` (skipping asserts it did not happen); kcal, fuel windows and timeline entry leave **every** figure for that day (surface S-2 scope); the card loses its timeline slot (S-7). **Unskip** → `PLANNED`: `status` cleared, `planned_time` untouched, position restored (reference rendering: unskip always lands on planned, never on confirmed). Both offer undo (toast, restores the exact prior state) — the v1 "no undo" defect W-4 does not carry into v2 |
| G6 | Platform sync matches this card | `SKIPPED` (passive or active), `DONE_CONFIRMED`, `PLANNED` | → `DONE_VERIFIED`: `actual_time` = measured start, source MANUAL/FORMULA → GARMIN, fuel re-enters. **Sync beats skip.** No user gesture can reverse it (G3) |
| G7 | State-change emission | — | The card **emits** its state change; it never repaints only itself. What listens is the surface's business |

## Data contract (authority: `spec/daily-macros/platform-resolution.md`)

`planned_time` immutable by gesture · `actual_time` written by Garmin sync (measured start) or
mark-done (**`= planned_time`**, Q-D7 — v2 said `= now`), cleared by mark-undone, upgraded
MANUAL → GARMIN on later sync · display shows
`actual_time ?? planned_time` · **`status`** ∈ {planned, skipped, deleted}: `skipped` written by
Skip, cleared by Unskip or by G1 recovery, **overridden by any matching sync** (`SKIPPED` never
survives a sync); `deleted` is the tombstone of the deferred delete path — no card gesture writes
it in v2 · passive `SKIPPED` is **derived** (day past ∧ `actual_time` null ∧ `status` ≠ skipped),
never written.

## Conformance (design vectors)

- **Golden (L1):** one image per state row, at token-resolved colors. The `SKIPPED` golden is
  blessed from the reference rendering's previous-day view (neutral drain).
- **Widget/Patrol (L2):** G1–G6 as scripted gestures/events asserting state, `actual_time` and
  `status` writes/clears, and G7 emission (assert a listener fires; whole-surface propagation is
  tested by the surface). **G3 negative test:** a swipe in either direction on `DONE_VERIFIED`
  produces no reveal and no state change — assert zero translation after release and no
  "Mark undone" / "Skip" node in the tree. **G6 test:** skip, then deliver a matching sync →
  `DONE_VERIFIED`, fuel back in every figure. **G1 write test (v3):** on the current day and on a
  past day, `actual_time == planned_time` after the swipe (never the clock), card still at its
  planned slot on its own day. **G1 future-day negative test (v3, Q-D7):** right-swipe on a
  future-day `PLANNED`/`SKIPPED` card → zero translation after release, no reveal, no
  `actual_time` write, no state change; left-swipe on the same card still reveals Skip/Unskip.
- Known reference-rendering defects — do **not** encode as truth: reveal never auto-dismisses
  (W-6); on a past day the second right-swipe lands on a `PLANNED` card (W-10 — the app derives
  `SKIPPED` there). W-3/W-4 (delete no-op, no undo) are moot in v2: delete is gone and skip has
  undo.
- **A golden may only be regenerated after this spec changes** — never to make a red test pass.
  Regeneration commits cite the spec change (`workout_card_skipped`: cite Q-D5 + Q-D6/D-2).

## Open ratification questions
- **Q-D7 — mark-done on a non-current day (and the current-day write). RULED and RATIFIED as v3
  (Xuan, 2026-08-18) → `daily-macros-dashboard@v3`.** `actual_time =
  planned_time` on past and current days (reverses W-7); not offered on a future day; Q-D6
  recovery inherits the write. Engine register hook: `spec/daily-macros/OPEN-QUESTIONS.md` Q-018.
  Intake: `intake/2026-08-18-mark-done-on-non-current-day.md`.
- **Q-D6 — the unified-skip model. RULED and RATIFIED as v2 (Xuan, 2026-08-17).** Decisions carried: skip replaces delete (delete deferred); active skip on
  the current day; sync beats skip; skipped card loses timeline position, unskip restores; Q-017's
  step-10b exemption is **excluded** from the same bundle version (Xuan, 2026-08-17).
- Q-D1 ruled 2026-08-14 (folded into G3); Q-D4 / Q-D5 ruled 2026-08-17 (folded into States).

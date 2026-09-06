# Design SSOT — Component: Calendar Sheet

**Status: RATIFIED v1 (Xuan, 2026-09-06 — ruling-desk block of 2026-09-06). Ships as
`home-shell@v1`.**
**Component contract** — owns the sheet's chrome, the day-cell anatomy and both of its cell
channels (dot ← workout state, tint ← logged fueling), plus the summon/dismiss gesture set.
**Tokens / material:** [`../tokens.md`](../tokens.md) §Materials — the sheet takes `glass-sheet`
**including its scrim (blackberry 60%)**; the Today pill and month chevrons take `glass`. Raw
values live in the tokens file only.
**Companion artifact:** `New Homepage with updated navbar calendar and chat.html` (walked live
2026-09-06) — illustrates; this file governs. Where the intake and the export disagreed
(today/selected treatment), the ruling below names the winner.
**Ruling source:** [`../../../intake/2026-09-06-calendar-sheet-two-channel-cells.md`](../../../intake/2026-09-06-calendar-sheet-two-channel-cells.md) (RESOLVED).

## The design contract (ratified as drawn)

Full-height `glass-sheet` summoned from the DateHeader
([`date-header.md`](date-header.md) — REST title tap or COMPACT calendar button; both paths, one
sheet), over the scrim (**load-bearing, not cosmetic** — without it, page chrome bleeds through
and impersonates the sheet's own glyph vocabulary; every future summoned glass surface inherits
it). Chrome: "**{Month YYYY} ˅**" + month chevrons top-right; `SUN`–`SAT` eyebrow labels; weeks
as rows; out-of-month cells empty; floating **Today** glass pill bottom-left; grabber at the top
edge.

**Day cell anatomy is THREE FIXED SLOTS — day number, dot slot, tint slot — and the extension
contract is that future features only ever repaint the tint slot.** *(Ruled into this spec
verbatim, 2026-09-06 — it is what keeps later lenses from re-architecting the grid.)*

**Today and selected — RULED (Xuan, 2026-09-06: the export governs; the intake's contract line
said the reverse and is corrected by this ruling):**

| Cell | Treatment |
|---|---|
| Today | **Cream-FILLED cell** (blackberry ink) |
| Selected (non-today) | **Cream ring**, 2 px |
| Selected == today | Cream-filled (the today treatment wins; observed in the export) |

**Day tap →** home navigates to that date, sheet dismisses.

## Q1 — dot slot ← workout state machine (RULED as proposed)

The dot derives from the ratified workout states — authority
[`workout-card.md`](workout-card.md) v3 (cross-referenced, deliberately not restated here):

| Workout state (workout-card.md v3) | Dot |
|---|---|
| `PLANNED` | Hollow `orange` ring, **2 px stroke, visibly dark centre** (the 1 px version reads solid at cell size — round-2 fix) |
| `DONE_CONFIRMED`, `DONE_VERIFIED` | Filled `electrolyte` dot — **no per-source distinction at cell size**; provenance stays the cards' business |
| `SKIPPED` (active or passive) | **No dot** — a hollow ring on a past skipped day is the failure signal this surface bans; the calendar stays neutral about skips |
| Rest day (no workout) | No dot |

**Multiple workouts / brick day:** one dot, best state wins — any completed → filled; else any
planned → hollow. (A count was considered and ruled against at cell size.)

## Q2 — tint slot ← "day has logged fueling" (RULED: binary v1)

The day tints when it has **≥ 1 athlete food log entry** (any source counts as the athlete's; a
day with only engine-planned items is **not** tinted). **Binary in v1** — intensity scaling is a
later ruling, not a v1 behaviour. The tint encodes **presence only**: an unlogged day keeps the
plain ground; no negative state, and **no `dragonfruit` anywhere on this surface**. Day
boundaries follow the app's existing daily-macros day definition — referenced, not restated.
*(Instrumentation: the per-day fueling-log rollup does not exist yet — building the derivation is
an app-side gate of this bundle; an ops sibling is filed if it needs backend work.)*

## Gestures — summon / dismiss (dismissal set RULED contractual, Xuan 2026-09-06)

| # | Gesture | Contract |
|---|---|---|
| CS-1 | Summon | From either DateHeader path; one sheet, one state |
| CS-2 | Grabber pull | Pull past the threshold → dismiss; released short → **snap back**. Thresholds pinned by the gesture manifest + goldens, never prose |
| CS-3 | Scrim tap | Dismiss |
| CS-4 | Day tap | Navigate home to that date + dismiss |
| CS-5 | Month chevrons / month title ˅ | Month navigation; sheet stays |
| CS-6 | Today pill | Select + navigate to the current day |

## Conformance (design vectors)

- **Goldens (L1):** a **dense month** with the channels diverging (tinted rest days AND untinted
  completed days — both must be present); a **sparse month** (3 workouts, 3 tints — must read
  calm); the **enlarged cell-spec card** (all four dot rows + tint on/off + today + selected);
  all at token-resolved colors over the ruled scrim.
- **Gesture manifest (L2):** CS-1…CS-6, including the CS-2 snap-back negative (short pull →
  sheet still open) and the CS-4 combined assertion (home date changed AND sheet gone).
- Goldens regenerate only after this spec changes; commits cite the change.

## Open ratification questions
- *(none — the contract, both channel mappings, today/selected and the dismissal set all RULED
  2026-09-06. Tint intensity scaling is deliberately out of v1 — a future ruling, not an open
  defect)*

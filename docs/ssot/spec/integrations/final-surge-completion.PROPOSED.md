# SSOT — Integrations: Final Surge completion

**Status: PROPOSED v1 (Lee, 2026-09-25) — authored app-side, awaiting Xuan.** Written from
testing-wave ticket 99 (Finding 29-002, Lee's ruling 2026-09-25: build it now). It amends
[`final-surge.md`](final-surge.md) FS-2.1 and applies [`matching.md`](matching.md) M-1.3 to
Final Surge. Until Xuan rules, Lee's ruling overrides FS-2.1's "completion data has never been
observed from FS". App-repo-relative paths.

## Why

FS-2.1 says every FS import lands and stays `planned`, and that FS completion data had never
been observed. On 2026-09-24 the dev account's feed sent it for two of the day's runs
(`.scratch/testing-wave/runs/29/console-redacted.log` lines 15993-16068):

| Workout | Plan | `WorkoutCompleted` | `ActualTime` (s) | `ActualDistanceMeters` |
|---|---|---|---|---|
| "Easy", `WorkoutTime 05:32:02` | 8 mi, pace in description | `true` | 2021.254 | 5704.1698 |
| "Run", `WorkoutTime 07:28:33` | none | `true` | 2154.255 | 6218.839 |

Both carry `WorkoutDate: 2026-09-24T00:00:00` (naive local). The app used the actuals only as
fallbacks for the *planned* fields, so the Easy card read "8 mi · 34 min" (planned distance,
actual time) and both cards stayed Planned with `actual_*` null.

## FSC-1 — The completion signal

A payload is a completion when `WorkoutCompleted == true` or `ActualTime` is a positive number
of seconds. This is the same predicate the M-1.3 revive path already used
(`FinalSurgeTransformResult.providerReportsCompletion`).

## FSC-2 — Planned fields keep the plan

`ActualTime` and `ActualDistanceMeters` never fill `duration_minutes`, `distance_miles` or
`distance_meters`, and never feed the pace derivation. Those fields are resolved from the plan
alone, by the FS-2.3 and FS-2.4 rules (including the load-bearing NULL duration and the sport
defaults when the plan is empty).

## FSC-3 — What is stored

A completion lands on the row as:

| Column | Value |
|---|---|
| `status` | `completed` |
| `actual_time` | the recorded start: `WorkoutDate` + `WorkoutTime`, naive local (L-9.2's 07:00 default when no time) |
| `completed_at` | `actual_time` + `ActualTime` seconds; `actual_time` when there is no `ActualTime` |
| `actual_duration_minutes` | `ActualTime` / 60, rounded, clamped 1..1440; NULL when absent |
| `actual_distance_miles` | `ActualDistanceMeters` / 1609.34; NULL when absent (all sports) |
| `completion_type` | `provider` (the column's default stays `manual` for the athlete's mark-done) |

Re-sync merge (L-2), by the M-1.3 order fact > declaration > heuristic:

1. A completion replaces a planned, skipped (G6) or athlete mark-done row's status and completion
   fields.
2. It never overwrites a Garmin completion (`garmin_summary_id` set): the device measurement
   stands. It never touches a brick-archived segment.
3. A later payload without completion changes none of these fields. A completion cannot be
   undone by a plan re-send.
4. A completion on a tombstoned row revives it to `completed` with the same fields (M-1.3.1).

## FSC-4 — Display

A row with `status = completed` and `completion_type = provider` is **DONE_VERIFIED**
([`integrations-data-display.md`](../design/surfaces/integrations-data-display.md) D-1): the
card shows the measured pair only (Q-DID1 B) and the chip reads `verified · Final Surge`. When
FS reports completion with no measurements, the card keeps the planned pair (D-1: `actual ??
planned` as a pair). Bricks keep the B-3 leg-stamp rule. An athlete mark-done on an FS row stays
DONE_CONFIRMED (self-reported).

## FSC-5 — Time

`WorkoutDate` and `WorkoutTime` are naive local wall clock. `actual_time` and `completed_at` are
built from them without any time-zone conversion, the same as `scheduled_date_time`, so a
completion stays on the athlete's local day.

## Open for Xuan

1. **Verified or self-reported?** FSC-4 treats an FS-reported completion as verified, as M-1.3
   treats keyed completion as fact. FS's actuals may themselves come from a watch upload or from
   the athlete typing them in; FS does not say which. Keep verified, or show a separate chip?
2. **Chip wording.** `verified · Final Surge` follows the `verified · <platform>` pattern.
3. **Energy mark.** The Active Energy burn mark stays "self-reported"/"estimated" for FS
   completions, since FS sends no calories. Confirm.
4. **Flag without actuals.** `WorkoutCompleted: true` with no `ActualTime` still counts as a
   completion (FSC-1) and shows the planned pair (FSC-4). Confirm.
5. **FS-2.1 amendment.** Fold FSC-1..5 into `final-surge.md` FS-2.1 in the QA repo, and add the
   two payloads above to the FS conformance vectors.

# /sim-explore — macro dashboard charter · 2026-08-20

- **Build:** dev flavor 1.23.1 (com.milkman.mealvanaendurance.dev), iPhone 17 sim (iOS 26.4), dev Supabase `vlmtsdzpnjnavdgytcmi`
- **Account:** ravi@test.com (`4a74be96…`) — shared test account; checks anchored on `PROBE-`-prefixed rows
- **Charter:** `.claude/skills/sim-explore/references/charter-macro-dashboard.md` (daily-macros-dashboard@v3 surfaces)
- **Screenshots:** session scratchpad `explore/` (00–55)

## Per-row verdicts

| Row | Verdict | Note |
|---|---|---|
| 1 open dashboard | ✅ | one paint, no strobe |
| 2 seed planned ⏱ | ✅ today + future | card at slot, dotted, `Planned`; DB planned/NULL |
| 3 mark done ⏱ | ✅ today + **past** | **Q-D7 verbatim: `actual_time == planned_time`** (18:00 written at 16:56); card KEEPS slot & day; past-day recovery took its 7:00 AM slot on ITS day; today untouched (no cross-day leak) |
| 4 undo ⏱ | ✅ today + past | actual NULL; past day returns to derived `Skipped`, never Planned (W-10 guard holds) |
| 5 skip ⏱ | ✅ | neutral reveal, tuck, no timestamp, figures drop in-frame, undo toast, no energy-card blink; DB skipped/NULL |
| 6 unskip ⏱ | ✅ | slot + figures restored, undo both directions |
| 7 verified card | ⬜ NOT COVERED | no DONE_VERIFIED card available on any visited day |
| 8 future-day right-swipe ⏱ | ✅ | zero reveal/write/state change; Skip still reveals (asymmetry per v3 G1) |
| 9 past-day passive skip | ✅ | untimed neutral stack after the timed card |
| 10 expansion persistence | ✅ | survives face switch AND card swipe (W-8 dead); even survived a full settings round-trip |
| 11 Full Breakdown | ✅ | opens at face's page, numbers match card — but see finding 3 (copy) |
| 12 weight → save | ✅ | today+future invalidated then recomputed (4097→4165, 2350→2376); **past-day values byte-identical (Q-016 honored)**; no blink; lazy recompute on next dashboard build |
| 13 kill/relaunch | ✅ | identical frames +3s/+7s, lands on today |
| 14 timeline toggle | ✅ | rail/timestamps hide; restore is md5-identical to pre-toggle frame; no recompute storm |

Free play (~8 min): done→skip inside 3 s (actual_time correctly cleared) · weight-save raced with day-flips + unskip (no dupes, no orphans, coherent UI) · armed-back-stack double-create (**reproduced — bug**) · server-side tombstone propagation (**stuck — bug**).

## Findings filed

Ops (`ops/data/bug-reports/2026-08-20-*`):
1. **Major — session-kcal three surfaces disagree**: create screen 1,410 / dashboard sheet 1,349 / engine session_kcal 1,530→1,568 (sheet ignores weight change; engine ⇄ explanation drift, invariant I4).
2. **Major — duplicate activity via armed back stack**: back-back after Create lands on the live form; re-fire inserts an identical row (proven: 2× PROBE-DUP @ 18:15).
3. **Minor — "self-reported · awaiting sync"** on the Active Energy sheet contradicts Q-D4 (awaiting-sync concept is ruled dead).
4. **Major(pending) — server tombstone not applied to locally-known rows** through relaunch + refresh + ~5 min; recovered via the app's own delete path.
5. **Minor — papercuts**: reveal never dismisses on outside tap (W-6 parity); plan-detail "Planned 1h 30m ahead" frozen at creation; Workout-face + Add Activity intermittently unresponsive (a11y: AXStaticText, not a button).

QA intake:
6. `intake/2026-08-20-future-day-net-balance-copy.md` — future day shows −2,115 "deficit — time to eat" (intraday register on a day that hasn't begun); ruling requested for a future-day/projection register.

Observations (not filed): ±25 kcal burned-so-far shift on skip/unskip of a not-yet-started workout (targets side-effect? worth one targeted trace) · `daily_macro_targets.updated_at` touched on past-day rows during gesture-triggered recomputes (values unchanged — Q-016 intact, but the touch muddies auditability) · the 1,351 net shift on mark-done matches the sheet's 1,349, corroborating finding 1.

## Cleanup
All four probe rows soft-deleted via the app's plan-detail trash (local+server agree, `status='deleted'`); the server-side copies additionally parked in 2016 so the ±15-min matcher can never collide. `select count(*) from activities where title like 'PROBE-%' and status!='deleted'` → 0. Weight restored to 161 lbs; targets recomputed back to baseline (4,097 / 2,350). Timeline visually clean (explore/55-final.png).

## Verdict
The v3 contract holds on-device everywhere the charter touches it — Q-D7, Q-D5/Q-D6, Q-016, W-8/W-10 all behave. What's broken is around the contract's edges: cross-surface number agreement, the creation flow's navigation stack, sheet copy, and tombstone down-sync. Row 7 (verified card) still needs a session with a Garmin-synced fixture.

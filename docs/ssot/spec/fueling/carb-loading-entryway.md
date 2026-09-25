# SSOT — Carb Loading: plan entryway & lifecycle (create · edit · delete)

**Status: RATIFIED v1 — BEHAVIOR CONTRACT ONLY (Xuan, 2026-09-24, entryway interview batch;
read-back confirmed). The RENDERING (plan summary surface, re-pick confirm dialog, disabled-card
treatment) is NOT ratified — it awaits the prototype extension and the desk, per the
always-visual design rule. Drafted the same day from app-38's proposal @ `5d8e8e4d`.** Named bundle-completeness gate for `carb-loading@v1` (Xuan,
2026-09-24: "the bundle is not complete until we understand where the entryway is").
**Current-state evidence:** the 2026-09-19 audit IS the shipped flow (no feature commits since
09-10) — one-shot entry (`pushReplacement` onto the legacy day page, `event_action_buttons_card.dart:206-253`),
edit = delete-plan + create-plan with fresh IDs and no navigation (`carb_loading_service.dart:381ff`),
delete has service support (`carb_loading_controller.dart:84`) and zero UI.
**Scope:** the entry row, the chooser's contract deltas, post-selection destination, re-pick
semantics, delete, and the reminder-to-start disposition. Slot-day math is `carb-loading.md`
(RATIFIED v1); the chooser's 1-Day card and point-value copy are already ruled there (G3, CL-12).

## Contract (RATIFIED rows — behavior; ruled imports cited, not re-asked)

- **CE-1 — Entry row, two states** *(Q-CE1)*: the event-details action row stays the canonical
  entryway. No plan → label "Set Up Carb Loading", opens the chooser. Plan exists → the row is a
  summary ("3-Day Classic · Sep 25–27") opening the **plan summary surface** — protocol re-pick
  becomes an action ON the plan, one level in; the bare chooser-reopening "Edit" row is retired.
- **CE-2 — Plan summary surface** *(Q-CE1, same gate)*: dates, per-day targets, per-day g/kg
  (point-value per CL-12), re-pick action, delete action (CE-5). New surface; pixels via
  prototype extension if the desk wants them.
- **CE-3 — Post-selection destination** *(Q-CE2)*: chooser pops back to **event details** (no
  `pushReplacement`, no stack surgery); the summary row now reflects the plan. If day 1 is today
  or underway, the success snackbar carries a CTA "Go to today's fuel" → the dashboard timeline;
  otherwise no forced navigation — visibility from then on is the ruled LOAD face.
- **CE-4 — Re-pick semantics** *(Q-CE3)*: on selection, diff the plan.
  - No day target ever edited → regenerate quietly.
  - Any stored `carbTargetGrams` differing from its protocol derivation → confirm dialog listing
    the edited days, exactly two choices: **"Keep my targets"** (migrate by DATE — regenerated
    days matching an edited date keep the stored grams and re-derive per CL-4a; dates outside
    the new protocol's window are dropped, and the dialog says so) or **"Reset to protocol"**.
  - Imports (ruled, not re-asked): slot logs survive any plan mutation (Path A); edited targets
    must never drop silently (Q-CL10).
- **CE-4a — Stable day-row identity** *(Q-CE4, implementation contract)*: day rows update in
  place keyed by plan+date instead of delete+recreate with fresh IDs, so foreign references and
  sync history survive re-picks.
- **CE-5 — Delete** *(Q-CE5)*: "Remove carb loading plan" on the plan summary — destructive
  register (dragonfruit), confirm copy states targets/schedule are deleted and **"food already
  logged stays in your log"** (true by Path A). Event-deletion cascade unchanged. No
  archive/history in release-1.
- **CE-9 — Dialog abort — RULED (Xuan, 2026-09-25, F6 interview: option A):** on BOTH re-pick
  dialogs (Keep/Reset and the F4 single-notice), a tap outside the dialog ABORTS the re-pick —
  dialog dismisses, plan untouched, chooser stays open. No new button; CE-4's "exactly two
  choices" stays literally true (the abort is a gesture, not a third option). Matches the ruled
  summoned-surface backdrop modality.
- **CE-8 — Chooser feasibility gate — RULED (Xuan, raised and ruled at the interview):**
  a protocol is choosable iff `days_until_race >= protocol_days` (race tomorrow → only 1-Day;
  in 2 days → 1- and 2-Day; 3+ → all three). **Race day itself: nothing choosable** — the entry
  row states the loading window has passed. Infeasible cards render **disabled with the reason**
  ("Needs N days before race day"), never hidden. Mid-plan re-pick to a shorter, still-feasible
  protocol is allowed (the athlete behind on a 3-Day may switch to the 1-Day); CE-4's
  migrate/drop semantics cover the fallout with no new machinery.
- **CE-6 — Reminder-to-start: OUT of release-1, named** *(Q-CE6)*: joins the exclusion list
  explicitly; it belongs to the fuel-CTA notifications workstream, consuming the plan's
  `startDate` seam later — no entryway rework.
- **CE-7 — "Manage plan ›" breakdown footer** — **DESK item, not this batch**: navigation-only
  row on the ruled read-only breakdown page → plan summary. Touches a ruled surface; rides the
  desk batch with glow + D7.

## Conformance implications (staged with the bundle)
Mostly L2/test-plan rows, not numeric vectors: entry-row state switch; post-selection stack
shape (back behaves); re-pick quiet path vs confirm path; migrate-by-date keeps stored grams /
drops out-of-window dates with disclosure; delete leaves food-log rows intact. One numeric
vector family joins `carb-loading.json` post-ratification: migrate-by-date target survival
(stored 620 g on a matching date re-derives slots per CL-4a after a protocol switch).

## Question register (batch closed 2026-09-24)
| Q | Disposition |
|---|---|
| Q-CE1 | **RULED** — CE-1/CE-2 as proposed |
| Q-CE2 | **RULED** — CE-3 as proposed |
| Q-CE3 | **RULED** — CE-4 as proposed (two choices, no third option) |
| Q-CE4 | **CONFIRMED** — CE-4a stable day-row identity |
| Q-CE5 | **RULED** — CE-5 as proposed |
| Q-CE6 | **CONFIRMED** — reminder-to-start OUT, named in exclusions |
| CE-8 | **RULED** — feasibility gate (raised by Xuan at the interview; see row) |
| CE-9 | **RULED 2026-09-25** — backdrop-tap aborts both re-pick dialogs (F6, option A) |
| CE-7 | **RULED yes (Xuan, 2026-09-25, desk)** — navigation-only "Manage plan ›" footer on the breakdown page → plan summary; read-only holds |

## Rendering ratification (OPEN — the desk)
The plan summary surface, the re-pick confirm dialog, and the disabled-card treatment need
pixels: app-38 extends the prototype; the desk ratifies visually (A/B where a call exists).
Behavior above binds the rendering; the rendering may not add or remove behavior.

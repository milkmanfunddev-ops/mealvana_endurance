# Carb-loading plan CREATE/EDIT entryway — current state + design proposal

For QA per the 2026-09-24 request ("the bundle is not complete until we
understand where the entryway is"). Sections are marked **RULED** (Xuan has
already ruled it, with citation) or **PROPOSAL** (open call — route to the
interview/desk). Prepared by app-38, 2026-09-24.

---

## 1. Current state, as shipped / on-branch (evidence)

Photographic: `docs/kyle/carb-loading-audit-2026-09-19/shots/` on this branch —
the feature has no commits since 2026-09-10, so the 09-19 audit run IS the
current flow. The relevant frames:

- `08_after_create.png` — event details right after event creation; the action
  row reads **"Create Carb Loading Plan"**.
- `09–11_protocol_*.png` — the protocol chooser (3-Day / 2-Day cards, range
  copy "8–10", expandable phases).
- `12_after_select.png`, `13_day1_scroll.png` — what selection lands on.
- `21_event_detail_after.png` — the row re-labelled **"Edit Carb Loading
  Plan"** once a plan exists.
- `22_edit_plan.png`, `25_after_edit_protocol.png` — the edit re-pick and its
  aftermath.

Code truth (all cited from `feature/carb-loading`):

- **Entry**: `event_action_buttons_card.dart:83-93` — one row, key
  `event_details.carb_loading_button`, label switches on `event.hasCarbLoading`
  ("Create…" / "Edit…"). Both push `CarbLoadingProtocolSelectionScreen`, which
  `Navigator.pop(context, days)` returns an int (`…selection_screen.dart:149`).
- **CREATE path** (`event_action_buttons_card.dart:206-253`): creates the plan,
  success snackbar, then **`pushReplacement` to the legacy
  `CarbLoadingDayDetailPage` for day 1** — the event-details page is popped out
  of the stack, so back lands on the Events list, and there is no route back to
  the day page afterwards (the audit's "one-shot" finding).
- **EDIT path** (`:186-201`): `updateCarbLoadingProtocol` →
  `carb_loading_service.dart:381-…` which is **delete-plan + create-plan** —
  every day row regenerated with fresh IDs — then a snackbar; **no
  navigation** (you stay on event details).
- **DELETE**: service + controller support exists
  (`carb_loading_controller.dart:84`); deleting the event cascades
  (`events_repository.dart:396`); **no UI entry point anywhere**.

Consequences under today's rulings: the chooser lacks the 1-Day card (G3), its
copy is range-style ("8–10") against CL-12 point-value, and the edit re-pick
**silently destroys edited day targets**, which Q-CL10 just made athlete data.

---

## 2. Design proposal

### (a) Entry points

**PROPOSAL.** The event-details row stays the canonical entryway, same key,
two states:

- **No plan:** label "Set Up Carb Loading". Tapping opens the chooser
  (unchanged mechanic).
- **Plan exists:** the row becomes a small summary — protocol name + dates
  ("3-Day Classic · Sep 25–27") — and opens the **plan summary surface**
  (below), NOT the chooser directly. "Edit Carb Loading Plan" as a bare
  chooser-reopener disappears; re-picking a protocol becomes an action *on*
  the plan, one level in, where its consequences can be shown.

**Durable route back in (PROPOSAL):** on loading days, the dashboard LOAD face
and timeline are already the daily surface (RULED 09-19/09-24), and the
breakdown page's PROTOCOL strip navigates days (RULED, v17). Proposed
addition: a quiet "Manage plan ›" footer row on the breakdown page that
navigates to the plan summary surface. Navigation-not-mutation, so the
breakdown page itself stays read-only — but this touches a ruled surface, so
it is explicitly flagged for the desk/interview. If rejected, the event page
remains the only manage entry, reached Events → event → row.

### (b) Post-selection destination

**PROPOSAL.** Selection pops the chooser back to **event details**, which now
shows the plan summary row (dates, per-day targets, per-day g/kg — point-value
per CL-12). No `pushReplacement`, no stack surgery; back behaves normally.

Rationale: a plan is usually created days before day 1 — dumping the athlete
into a day-1 *logging* surface (today's behavior) at creation time is
premature, and the legacy `CarbLoadingDayDetailPage` is not a release-1
surface. If the plan's first day is **today** (or already underway), the
snackbar carries a CTA: "Go to today's fuel" → the dashboard timeline
(scaffold live). Otherwise: no forced navigation; the plan's visibility from
then on is the ruled LOAD face when day 1 arrives.

### (c) Edit / re-pick semantics

- **RULED:** slot logs are ordinary food-log entries (Path A, 09-23) — they
  survive any plan mutation by construction and keep counting toward their
  days.
- **RULED:** edited day targets are athlete data that re-derive slots,
  checkpoints, ramp, copy (Q-CL10). Silently dropping them — today's
  delete+create — is not acceptable.
- **PROPOSAL (the design call):** re-pick from the plan summary opens the
  chooser; on selection, diff the plan. If **no day target was ever edited**,
  regenerate quietly (today's outcome, minus the hazard). If **any stored
  `carbTargetGrams` differs from its protocol derivation**, a confirm dialog
  lists the edited days ("Day 2 — you set 620 g") with exactly two choices:
  **"Keep my targets"** (migrate by *date*: regenerated days that match an
  edited date keep the stored grams and re-derive from them; dates that fall
  outside the new protocol's window are dropped and the dialog says so) or
  **"Reset to protocol"**. No third option, no partial pick.
- **PROPOSAL (implementation note for G-gating):** day-row identity should
  become stable (update-in-place keyed by plan+date rather than
  delete+recreate with fresh IDs), so foreign references and sync history
  survive; this is invisible to design but the migration above is simplest on
  top of it.

### (d) Delete / lifecycle

**PROPOSAL.** The plan summary surface carries "Remove carb loading plan" —
destructive register (dragonfruit per tokens.md Q-D3), confirm dialog stating
what happens: targets and schedule are deleted; **food already logged stays in
your log** (true by Path A). Service support exists; only the UI is new.
Event deletion continues to cascade (as shipped). No archive/history concept
in release-1.

### (e) Reminder-to-start

**PROPOSAL: OUT of carb-loading release-1**, and the exclusion list should
name it explicitly (it is currently silent). Rationale: a start-day reminder
is a notification product decision that belongs to the fuel-CTA notifications
workstream (feasibility closed 2026-09-17; its release-1 scope is separately
gated) — landing a one-off local notification here would fork that system's
rulings. The entryway design leaves a natural seam: the plan summary knows
`startDate`; when the notifications workstream lands, the reminder is a
consumer of that field, no entryway rework.

---

## 3. Ruled vs. open, at a glance

| Item | Status |
|---|---|
| Chooser gains 1-Day card @ 11.0 g/kg | RULED (G3 / Q-CL3a) |
| All chooser/help copy point-value | RULED (CL-12 / Q-CL4+5) |
| Slot logs survive plan mutation | RULED (Path A) |
| Edited targets must not be silently dropped | RULED (Q-CL10 + qa 09-24) |
| Two-state entry row + plan summary surface | PROPOSAL |
| Post-selection → event details (+ today CTA) | PROPOSAL |
| Keep-my-targets / Reset confirm on re-pick | PROPOSAL |
| Migrate-by-date semantics | PROPOSAL |
| Stable day-row identity (update-in-place) | PROPOSAL (impl) |
| "Manage plan ›" on breakdown page | PROPOSAL — touches ruled read-only surface, flag to desk |
| Delete affordance + confirm copy | PROPOSAL |
| Reminder-to-start OUT (named in exclusions) | PROPOSAL |

Prototype extension: not built yet — this document is the fastest handover.
If the desk wants pixels for the plan summary / confirm dialog, app-38 will
extend the Fuel Timeline project on request (the chooser itself is app-side
and was audited in shots 09–11).

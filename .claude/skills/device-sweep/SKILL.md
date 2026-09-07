---
name: device-sweep
description: UI proofread across the device matrix — walk the shipping surfaces on the tier devices (smallest phone through iPad, plus the Android emulator) with a POPULATED account, capture every contractual state, and publish/refresh the review-board artifact. Run before merging a UI-bearing feature branch to develop, and as a release-gate pass on a release candidate. Invoked as "/device-sweep", "run the sweep", "check this on different devices".
---

# Device sweep (UI proofread)

The cross-hardware complement to qa's `sim-explore`: sim-explore asks *does it
behave right* on one device; this asks *does the design hold up* across sizes,
platforms, and render backends. All device mechanics live in `/drive-device` —
load that skill first and follow it; this file is the matrix, the checklist,
and the reporting contract.

## Tier matrix — resolve by name at runtime, never pin UDIDs

1. **Smallest supported phone** (SE-class, 375pt) — the width- and
   height-budget canary. Most layout overflows only reproduce here.
2. **Baseline phone** (current mainline iPhone).
3. **Tallest/widest phone** (current Pro Max class).
4. **iPad** — exercises the tablet/rail breakpoint branch.
5. **Android emulator** (AVD `mealvana_api36` or current equivalent) — the
   other render backend. Confirm the backend in logcat (expect Impeller);
   emulator GLES translates on the host GPU, so shader findings still need
   one physical-Android check before any Android ship decision.

Create missing sims with `xcrun simctl create` from current device types —
don't skip a tier because no sim exists.

## Preconditions

- A **populated** account, or the sweep proves nothing: seed with
  `node qa/scripts/seed-activities.mjs [email]` and log the device in as that
  account (per `/drive-device`, including its meal_logs-gap workaround when
  the surface under test needs meal data). An empty account hid a real
  SE overflow for a full sweep round once — pills that only appear with data
  never rendered.
- Use a **debug** build on sims: overflow banners are the cheapest detector
  the sweep has.

## State checklist — every tier, every state

For the current home shell (extend as surfaces ship; the ratified contracts in
`docs/ssot/spec/design/components/` define what counts as a state):

- Rest: home at top, header + pinned block + tab bar.
- Scrolled: top dissolve, bar collapse morph, pick a *tall* day so the list
  actually scrolls on big phones.
- Calendar sheet: all data channels visible (dots, rings, tint, today,
  selected).
- Tab bar in motion: committed switch AND a held drag — record video, extract
  frames, inspect the lens/highlight mid-transit for crispness and artifacts.
- Any conditional chrome the data can summon (e.g. the Brick pill) — data
  dependence is exactly where sweeps have caught real bugs.

## Findings protocol

- **Layout bug**: fix it, and add a regression test pumped at the failing
  logical size. Load real fonts in that test file (Ahem's square glyphs
  false-overflow rows that are fine on device) — see
  `test/features/home_shell/home_shell_test_fonts.dart`.
- **Design-pass-sized gap** (e.g. a breakpoint branch that needs rethinking):
  don't improvise a redesign — record it on the board and surface to Xuan;
  spec changes go through the qa intake flow.
- **Product/behavior finding** (sync gaps, data issues): report to Xuan and
  route via the ops bug-report workflow; not the sweep's to fix unilaterally.

## Reporting

One **review-board artifact per feature/bundle**, republished at its stable
URL every round (never a new artifact per round): a section per
device/round with a captioned screenshot strip, per-device notes, a verdict
chip, and a living follow-ups list where completed items get struck through,
not deleted. Give Xuan the link in the wrap-up.

## Cleanup

Shut down the sims the sweep booted (state persists), and never leave the
Android emulator running beside multiple sims (memory pressure kills it).

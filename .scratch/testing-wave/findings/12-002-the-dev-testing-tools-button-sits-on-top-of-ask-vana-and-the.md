# 12-002 · The dev testing-tools button sits on top of Ask Vana and the Vana Send button: tapping Ask Vana opened UI settings

- kind: bug
- status: triaged
- ticket: 12
- run: w4-20260924T0417Z
- screen: Timeline
- decision: 

**Steps.**
1. Run the dev debug build with `scripts/run_dev.sh` (it passes `IS_INTERNAL=true`).
2. Sign in, dismiss the sheets, tap the red Ask Vana button at the bottom right of the timeline.
3. In the Vana companion, try to tap Send.

**Expected.**
Ask Vana and Send take the tap. The testing-tools button, if it must float there, sits clear of the app's own controls.

**Actual.**
The blue "Open testing tools" button (344,782 48×48 pt) overlaps Ask Vana (336,790 52×52) and Vana's Send (342,778 44×44). A tap on Ask Vana's centre opened the UI settings tool instead; only a tap on Ask Vana's bottom-left edge (340,837) opened Vana, and the message had to be sent with the keyboard's Return. It also covers the right end of the What's New sheet's Got it button. Dev only (the tool is internal), so athletes never see it, but it makes every agent and hand test on dev miss these controls.

**Evidence.**
- runs/12/07-timeline-ask-vana-button.png
- runs/12/08-testing-tools-opened-instead-of-vana.png
- runs/12/09-vana-open.png (Send under the wrench)
- runs/12/04c-timeline-with-whats-new-sheet.png

**Decision quote.**
> 

**Triage.**

Fix ticket 68 (Lee, 2026-09-25). Closed by the retest after it merges.

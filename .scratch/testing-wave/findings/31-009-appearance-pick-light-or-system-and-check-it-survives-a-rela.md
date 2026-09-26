# 31-009 · Appearance: pick Light or System and check it survives a relaunch and a sign-out

- kind: followup-test
- status: closed
- ticket: 31
- run: w11-20260924T1648Z
- screen: Settings
- decision: 

**Steps.**
1. Settings > Appearance; the Theme Mode dialog shows System, Light, Dark with Dark selected.
2. Pick Light; relaunch; check it is kept.
3. Sign out and in as another account; check whether the theme carries over. Put Dark back.

**Expected.**
The pick is kept across a relaunch; whether it follows the device or the account is a product choice to confirm.

**Actual.**
Not run: this run opened the dialog and dismissed it by tapping outside (the dialog closed, nothing changed).

**Evidence.**
- runs/31/15-appearance-dialog.png: the dialog

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 93 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 119 when 93 was split (Lee, 2026-09-25).

Run by retest ticket 119 (run w36-20260926T0031Z, build 72d3723e): pass for Light (survives a relaunch; it is per device, so it carries to another account). Light's Timeline cards are bug 119-003; System is follow-up 119-011.

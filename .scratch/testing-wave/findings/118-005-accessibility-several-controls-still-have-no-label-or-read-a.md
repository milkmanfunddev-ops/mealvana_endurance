# 118-005 · Accessibility: several controls still have no label or read as text, not buttons (onboarding back, signup eye toggles, New Event back, Vana and Browse headers, Connected Apps Reconnect)

- kind: bug
- status: triaged
- ticket: 118
- run: w36-20260926T0031Z
- screen: Onboarding; Sign Up with Email; New Event; Vana (full screen); Browse meals; Connected Apps
- decision: 

**Steps.**
1. On each screen below, read `idb ui describe-all --udid UDID` (build 72d3723e).

**Expected.**
Every tappable control is a button with a name, as fix ticket 51 did for the sheet close, the
Browse add and the Log search bar.

**Actual.**
- Onboarding, every step: the back arrow (22,78 32×32) has no label (GenericElement, then
  StaticText with no label). On "Tell us about yourself" a label-less element "Continue" spans the
  whole screen (0,0 402×874) while Continue is disabled. The sport and obstacle tiles are
  StaticText with no checked state (the tick is visual only).
- Sign Up with Email: the two show-password buttons (338,328 and 338,402) have no label; Log In's
  same button is "Show password".
- New Event: the back button (4,66 48×48) has no label.
- Vana full screen: Back, New conversation, Conversations and the composer's Add and Dictate read as
  StaticText, not buttons.
- Browse meals: Back, Search meals and Filters read as StaticText. The filter menu's items are
  38 pt tall; the debug checker reports "Tap area of 112x38 is too small: should be at least 48x48"
  (9 issues).
- Connected Apps: each connection card is one Image element whose label runs "Reconnect / Sign in
  again … / Xuan Huang / Last synced …"; Reconnect and Sync Now are not separate buttons.
- Filled onboarding name fields lose their label ("First name" becomes no label once text is in).

**Evidence.**
- runs/118/03-sports-running.png, runs/118/08-onb-personal-filled.png: onboarding (element lists in runs/118/notes.md).
- runs/118/22-signup-email.png: signup eye toggles.
- runs/118/44-new-event-opened.png: New Event back.
- runs/118/54-vana-full.png: Vana header.
- runs/118/55-browse.png, runs/118/60-a11y-issues-browse-menu.png: Browse header and filter tap size.
- runs/118/41-connected-apps.png: Connected Apps cards.

**Decision quote.**
> 

**Triage.**

Fix ticket 141, Accessibility, dev buttons, small fixes (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.

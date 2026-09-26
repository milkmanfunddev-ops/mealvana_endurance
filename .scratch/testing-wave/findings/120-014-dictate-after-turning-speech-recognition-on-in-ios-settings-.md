# 120-014 · Dictate after turning Speech Recognition on in iOS Settings: works without a relaunch?

- kind: followup-test
- status: open
- ticket: 120
- run: w39-20260926T1013Z
- screen: Vana chat
- decision: 

**Steps.**
1. Refuse Speech Recognition from the Dictate tap.
2. iOS Settings → the app → turn Speech Recognition and Microphone on.
3. Back in the app, tap Dictate without relaunching.

**Expected.**
Dictation starts; no stale refused state and no settings message.

**Actual.**


**Evidence.**
- runs/120/17-second-dictate-tap.png (the refused state)

**Decision quote.**
> 

**Triage.**


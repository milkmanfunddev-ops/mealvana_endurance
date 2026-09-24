# 04-006 · Onboarding back button mid-flow keeps the answers already given

- kind: followup-test
- status: open
- ticket: 04
- run: w4-20260924T0418Z
- screen: Onboarding (Personal info, Body composition, Nutrition settings)
- decision: 

**Steps.**
1. Walk onboarding to Nutrition settings with answers on each step.
2. Tap the back arrow two or three times, then Continue forward again.

**Expected.**
Every answer is still selected on the way back and forward, and the saved profile after signup
carries them (the flow's sentinels: female, metric, high gut, heavy sweat).

**Actual.**
Not run (look-around, ticket 04).

**Evidence.**
- runs/04/06-personal-info.png
- runs/04/08-nutrition-settings.png

**Decision quote.**
> 

**Triage.**


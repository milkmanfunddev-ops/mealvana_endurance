# 09-004 · Opening a new meal plan with Vana asks for Speech Recognition before the athlete touches the microphone

- kind: idea
- status: triaged
- ticket: 09
- run: w7-20260924T1219Z
- screen: Vana chat (New meal plan)
- decision: 

**Steps.**
1. Food → New meal plan, first time on this install (12:33:09Z).
2. Before the chat shows, iOS asks: "“Endurance Dev” would like to access Speech Recognition." Don't Allow was tapped.

**Expected.**
Idea: ask for Speech Recognition (and the microphone) when the athlete first taps the mic, with a line saying why. Asking on the way into a chat the athlete may never dictate into makes a "Don't Allow" likely, and iOS won't ask again.

**Actual.**
The permission prompt comes up as the chat opens, before any mic tap. After Don't Allow the chat worked normally.

**Evidence.**
- runs/09/13-vana-new-plan.png

**Decision quote.**
> 

**Triage.**
Fix ticket 79 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.

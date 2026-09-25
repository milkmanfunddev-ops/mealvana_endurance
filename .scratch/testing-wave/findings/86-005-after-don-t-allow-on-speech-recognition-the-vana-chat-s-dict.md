# 86-005 · After Don't Allow on Speech Recognition, the Vana chat's Dictate button disappears without a word

- kind: idea
- status: triaged
- ticket: 86
- run: w25-20260925T1324Z
- screen: Vana chat (full screen)
- decision: 

**Steps.**
Idea. 1. Food → Ask Vana → Open full screen. 2. Tap Dictate; iOS asks for Speech Recognition; tap Don't
Allow. The Dictate button is then gone from the composer, with no line saying why or how to turn it back on
(iOS Settings). Show a short note on the denied tap, or keep the button and explain on tap.

**Expected.**
An athlete who declined once can find out why dictation went away and how to get it back.

**Actual.**
After Don't Allow the composer shows only the text field (it widens into the Dictate button's place); no
message. The prompt itself now comes on the mic tap, not on opening the chat (09-004 passes).

**Evidence.**
- runs/86/31-vana-full-screen.png (Dictate present)
- runs/86/32-dictate-tap-prompt.png
- runs/86/33-after-dont-allow.png (Dictate gone)

**Decision quote.**
> 

**Triage.**
Fix ticket 104 (Lee, 2026-09-25): Dictate stays after a refusal and a tap says how to turn it on in iOS Settings. Closed by retest ticket 107 after it merges.
Moved to retest ticket 120 when 107 was split (Lee, 2026-09-25).

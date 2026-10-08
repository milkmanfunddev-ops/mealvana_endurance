# 30-009 · Tell us about yourself: Continue stays dimmed until a gender is picked, with nothing saying gender is needed while the card says optional

- kind: bug
- status: open
- ticket: 30
- run: w3-20261008T1255Z
- screen: Tell us about yourself
- decision: 

**Steps.**
1. Onboarding (account B, 13:08Z). Leave first name, last name and email empty ("PERSONAL INFORMATION · optional"),
   pick no gender, keep the birth year.
2. Tap Continue.

**Expected.**
01-017: skipping optional fields works, and when something is required the screen says what is missing (as the sports
page does: "Please select at least one sport").

**Actual.**
Continue is dimmed and a tap does nothing. Nothing says gender is required; the element list does not mark the button
disabled either, so VoiceOver reads a plain "Continue". Picking Female enables it. (The subtitle "Age and gender help us
determine the best fueling strategy" hints at it; the copy is Xuan's and is not the point here.)
Also seen for 01-017, as passes: Back once and forward on every page kept the answers (sports, empty goal, obstacles,
gender, metric 62 kg, gut High, sweat Heavy, the daily plan); the sports page with nothing selected says "Please select at
least one sport"; Goal may be left empty and Continue moves on; Last name keeps its label once typed in.

**Evidence.**
- runs/30/30b1-04-personal-skip.png
- runs/30/30b1-02-continue-empty.png
- runs/30/30b1-05-personal-after-back.png

**Decision quote.**
> 

**Triage.**

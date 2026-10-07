# 01-017 · Welcome and onboarding: back navigation, skipped optional steps, accessibility labels

- kind: followup-test
- status: triaged
- ticket: 01
- run: w1-20261007T1103Z
- screen: Welcome
- decision: 

**Steps.**
1. On each onboarding page, tap the back arrow: are earlier answers kept when going forward again?
2. Skip every optional field (no name, no gender) and finish: does the plan reveal and signup still work?
3. Tap Continue on the sports page with nothing selected.
4. "I already have an account" from Welcome with a fresh install.
5. VoiceOver labels: in this run the dev overlay reported accessibility issues on Welcome, "Build My Plan" reads as static text (not a button) in the element list, and the Last name field lost its label once text was typed.

**Expected.**
Answers survive back/forward; required steps say what is missing; buttons are exposed as buttons with labels.

**Actual.**
Not run (look-around), apart from the element-list observations in step 5.

**Evidence.**
- runs/01/03-welcome.png
- runs/01/11-personal-filled.png

**Decision quote.**
> 

**Triage.**
retest ticket 30 (retest: auth and account), wave 3 (Lee: all 27 followups into four retest tickets)

# 48-006 · Follow-up: onboarding choice tiles and the doubled Back label with VoiceOver

- kind: followup-test
- status: triaged
- ticket: 48
- run: w5-20261008T1718Z
- screen: Tell us about yourself
- decision: 

**Steps.**
1. With VoiceOver on (device), walk onboarding: Tell us about yourself (MALE / FEMALE / NON-BINARY), Basic body composition
   (Imperial / Metric), Nutrition Settings (LOW / MODERATE / HIGH, LIGHT / MEDIUM / HEAVY).
2. On Sign Up with Email, Log In and Settings, focus the top-left back arrow.

**Expected.**
Each choice is announced as a button (selected or not); the back arrow is announced once as "Back".

**Actual.**
Not run with VoiceOver. `idb ui describe-all` in this run lists those choice tiles as StaticText with no Button trait or selected
state (ui-03.txt shows the sports page uses CheckBox correctly), and the back arrow on Sign Up with Email, Log In and Settings as
`Button 'Back\nBack'`. Ticket 43 covered Build My Plan, the sign-in pills and the consent switch only; those pass.

**Evidence.**
- runs/48/48-11-ob-personal.png
- runs/48/48-23-email-signup.png
- runs/48/ui-35-settings.txt

**Decision quote.**
> 

**Triage.**

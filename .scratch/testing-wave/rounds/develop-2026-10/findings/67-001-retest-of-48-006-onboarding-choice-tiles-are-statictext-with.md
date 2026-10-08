# 67-001 · Retest of 48-006: onboarding choice tiles are StaticText with no selected state, and back arrows read 'Back Back'

- kind: bug
- status: open
- ticket: 67
- run: w7-20261008T2308Z
- screen: Tell us about yourself
- decision: 

**Steps.**
1. Signed out, Build My Plan, walk onboarding to Tell us about yourself (23:11Z).
2. `idb ui describe-all` before and after tapping MALE; then the same on Basic body composition and Nutrition Settings.
3. Also read the top-left back arrow on Sign Up with Email, Settings and Connected Apps.

**Expected.**
Retest of 48-006. Each choice tile (MALE / FEMALE / NON-BINARY, Imperial / Metric, LOW / MODERATE / HIGH, LIGHT / MEDIUM / HEAVY)
is a Button (or CheckBox, as the sports tiles are) with a selected state, so VoiceOver can announce which one is chosen. The back
arrow is announced once as "Back".

**Actual.**
Every tile is `StaticText` with traits `["StaticText", "Scrollable"]` and no selected value, before and after the tap, although the
screen draws MALE as selected (67-10-personal-male.png):
- Tell us about yourself: `StaticText 'MALE'`, `StaticText 'FEMALE'`, `StaticText 'NON-BINARY'` (unchanged after selecting MALE).
- Basic body composition: `StaticText 'Imperial'`, `StaticText 'Metric'`.
- Nutrition Settings: `StaticText 'LOW\n0.7×'`, `'MODERATE\n1.0×'`, `'HIGH\n1.2×'`, `'LIGHT\n0.85×'`, `'MEDIUM\n1.0×'`, `'HEAVY\n1.2×'`.
Sports, goals and pitfalls use `CheckBox … '0'/'1'` correctly. The back arrow still lists as `Button 'Back\nBack'` on Sign Up with
Email, Settings and Connected Apps (onboarding's arrow and Log In choice screen read `Button 'Back'`). No wave-6 ticket touched these
widgets, so this is the 48-006 picture confirmed. VoiceOver itself is a device check (ticket 51).

**Evidence.**
- runs/67/ui-10-personal-info.txt
- runs/67/ui-10b-personal-info-male-selected.txt
- runs/67/67-10-personal-male.png
- runs/67/ui-11-body-composition.txt
- runs/67/ui-12-nutrition-settings.txt
- runs/67/67-12-ob-nutrition-settings.png

**Decision quote.**
> 

**Triage.**


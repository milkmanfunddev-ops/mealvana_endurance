# 119-005 · Unlabelled buttons: Profile & Preferences' bottom back arrow and Sign Up with Email's show-password buttons

- kind: bug
- status: open
- ticket: 119
- run: w36-20260926T0031Z
- screen: Profile & Preferences
- decision: 

**Steps.**
1. Settings > Profile & Preferences; read `idb ui describe-all`.
2. Onboarding > Create Your Account > Sign up with Email; read the tree.

**Expected.**
Every button has a name, like Log In's "Show password".

**Actual.**
1. The orange back arrow left of Save Changes is `Button` with an empty label (20,767 48x48). The top-left back arrow is named "Back".
2. Sign Up with Email's two eye buttons beside Password and Confirm Password are `Button` with empty labels (338,328 and 338,402); the Log In screen's eye button is "Show password".

**Evidence.**
- runs/119/tree-profile-prefs.txt: `Button|||20,767,48x48`
- runs/119/05-hydration-checked-unsaved.png: the orange arrow
- runs/119/notes.md: the Sign Up tree at 00:47Z

**Decision quote.**
> 

**Triage.**

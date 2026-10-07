# 01-012 · Check what a deleted account leaves on the device (prefs and Drift rows)

- kind: followup-test
- status: open
- ticket: 01
- run: w1-20261007T1103Z
- screen: Settings
- decision: 

**Steps.**
1. Sign up, add a meal and an activity, then Settings → Delete Account.
2. On Welcome, read the app's prefs key names (plistlib on `Library/Preferences/com.milkman.mealvanaendurance.dev.plist`, names only) and count rows per Drift table keyed to the deleted id.
3. Sign up again on the same device as a new user; check nothing of the old user shows (meals, activities, targets, name).

**Expected.**
Nothing keyed to the deleted user stays on the device; the next user starts empty.

**Actual.**
Seen in this run (not judged as a bug): after two deletes the prefs still held `flutter.last_sync_timestamp_8fbd939d-...` and `flutter.last_sync_timestamp_6c8552d2-...`, one per deleted user. Drift rows were not checked. The second and third signups showed no carried-over onboarding data.

**Evidence.**
- runs/01/notes.md
- runs/01/40-C-welcome.png

**Decision quote.**
> 

**Triage.**


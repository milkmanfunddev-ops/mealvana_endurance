# 30-012 · Ticket 30's 'simctl spawn defaults delete com.milkman.mealvanaendurance.dev <key>' does nothing on a simulator: use the container plist path

- kind: idea
- status: closed
- ticket: 30
- run: w3-20261008T1255Z
- screen: none
- decision: IMPROVEMENTS entry (#113): simctl defaults delete does nothing on a simulator; use the container plist

**Steps.**
Process idea. `xcrun simctl spawn UDID defaults delete com.milkman.mealvanaendurance.dev flutter.privacy_region_source`
answers "Domain (com.milkman.mealvanaendurance.dev) not found. Defaults have not been changed." (13:05:59Z): the
simulator's `defaults` looks in its own global domain, not the app container. What works:
`xcrun simctl spawn UDID defaults delete "$(xcrun simctl get_app_container UDID com.milkman.mealvanaendurance.dev data)/Library/Preferences/com.milkman.mealvanaendurance.dev" <key>`
(and the same path for `defaults write`/`read`), with the app terminated. Put the path form in the runbook (step 5) and
in any ticket that writes prefs, and have the agent read the keys back after every write.

**Expected.**
A ticket's device-only prefs write does what it says.

**Actual.**
The first relaunch of 7(i) ran on the warm `geo` cache because the deletes had silently not happened; caught by
reading the plist back, then redone with the path form.

**Evidence.**
- runs/30/prefs-30b7i-before.txt
- runs/30/prefs-30b7i-after-failed-lookup.txt

**Decision quote.**
> 

**Triage.**

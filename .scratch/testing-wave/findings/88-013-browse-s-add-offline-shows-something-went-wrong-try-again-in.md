# 88-013 · Browse's Add offline shows Something went wrong. Try again. instead of a connection message

- kind: bug
- status: open
- ticket: 88
- run: w29-20260925T1949Z
- screen: Browse meals
- decision: 

**Steps.**
1. Retest of 18-008 step 1. Conversation `0401b3d8` > plus > Browse meals (online). Netcut on (20:19:15Z). Tap "+" on Oats, bread, orange & black coffee.

**Expected.**
18-008: the "needs connection" warning, no tick, no row.

**Actual.**
A pink toast "Something went wrong. Try again.", no tick, no row (right on data, wrong words). Caveat: under netcut the app's connectivity check still reads online (20-006), so this is the network-error path; a device may show the connection message.

**Evidence.**
- runs/88/89-18-008-offline-add-1s.png
- runs/88/db-18-18-008-offline-add.txt

**Decision quote.**
> 

**Triage.**

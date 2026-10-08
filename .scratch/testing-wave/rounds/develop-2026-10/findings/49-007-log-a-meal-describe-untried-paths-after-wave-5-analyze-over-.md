# 49-007 · Log a Meal Describe: untried paths after wave 5 (Analyze over 2000 characters, double-tap Analyze, Gallery pick with location, camera denied)

- kind: followup-test
- status: triaged
- ticket: 49
- run: w5-20261008T1719Z
- screen: Log a Meal (Describe tab)
- decision: 

**Steps.**
1. Type more than 2000 characters (the field has no cap; 1000 went in fine) and Analyze. From code, describe-meal answers 400 before the credit check and the app shows "The AI service returned an error. Please try again." Check the message tells the athlete the text is too long, and that no token is charged. Spend first.
2. Double-tap Analyze fast with new text: one call and one debit (ticket 45's `_inFlight` join)?
3. Camera with permission denied (Settings > Endurance Dev > Camera off): which message shows?
4. The iOS picker reads "Location Is Included": attach a photo that carries GPS and check whether the uploaded `meal-photos` object keeps it (the app re-encodes at 1000 px, which may drop it).

**Expected.**
A long text says it is too long and costs nothing; a double tap charges once; a denied camera explains itself; uploaded meal photos carry no location.

**Actual.**
Not run: steps 1 and 2 need AI spends beyond this ticket's three; 3 and 4 were outside the ticket's checks.

**Evidence.**
- runs/49/40b-long-text-again.png — 1000 characters in the field, no cap
- runs/49/41-gallery-with-photo.png — the picker's "Location Is Included"

**Decision quote.**
> 

**Triage.**

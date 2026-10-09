# 68-018 · First barcode lookup of 12345670 timed out on the client after 30 s with no request reaching the server

- kind: bug
- status: triaged
- ticket: 68
- run: w7-lead-20261008T2354Zw7-lead-20261008T2354Z
- screen: Log a Meal > Scan barcode > Enter a barcode
- decision: 

**Steps.**
1. Signed in as test@test.com on wave-pool-2, camera access revoked. Log a Meal → Scan barcode → Enter → type 12345670 → Look it up.
2. Watch the console and the dev edge logs for lookup-product.

**Expected.**
One lookup-product request answers within seconds; a found product opens Log Food, an unknown one says so.

**Actual.**
Filed by the wave lead from runs/68/notes.md check 12. At 23:41:08Z the first lookup of 12345670 hung ~30 s, ended in a client SocketException timeout, showed the dialog "Error / Unable to connect to product lookup service" with two `error_reported`, and "Try Again" only returned to the scanner. The lead's edge extract for 23:05–00:00Z has NO lookup-product request line at 23:41Z (the only lookup-product line is the 404 at 23:43:02Z); the second try at 23:42:31Z found "McEnnedy Double burger". The request never left the device or never reached the gateway; a 30 s client wait on a cold function with no retry is what the athlete saw.

**Evidence.**
- runs/68/notes.md check 12 (12345670 first try)
- runs/lead-wave7/edge-wave7-2305-0000.txt (no request line at 23:41Z)
- runs/68/console-redacted.log (SocketException at 23:41Z)

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 79 (describe-meal 400 and lookup-product 404 get their own copy as expected outcomes; the lookup wait is bounded with one retry), fix wave 8 · Lee, 2026-10-09

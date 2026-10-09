# 68-007 · Barcode Enter with an unknown code: the server answers 404 not found, the app says 'Unable to connect to product lookup service' and reports a fault

- kind: bug
- status: triaged
- ticket: 68
- run: w7-20261008T2309Z
- screen: Log a Meal > Scan barcode > Enter > Look it up
- decision: 

**Steps.**
1. Retest of 50-013 (check 12). Log a Meal > Scan barcode (camera access off) > Enter.
2. Typed 98765432109871 (a made-up code), Look it up at 23:43:00Z.

**Expected.**
The 'Product Not Found' dialog (with Create Manually), barcode_lookup_failed {reason: not_found}, and no error_reported: an unknown code is an expected answer.


**Actual.**
Dialog 'Error / Unable to connect to product lookup service' with Try Again / Cancel / Create Manually. lookup-product answered POST 404 at 23:43:02.438 after 'No product found', so the service was reachable. Console: error_reported {severity: degraded, ProductDetailException, sentry 7cb7faf2…} and error_reported {severity: fault, area: barcode_scanning, exception_type: FunctionException, sentry 83cdf137…}. An athlete is told the network failed when the food is simply not in the databases, and every unknown barcode raises a fault in Sentry. 'Try Again' goes back to the scanner rather than retrying. Also seen: the first lookup of 12345670 at 23:41:08Z timed out client-side after ~30 s (SocketException errno 60, no request in the edge logs) with the same dialog and two error_reported; the same code succeeded at 23:42:31Z ('McEnnedy Double burger'), so that one was a transient socket failure.


**Evidence.**
- runs/68/12k-unknown-barcode-made-up.png: the dialog for the 404.
- runs/68/edge-check12-barcode.txt: the 404 and the earlier 200s.
- runs/68/12h-unknown-barcode-result-later.png: the same dialog after the client timeout.
- runs/68/console-redacted.log: error_reported lines at 18:41:38 and 18:43:0x local.

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 79 (describe-meal 400 and lookup-product 404 get their own copy as expected outcomes; the lookup wait is bounded with one retry), fix wave 8 · Lee, 2026-10-09

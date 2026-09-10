# 03: Coverage, and catalog reads without a login

**What to build:** A shopper learns whether Kroger can serve them before being asked to authorize
anything, and a shopper Kroger cannot serve is never offered the feature at all.

Location and product reads move from the shopper's token to the application token. Kroger requires
no scope for Locations and only a basic product scope for Products; only the cart write needs the
shopper. This is what makes a pre-authorization Coverage check possible, and it removes the
dependency that made the feature untestable — Kroger's certification environment is unreachable
from outside their network, so anything requiring a shopper could only ever be exercised against
production.

Where no Location serves the area at the requested Modality, the entry point into Shop with Kroger
is not shown.

**Blocked by:** 01

**Status:** built, awaiting device verification (2026-09-10)

- [x] Location and product reads use the application token — one cached
      `client_credentials` token per isolate, `product.compact` only
- [x] The cart write still uses the shopper's token, and nothing else does. The
      customer authorization no longer asks for `product.compact` either
- [x] Coverage can be determined for an area with no shopper account connected —
      a new `coverage` action, needing no Kroger authorization
- [x] Where Coverage is empty, the entry point into the feature is not shown
- [x] A shopper who has never connected Kroger can still be told whether Kroger
      serves them
- [x] Server tests cover both token paths at the service seam

**Coverage is presence, not fulfillment.** Kroger's Locations API has no
fulfillment filter, and a Location's own booleans are not Location-truthful, so
Coverage answers "is there a Location near this area at all". Whether that
Location will deliver a given product is the filtered product search's answer
and stays with the matching run.

**Unknown is not "no".** A Coverage check that fails — rate limited, Kroger
down, not configured — leaves the entry point in place. Taking the feature away
from someone Kroger can serve because a check failed is the worse error. The
entry point is withheld only while the check is unanswered and once it answers
zero, so an uncovered shopper never sees it appear and vanish.

**Coverage stays behind Pro.** It was briefly let past the entitlement gate, on
the reasoning that the offer it gates is what sells Pro. Review caught the cost:
Kroger meters Locations per application per day, so that would put a resource
every paying shopper shares behind nothing but `claim_kroger_request` — a
60-per-minute burst guard, not a daily cap — for any authenticated account. A
non-entitled shopper is told Pro is required, and their unanswered Coverage
check leaves the entry point in place. Revisit if a per-action daily cap is ever
worth the migration.

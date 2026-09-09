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

**Status:** ready-for-agent

- [ ] Location and product reads use the application token
- [ ] The cart write still uses the shopper's token, and nothing else does
- [ ] Coverage can be determined for an area with no shopper account connected
- [ ] Where Coverage is empty, the entry point into the feature is not shown
- [ ] A shopper who has never connected Kroger can still be told whether Kroger serves them
- [ ] Server tests cover both token paths at the service seam

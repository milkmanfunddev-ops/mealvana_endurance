# 01: Declare Kroger content keys

**What to build:** No visible change. Kroger's user-facing copy is declared in the shared content
key registry the way every other feature declares it, instead of being assembled from bare strings
at each call site. This is a prefactor: every later ticket in this feature edits this copy, and
doing it once up front avoids resolving the same churn six times.

The trick of detecting a missing key by comparing a returned value against the key itself is
removed — a miss is handled explicitly.

**Blocked by:** None (can start immediately)

**Status:** done (2026-09-09)

- [x] Every Kroger content key is declared as a typed constant in the shared registry
- [x] No Kroger string is looked up by interpolating a namespace with a bare literal
- [x] A missing key is detected without comparing a value to its own key
- [x] Keys that are defined but referenced nowhere are either used or deleted, deliberately, not left dead
      — `find` and `find_stores` deleted (the flow submits with the shared `continue` label);
      `all_skipped` kept and documented, because ticket 02 reports with it next
- [x] The two screen-reader-only labels on the quantity control are content, not literals
- [x] Existing Kroger tests pass unchanged; no user-visible behaviour differs

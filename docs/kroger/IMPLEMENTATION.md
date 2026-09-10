# Kroger shopping: implementation

## Product boundary

The public API adds **products to a cart**, not ingredient text to a two-way
shopping list. The public API reference exposes no cart read, removal, quantity
replacement, checkout or store-selection endpoint. Mealvana therefore owns an
editable pre-export draft; Kroger owns the cart and checkout after handoff.

The first version allows **one handoff per user / meal plan / API environment**.
This is deliberately stricter than add-on shopping: after a sent or ambiguous
handoff, edits happen in Kroger. It avoids treating an additive operation as
an update, and avoids duplicating groceries after timeouts. This limit is shown
before confirmation. A later additive-batch feature needs an explicit user-reviewed
delta workflow, not a generic “sync cart” button.

## Shopper flow

1. Open Shopping → the compact cart-icon **Shop with Kroger** button above the
   groceries (visible on dev; production release flag required). It opens review,
   never sends the list without confirmation.
2. Connect the customer's Kroger account in a native browser session.
3. Find a store by ZIP and select pickup/delivery. This controls catalog search,
   **not** Kroger's cart location; the shopper must select that same store in Kroger.
4. Suggest products for the source list. Show ingredient requirement separately
   from retailer package size, price and package count. Previously approved
   products are preferred when returned and available, but never auto-approved.
5. Search for alternatives, change products, edit package counts, skip/include
   lines, or add an extra item. Approve each included line explicitly.
6. Confirm the handoff. Sync the draft with server acknowledgment, reconcile
   source changes, recheck current products/prices/sizes, then send approved UPCs.
   Any changed product requires another review before a cart write.
7. Show a historical receipt. Open the production Kroger cart for final edits,
   availability, store, substitutions, fees and checkout. Certification never
   opens a production-cart link as if a test add were a real order.

## Matching and quantities

Search is store- and fulfillment-specific. The server ranks returned candidates
by ingredient-name overlap, availability and form mismatches (e.g. dried vs fresh).
This is a suggestion heuristic, not semantic or dietary verification. Products
must be individually approved; no LLM invents UPCs or silently makes substitutions.
The API does not guarantee complete allergen labels. The shopper must check labels;
the matching system must not claim an item is allergy-safe.

Safe package conversions cover compatible mass, volume and explicit counts,
including simple fractions and compatible compound quantities. For example,
600 g / a 1 lb package suggests 2 packages. Cups-to-mass, cooked-to-dry,
variable-weight produce, unparsed multipacks, and ambiguous sizes require human
review. Package counts are integers 1–99. Repeated UPCs are aggregated on export;
aggregate counts above 99 and handoffs over 100 input lines are rejected.

The retailer overlay never rewrites meal nutrition or recipe quantities.
Source IDs derive from plan ID + normalized ingredient name because the current
shopping model has no line ID. Source quantity changes revoke approval; source
have/checked changes propagate, add-back works, manually skipped lines persist
while the source is unchanged, and removed source lines disappear. Manual extra
items survive regeneration. Exported snapshots no longer follow source changes.

The source grocery builder can collapse preparation distinctions; matching
cannot recover information absent from that source. Mandatory review is intentional.

## Code and data

- `lib/features/kroger/domain/`: typed store/product/line/draft overlay.
- `application/`: matching/conversion, AsyncNotifier orchestration, rollout flag.
- `data/`: account/plan-scoped SharedPreferences persistence, dirty/revision
  tracking, explicit on-demand sync and Supabase API/RPC calls.
- `presentation/`: review screen and dialogs; copy comes from content defaults.
- `supabase/functions/kroger/`: authenticated POST endpoint with shared Pro
  entitlement policy, rate limiting, sanitized errors and no credential logging.
- `_shared/kroger/`: upstream client, catalog normalization, OAuth and export service.
- `20260907120000_kroger_shopping.sql`: isolated owner-scoped tables and RPCs.

Drafts save locally first. Cloud writes compare revision numbers so stale devices
cannot overwrite a newer draft. In-flight local edits survive sync; duplicate sync
calls share one upload. Conflicts require explicit confirmation before loading
the cloud version. Preferred-product hints are currently device-local; draft
selections themselves sync. Signing out does not expose another account's draft
keys, and in-flight controller work is invalidated on account changes.

Two tokens, and they buy different things. Locations and Products are read with
an application `client_credentials` token — Locations needs no scope, Products
needs only `product.compact`, and neither needs to know who is asking. The
shopper's own token pays for the cart write and for nothing else, which is what
lets Coverage ("does Kroger serve this area at all?") be answered before anyone
has authorized Mealvana, and what keeps the catalog path testable: Kroger's
certification environment is unreachable from outside their network, so anything
needing a shopper can only ever be exercised against production. The customer
authorization request therefore asks for `cart.basic:write profile.compact`;
`product.compact` is registered for the application credential, not the shopper.

`kroger_connections` and `kroger_oauth_sessions` have no authenticated/anon grants.
Only the server can read tokens, exchange OAuth codes, refresh, or reserve receipts.
Token refresh uses a conditional expiring lease to prevent concurrent refreshes.
Disconnect deletes stored tokens and pending sessions even if Pro expires or
the server rollout flag is disabled; it does not revoke the grant on Kroger's site.

Exports reserve a unique durable `sending` receipt before the non-retried PUT.
204 becomes `sent`; timeout/upstream failure becomes `unknown`. If persisting
the outcome fails, `sending` remains and still blocks another send. A receipt is
not a claim about current cart contents, and application-side uniqueness cannot
offer exactly-once semantics inside Kroger. Never delete an ambiguous receipt to
“fix” a stuck export without reviewing the customer's cart.

A second send is the shopper's own decision, taken through a confirmation that
says what an add-only cart does with it, and reaches the server as
`resend: true` on the export body — the only thing that gets past the existing
receipt, and only over a `sent` one. A `sending` receipt may still be in flight
and an `unknown` one cannot say what reached the cart, so neither is offered a
second send: those are settled in the customer's cart, in Kroger. The resend
takes the `sent` receipt over in place, claimed by the id and status that were
read, so there is never a moment with no durable row. The items the first send
added stay in the cart, because Kroger offers no way to take them out.

After a `sent` receipt the shopper is handed off to `kroger.com/cart`: the
Kroger app when it is installed (`externalNonBrowserApplication`), the system
browser when it is not. The OAuth step does not ask for an ephemeral browser
session, so the sign-in the shopper completed there is the one the browser
already holds and the Hand-off does not ask for a second. A Hand-off that
cannot open Kroger is not a failed send and is never reported as one.

Certification and production receipts are isolated. Switching API environments
clears old store/product approvals while preserving ingredient rows for review.
The feature uses the existing Pro gate, including its documented dev/internal bypass.

## Not implemented / launch checks

- Web OAuth and an HTTPS callback (current registration is native only).
- Production approval and production credentials.
- Android-dev redirect registration; its manifest scheme differs from the current registration.
- Live customer OAuth, token refresh and approved test-cart addition on devices.
- Confirm cart modality values, test-account behavior and store selection in Kroger's
  certification UI. The public example gives modality as a string; pickup/delivery
  must pass the live test before rollout.
- Two-way cart edits, checkout, coupon handling, substitution preferences, and
  additive exports after the first handoff.
- A global upstream quota budget/caching strategy before broad rollout. The
  implemented per-user request limiter is not a substitute for app-wide API quotas.
- Review local-draft retention/account-deletion policy and provider terms before
  launch; OAuth tokens are server-only but selected groceries persist locally.

Reference: [Kroger Public APIs](https://www.postman.com/kroger/the-kroger-co-s-public-workspace/documentation/ki6utqb/kroger-public-apis).

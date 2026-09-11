# 02: Delivery-first matching, on real Kroger payloads

**What to build:** The bug. A shopper in a delivery-only market taps "Find product matches" and
gets actual groceries instead of silence.

A new draft's Modality is `DELIVERY`. The server maps Modality to Kroger's fulfillment filter, and
availability is derived from whether the filtered search returned the product — never from the
per-item fulfillment booleans, which claim curbside is available at a Spoke where the curbside
filter returns nothing. A product with no price stays priceless rather than becoming zero.

Alongside it, the screen stops lying about failure. The state's message survives the initial load,
so each cause says its own thing rather than every failure rendering as "Kroger shopping is being
set up". A matching run that matched nothing says so. A run where every line was already ticked
says something different again. Controls that cannot act are not rendered at all, and no control
is labelled with error copy.

Hand-written product fixtures are replaced with payloads captured from Kroger production on
2026-09-08 — a Spoke response with no price field and misleading fulfillment flags, a Store
response with a price and sold-by-weight, a single-Location response, and an empty one. The repo's
seam rule requires producer-shaped fixtures, and the invented fixture is what hid this bug.

**Also in this ticket, and deliberately early: prove the cart write.** No item has ever reached a
real Kroger cart from this app. Send one item to a real account by hand and confirm it arrives. If
it does not, every ticket after this one is being built on an assumption.

**Blocked by:** 01

**Status:** matching verified on the iOS simulator against Kroger production (2026-09-10); cart write not yet done (needs Lee); legacy-PICKUP-draft defect, see `../device-verification.md`

- [x] A new draft defaults to `DELIVERY`
- [x] Delivery Modality maps to Kroger's delivery-to-home filter; pickup maps to curbside
      — one `fulfillmentFilter()`, now also on the by-UPC lookup the export preflight uses,
      which had no filter at all
- [x] Availability comes from the filtered result, not from per-item fulfillment flags
      — `productFromApi` no longer takes a Modality; the caller owes it a filtered request
- [x] A product with no price is represented as having no price, never zero
- [~] Fixtures are real captured Kroger payloads, including the priceless Spoke response
      — every field the spec records is reproduced, but from the spec's record, not from the
      probe's bytes, which were not kept. See the note below. The hand-written product with a
      price and `available: true` is gone either way.
- [x] A failure reason survives the initial load and reaches the screen
      — `KrogerState.copyWith` was dropping `message` on every copy; it now carries like every
      other field, with an explicit `clearMessage`, and each action clears it as it starts
- [x] Pro-required, rate-limited, reconnect-required and not-configured each produce distinct copy
- [x] A run that matched nothing reports that it matched nothing
- [x] A run with no eligible lines reports that nothing was selected
- [x] No control renders in a state where tapping it does nothing
- [x] No control is labelled with an error message
- [x] Verified in a delivery-only market: matches return real products — iOS simulator against
      Kroger production, Birmingham Spoke, 11 of 13 lines (2026-09-10)
- [ ] Verified by hand: one item sent to a real Kroger account arrives in that cart

## Notes

**The two device checks are Lee's.** Both need a real Kroger Production account on a device, and
the cart write has never been exercised from this app — it is the one genuinely unknown step and
everything after this ticket assumes it works. The ticket is not done until they pass.

Before verifying, clear any draft already on the device: `DELIVERY` is the default for a *new*
draft, and a draft saved before this change keeps the `PICKUP` it was stored with, which would
fail exactly as before and read as the fix not working. Choosing the Location again sets the
modality; ticket 04 removes the stored-modality question entirely.

**The fixtures are reconstructions, not transcriptions.** The literal bytes of the 2026-09-08
probe were not kept in the repo. Every field the spec records — stock level, size, `soldBy`, the
fulfillment booleans, the presence or absence of `price`, one Location with zero departments — is
reproduced exactly; identifiers, addresses and image URLs are representative.
`supabase/functions/_shared/kroger/fixtures/README.md` says so at the fixtures.

**Review found a hole I had opened.** Gating the snackbar on availability silenced every later
failure for an unavailable session — a rate limit hit while the body already read "Pro is
required" would have gone nowhere. It is now suppressed only when the body is showing those
exact words, with a test.

**Two judgment calls on "no control renders in a state where tapping it does nothing".**
Removed: the Send button until the draft is ready, the Choose-product button without a Location
or a connection, the Approve button once approved or when the product cannot be had. Kept as
disabled: the package steppers at 1 and 99, and Refresh while a request is in flight. A stepper
end shows a range and a busy control shows work in progress; neither is a dead control that
teaches a shopper nothing. Say so if you disagree — it is one `if` either way.

**One repair on the send path, forced by this ticket.** Putting a fulfillment filter on the
by-UPC lookup — which this ticket requires — turns a product the Location no longer serves into
an absent response, and the export preflight would have failed the whole send on it. It now
becomes a `changed` line instead, which is where an unavailable product already went. This is
holding the send path still, not designing it; how that line reads is ticket 05's, and until
then it shows with an empty product name.

**Not touched.** The dialog race noted at the end of ticket 01 still belongs to ticket 05.

**`docs/kroger/DEPLOYMENT.md`** had customer OAuth as never attempted. Corrected to match the
spec's Further Notes: done on iOS, cart write still never exercised.

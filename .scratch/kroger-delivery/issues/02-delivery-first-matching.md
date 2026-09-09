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

**Status:** ready-for-agent

- [ ] A new draft defaults to `DELIVERY`
- [ ] Delivery Modality maps to Kroger's delivery-to-home filter; pickup maps to curbside
- [ ] Availability comes from the filtered result, not from per-item fulfillment flags
- [ ] A product with no price is represented as having no price, never zero
- [ ] Fixtures are real captured Kroger payloads, including the priceless Spoke response
- [ ] A failure reason survives the initial load and reaches the screen
- [ ] Pro-required, rate-limited, reconnect-required and not-configured each produce distinct copy
- [ ] A run that matched nothing reports that it matched nothing
- [ ] A run with no eligible lines reports that nothing was selected
- [ ] No control renders in a state where tapping it does nothing
- [ ] No control is labelled with an error message
- [ ] Verified on a real device in a delivery-only market: matches return real products
- [ ] Verified by hand: one item sent to a real Kroger account arrives in that cart

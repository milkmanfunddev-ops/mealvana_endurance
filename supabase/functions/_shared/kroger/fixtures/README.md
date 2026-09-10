# Kroger payload fixtures

Producer-shaped responses from Kroger's Products and Locations APIs, standing in
for the upstream in the Deno suite and — reduced to the edge function's own
`Product` shape — in the Flutter seam tests.

They reproduce a probe run against Kroger **production** on 2026-09-08 with an
application token, recorded in `.scratch/kroger-delivery/spec.md`: postcode
35209 returns exactly one Location, a Spoke with zero departments, and the
identical product query there returns 0 results under the curbside filter and 5
under delivery. The fields the spec names — stock level, size, `soldBy`, the
fulfillment booleans, and the presence or absence of `price` — are reproduced
exactly. The surrounding envelope is Kroger's documented response shape; the
verbatim bytes of that run were not kept, so identifiers, addresses and image
URLs here are representative rather than transcribed.

The point of each file:

- `spoke_product.json` — the Spoke. **No `price` field at all**, and
  `fulfillment.curbside` is `true` for an item the curbside filter will not
  return. Believing those booleans is the bug this feature was built on;
  availability is derived from the filtered result instead.
- `store_product.json` — the same item id at a real Store: a price, a different
  pack size, and `soldBy: "WEIGHT"`. Proves price is data about a Location,
  never about a product.
- `locations_delivery_only.json` — one Location, zero departments: a market
  Kroger serves by delivery only.
- `locations_empty.json` — a market Kroger does not serve at all. Coverage
  reads this as "no", and the entry point into Shop with Kroger is not shown.

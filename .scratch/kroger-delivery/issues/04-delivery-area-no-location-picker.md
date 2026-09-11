# 04: Delivery area, no Location picker

**What to build:** The shopper never sees a Location again. The screen says where their groceries
are going — "Delivery to 35209" — and nothing about a facility, a name or an address.

The delivery area comes from the device's location on first use, using the app's existing shared
location service. If the shopper declines the permission or resolution fails, they type a postcode
once. The same typed path is how they correct the area later, having moved or travelled.

The Location is resolved from the area and the Modality together and persisted on the draft. The
shopper's coordinates and postcode are not persisted for Kroger purposes: Kroger's acceptable-use
terms prohibit storing data about a customer's location.

Pickup remains representable in the model and on the wire. It is not on the critical path here.

**Blocked by:** 03

**Status:** typed-postcode path verified on the iOS simulator (2026-09-10); device path fails, reverse-geocode defect, see `../device-verification.md`

- [x] The screen presents the delivery area, never a Location name or address
- [x] No Location list is shown anywhere in the flow
- [x] The area resolves from device location without the shopper being asked to choose
- [x] Declining the location permission leaves a working typed-postcode path
- [x] The shopper can change their delivery area afterwards
- [x] The resolved Location is persisted; coordinates and postcode are not
- [x] A Location that cannot serve the requested Modality is never selected

**Built in** `70a71e58`. Notes for whoever verifies on a device:

- The area resolution is scheduled after the build future, not awaited, so the screen appears
  before the device fix. Watch for the delivery line filling in a beat late.
- The postcode is not persisted, so a shopper who declines the location permission is asked to
  type it again on each load. The Location they resolved earlier survives, and matching still
  works before they do.
- The Modality probe is a delivery-filtered search for "milk" at each candidate Location, capped
  at three candidates. Confirmed against production on 2026-09-08: 5 results at the Birmingham
  Spoke under `dth`, 0 under `csp`.
- Coverage is still presence-only (ticket 03's design, and the Locations endpoint has no
  fulfillment filter). A market with Locations but none that deliver therefore passes Coverage and
  then reports "Kroger does not deliver to that ZIP code" — honest, but not a vanish.
- Goldens for this screen are deliberately not here: ticket 07 rebuilds it from the design system.

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

**Status:** ready-for-agent

- [ ] The screen presents the delivery area, never a Location name or address
- [ ] No Location list is shown anywhere in the flow
- [ ] The area resolves from device location without the shopper being asked to choose
- [ ] Declining the location permission leaves a working typed-postcode path
- [ ] The shopper can change their delivery area afterwards
- [ ] The resolved Location is persisted; coordinates and postcode are not
- [ ] A Location that cannot serve the requested Modality is never selected

# 08: The device finds the delivery area where LocationIQ answers with an address point

**What to build:** A shopper who allows location access sees "Delivery to 35209" without typing
anything, in Birmingham and wherever else LocationIQ's reverse lookup lands on an address point.
Today the device path fails in most US places, and every shopper there retypes a postcode on every
load.

Found on the 2026-09-10 simulator pass (`../device-verification.md`, defect 1; screenshot
`../evidence/2026-09-10/14-device-location-geocode-fails.png`).

**Blocked by:** None (can start immediately)

**Status:** built 2026-09-10 (`a8f15741`). Device area verified on the simulator on 2026-09-11.
"Matching then works" was not exercised: this plan's list was already sent, so matching is hidden,
and reopening it would take a second cart write.

`location_iq` 1.1.4 is the latest on pub.dev, so `LocationRepository.reverseGeocode` now makes
the request and decodes it itself, returning `ReversePlace` (`lib/shared/domain/`). Two more
things the live probe found: the package sends `addressdetails=0`, and with it LocationIQ leaves
out the `address` block and the postcode with it, so the request now asks for `1`; and the live
Homewood response omits `osm_type`/`osm_id` entirely rather than sending null. Fixtures in
`test/fixtures/location_iq/`, captured 2026-09-10.

## What happens

`krogerAreaFinder` (`lib/features/kroger/application/kroger_controller.dart`) asks
`LocationService.reverseGeocodeCoordinates`, which goes through
`LocationRepository.reverseGeocode` (`lib/shared/data/repositories/location_repository.dart`) to
the `location_iq` 1.1.4 package. That package's `LocationIQReverseResult` declares `osmType` and
`osmId` as non-null `String`. LocationIQ returns both as `null` when the match is one of its own
address points rather than an OSM object, so decoding throws:

```
Exception: Failed to reverse geocode coordinates: type 'Null' is not a subtype of type 'String' in type cast
```

The finder turns the throw into `null`, as designed, and the screen falls back to "We could not
tell where you are". The response it failed to decode had the answer in it. Captured from
`us1.locationiq.com/v1/reverse` for 33.47, -86.80 on 2026-09-10:

```json
{
  "place_id": "331739302909",
  "licence": "https://locationiq.com/attribution",
  "osm_type": null,
  "osm_id": null,
  "lat": "33.47003",
  "lon": "-86.800165",
  "display_name": "318, West Glenwood Drive, Homewood, Jefferson County, Alabama, 35209, USA",
  "address": {
    "house_number": "318", "road": "West Glenwood Drive", "city": "Homewood",
    "county": "Jefferson County", "state": "Alabama", "postcode": "35209",
    "country": "United States of America", "country_code": "us"
  },
  "boundingbox": ["33.47003", "33.47003", "-86.800165", "-86.800165"]
}
```

Of six US coordinates probed, four came back with null `osm_type`/`osm_id`: all three in
Birmingham, plus downtown Cincinnati. San Francisco and Boston returned OSM objects and decode fine.

The Kroger area finder is the only caller of `reverseGeocodeCoordinates` in `lib/`.

## Direction

Stop depending on the package's strict reverse model for a postcode. Read `address.postcode` from
the reverse response without requiring the OSM fields, either with a small decoder of our own
behind `LocationRepository.reverseGeocode` or with a newer `location_iq` if one makes those fields
nullable. Check pub.dev before writing the decoder. The fix belongs in the shared layer, not in the
Kroger controller.

## Acceptance

- [x] The reverse lookup succeeds on a response with `osm_type: null` and `osm_id: null`, and
      yields postcode `35209`
- [x] A seam test feeds the captured payload above, producer-shaped (not the app's own output),
      and asserts the Kroger area finder returns `35209`
- [x] A response with OSM fields still decodes (keep a San Francisco- or Boston-shaped case)
- [x] A response with no postcode still ends on the typed path, not an error
- [x] On the simulator at 33.47, -86.80 with location allowed, the Kroger screen shows "Delivery
      to 35209" without the shopper typing, and matching then works
      *(2026-09-11, iPhone 17 Pro, dev app from `a8f15741`: "Delivery to 35209" on a fresh launch
      with nothing typed, and no reverse-geocode error in the run log. Screenshot
      `../evidence/2026-09-11/01-device-area-35209-untyped.png`. The matching half is **not
      verified**: the draft for this plan is `sent`, the screen draws no match button on an exported
      draft, and "Send these items again" is a real cart write. It needs an unsent plan. The
      Location an area resolves to was proven to match at the Spoke on 2026-09-10, on the typed
      path, and the device path now hands the same `35209` to the same resolution.)*

/// LocationIQ `/v1/reverse` bodies, captured from `us1.locationiq.com`.
///
/// Producer-shaped on purpose (`docs/test/README.md`, Seam tests): each file
/// is what LocationIQ sent, not what the app decodes it into. Captured
/// 2026-09-10. `reverse_address_point_null_osm_35209.json` is the payload from
/// Kroger ticket 08, verbatim; the rest are live responses to the same query
/// the app makes.
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _dir = 'test/fixtures/location_iq';

/// An address point in Homewood, AL, with `osm_type` and `osm_id` null — the
/// shape `location_iq` 1.1.4 cannot decode.
const addressPointNullOsm = 'reverse_address_point_null_osm_35209';

/// The same address point as it came back live, with the OSM keys absent.
const addressPointNoOsmKeys = 'reverse_address_point_no_osm_keys_35209';

/// San Francisco City Hall: an OSM relation, the shape that always decoded.
const osmObject = 'reverse_osm_object_94102';

/// Monroe County, FL (25.0, -81.0): a real place with no postcode.
const noPostcode = 'reverse_no_postcode_monroe_county';

/// LocationIQ's 404 for a point it cannot place (-80.0, 0.0).
const unableToGeocode = 'reverse_error_unable_to_geocode';

/// A LocationIQ that answers every request with one captured body, and keeps
/// the requests so a test can see what was asked.
MockClient locationIqAnswering(
  String name, {
  int status = 200,
  List<http.Request>? requests,
}) => MockClient((request) async {
  requests?.add(request);
  final file = File('$_dir/$name.json');
  if (!file.existsSync()) {
    throw StateError(
      'Missing ${file.path}. Run flutter test from the repo root.',
    );
  }
  return http.Response.bytes(
    file.readAsBytesSync(),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

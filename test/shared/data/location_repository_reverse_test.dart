import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/shared/data/repositories/location_repository.dart';
import 'package:mealvana_endurance/shared/domain/reverse_place.dart';

import '../../fixtures/location_iq_fixtures.dart';

/// A reverse lookup of 33.47, -86.80 against a LocationIQ that answers with
/// one captured body. The fake ignores the coordinates; the body decides.
Future<ReversePlace> reverse(
  String payload, {
  int status = 200,
  List<http.Request>? requests,
}) => LocationRepository(
  apiKey: 'test-key',
  httpClient: locationIqAnswering(payload, status: status, requests: requests),
).reverseGeocode(latitude: 33.47, longitude: -86.80);

void main() {
  group('reverseGeocode', () {
    test('an address point with null OSM fields yields its postcode', () async {
      expect((await reverse(addressPointNullOsm)).postcode, '35209');
    });

    test('an address point with no OSM keys yields its postcode', () async {
      expect((await reverse(addressPointNoOsmKeys)).postcode, '35209');
    });

    test('an OSM object still decodes', () async {
      expect((await reverse(osmObject)).postcode, '94102');
    });

    test('a place with no postcode decodes to none', () async {
      expect((await reverse(noPostcode)).postcode, isNull);
    });

    test('a point LocationIQ cannot place throws', () async {
      await expectLater(reverse(unableToGeocode, status: 404), throwsException);
    });

    test('a failed request says nothing about where the shopper is', () async {
      // The error is logged. `ClientException` prints the request URI, which
      // carries the coordinates and the API key.
      final repository = LocationRepository(
        apiKey: 'test-key',
        httpClient: MockClient(
          (request) async =>
              throw http.ClientException('Connection reset', request.url),
        ),
      );

      final error = await repository
          .reverseGeocode(latitude: 33.47, longitude: -86.80)
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isException);
      expect('$error', isNot(contains('33.47')));
      expect('$error', isNot(contains('test-key')));
    });

    test('asks for the address details, which carry the postcode', () async {
      // Without `addressdetails=1` LocationIQ leaves out the `address` block,
      // and with it the postcode. `location_iq` 1.1.4 sends 0.
      final requests = <http.Request>[];
      await reverse(addressPointNullOsm, requests: requests);

      final uri = requests.single.url;
      expect(uri.host, 'us1.locationiq.com');
      expect(uri.path, '/v1/reverse');
      expect(uri.queryParameters, {
        'key': 'test-key',
        'lat': '33.47',
        'lon': '-86.8',
        'format': 'json',
        'addressdetails': '1',
        'accept-language': 'en',
      });
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/kroger/application/kroger_controller.dart';
import 'package:mealvana_endurance/features/weather/domain/location.dart';
import 'package:mealvana_endurance/shared/data/repositories/location_repository.dart';
import 'package:mealvana_endurance/shared/services/location_service.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

import '../../fixtures/location_iq_fixtures.dart';

/// The device's fix is the one thing stubbed: geolocator talks to a platform
/// channel. Everything after it — the shared service, the repository, the
/// decoding — is the real code, fed what LocationIQ sent.
class FixedPositionLocationService extends LocationService {
  FixedPositionLocationService({
    required super.logger,
    required super.locationRepository,
  });

  @override
  Future<Location?> getCurrentLocation() async =>
      const Location(latitude: 33.47, longitude: -86.80);
}

Future<String?> areaFromDevice(String payload, {int status = 200}) {
  final container = ProviderContainer(
    overrides: [
      locationRepositoryProvider.overrideWithValue(
        LocationRepository(
          apiKey: 'test-key',
          httpClient: locationIqAnswering(payload, status: status),
        ),
      ),
      locationServiceProvider.overrideWith(
        (ref) => FixedPositionLocationService(
          logger: ref.watch(appLoggerProvider),
          locationRepository: ref.watch(locationRepositoryProvider),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(krogerAreaFinderProvider)();
}

void main() {
  test('an address point finds the delivery area', () async {
    // Homewood, AL: LocationIQ answers with its own address point, and
    // `osm_type`/`osm_id` null. Kroger ticket 08.
    expect(await areaFromDevice(addressPointNullOsm), '35209');
  });

  test('an OSM object finds the delivery area', () async {
    expect(await areaFromDevice(osmObject), '94102');
  });

  test('a place with no postcode leaves the shopper to type one', () async {
    expect(await areaFromDevice(noPostcode), isNull);
  });

  test(
    'a point LocationIQ cannot place leaves the shopper to type one',
    () async {
      expect(await areaFromDevice(unableToGeocode, status: 404), isNull);
    },
  );
}

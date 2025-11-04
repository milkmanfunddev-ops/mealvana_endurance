import 'package:geolocator/geolocator.dart';
import 'package:location_iq/location_iq.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/logging_service.dart';
import '../data/repositories/location_repository.dart';
import '../../features/weather/domain/location.dart' as domain;

part 'location_service.g.dart';

/// Location service using geolocator and LocationIQ
/// Handles GPS location fetching with proper permission handling
/// and provides geocoding/address autocomplete functionality
@riverpod
LocationService locationService(Ref ref) {
  return LocationService(
    logger: ref.watch(appLoggerProvider),
    locationRepository: ref.watch(locationRepositoryProvider),
  );
}

class LocationService {
  final AppLogger logger;
  final LocationRepository locationRepository;

  LocationService({
    required this.logger,
    required this.locationRepository,
  });

  /// Get current device location
  /// Returns null if permission denied or location unavailable
  Future<domain.Location?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        logger.warning('Location services are disabled', context: 'LocationService');
        return null;
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          logger.warning('Location permission denied by user');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        logger.warning('Location permission permanently denied');
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      return domain.Location(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e, stackTrace) {
      logger.error('Error getting current location', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Check if location permissions are granted
  Future<bool> hasLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
             permission == LocationPermission.whileInUse;
    } catch (e) {
      logger.error('Error checking location permission', error: e);
      return false;
    }
  }

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      final permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always ||
             permission == LocationPermission.whileInUse;
    } catch (e) {
      logger.error('Error requesting location permission', error: e);
      return false;
    }
  }

  /// Open app settings for location permissions
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      logger.error('Error opening location settings', error: e);
      return false;
    }
  }

  // ========== Geocoding & Address Search Methods ==========

  /// Search for locations based on a query string (autocomplete)
  ///
  /// Useful for address fields where users type and see suggestions.
  /// Returns a list of matching locations with addresses and coordinates.
  ///
  /// Example:
  /// ```dart
  /// final results = await service.searchLocations('Boston Marathon');
  /// ```
  Future<List<LocationIQAutocompleteResult>> searchLocations(String query, {int limit = 5}) async {
    try {
      // TODO: Implement LocationIQ autocomplete API call
      logger.warning('searchLocations not yet implemented');
      return [];
    } catch (e, stackTrace) {
      logger.error('Error searching locations', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Convert an address string to coordinates (forward geocoding)
  ///
  /// Useful when you have a complete address and need lat/lng coordinates.
  Future<List<ForwardGeocodingResult>> geocodeAddress(String address) async {
    try {
      // TODO: Implement forward geocoding API call
      logger.warning('geocodeAddress not yet implemented');
      return [];
    } catch (e, stackTrace) {
      logger.error('Error geocoding address', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Convert coordinates to an address (reverse geocoding)
  ///
  /// Useful when you have lat/lng and need the human-readable address.
  Future<LocationIQReverseResult?> reverseGeocodeCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // TODO: Implement reverse geocoding API call
      logger.warning('reverseGeocodeCoordinates not yet implemented');
      return null;
    } catch (e, stackTrace) {
      logger.error('Error reverse geocoding coordinates', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}

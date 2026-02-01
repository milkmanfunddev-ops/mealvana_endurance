import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:location_iq/location_iq.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/logging_service.dart';
import '../data/repositories/location_repository.dart';
import '../../features/weather/domain/location.dart' as domain;

part 'location_service.g.dart';

enum LocationFailureReason {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  recentFailure,
  unknown,
}

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
  static const Duration _failureCooldown = Duration(minutes: 2);
  static DateTime? _lastFailureAt;
  static LocationFailureReason? _lastFailureReason;
  final String _instanceId = DateTime.now().microsecondsSinceEpoch.toString();

  LocationService({
    required this.logger,
    required this.locationRepository,
  });

  LocationFailureReason? getLastFailureReason() => _lastFailureReason;

  bool _isInFailureCooldown() {
    if (_lastFailureAt == null) {
      return false;
    }
    return DateTime.now().difference(_lastFailureAt!) < _failureCooldown;
  }

  Future<domain.Location?> _getLastKnownLocation() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown == null) {
        return null;
      }
      return domain.Location(
        latitude: lastKnown.latitude,
        longitude: lastKnown.longitude,
      );
    } catch (e, stackTrace) {
      logger.error('Error getting last known location', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get current device location
  /// Returns null if permission denied or location unavailable
  Future<domain.Location?> getCurrentLocation() async {
    try {
      logger.debug(
        'Starting location fetch',
        context: 'LocationService',
        data: {
          'instance_id': _instanceId,
          'cooldown_active': _isInFailureCooldown(),
          'last_failure_reason': _lastFailureReason?.name,
        },
      );
      if (_isInFailureCooldown()) {
        final lastKnown = await _getLastKnownLocation();
        if (lastKnown != null) {
          logger.info('Using last known location during cooldown', context: 'LocationService');
          _lastFailureReason = null;
          return lastKnown;
        }
        logger.warning('Skipping location fetch due to recent failure', context: 'LocationService');
        _lastFailureReason = LocationFailureReason.recentFailure;
        return null;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      logger.debug(
        'Location services enabled',
        context: 'LocationService',
        data: {'enabled': serviceEnabled},
      );
      if (!serviceEnabled) {
        logger.warning('Location services are disabled', context: 'LocationService');
        _lastFailureReason = LocationFailureReason.servicesDisabled;
        return null;
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      logger.debug(
        'Location permission status',
        context: 'LocationService',
        data: {'permission': permission.name},
      );

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          logger.warning('Location permission denied by user');
          _lastFailureReason = LocationFailureReason.permissionDenied;
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        logger.warning('Location permission permanently denied');
        _lastFailureReason = LocationFailureReason.permissionDeniedForever;
        return null;
      }

      // Get current position
      logger.debug(
        'Requesting current position',
        context: 'LocationService',
        data: {'accuracy': 'low', 'timeout_seconds': 20},
      );
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 20),
      );

      _lastFailureAt = null;
      _lastFailureReason = null;
      logger.debug(
        'Location acquired',
        context: 'LocationService',
        data: {'lat': position.latitude, 'lng': position.longitude},
      );
      return domain.Location(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e, stackTrace) {
      if (e is TimeoutException) {
        logger.warning('Location request timed out', context: 'LocationService');
        _lastFailureReason = LocationFailureReason.timeout;
      } else {
        logger.error('Error getting current location', error: e, stackTrace: stackTrace);
        _lastFailureReason = LocationFailureReason.unknown;
      }

      final lastKnown = await _getLastKnownLocation();
      if (lastKnown != null) {
        logger.warning('Using last known location after failure', context: 'LocationService');
        return lastKnown;
      }

      _lastFailureAt = DateTime.now();
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

  /// Open app settings
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      logger.error('Error opening app settings', error: e);
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
      return await locationRepository.searchLocations(query, limit: limit);
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
      return await locationRepository.geocode(address);
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
      return await locationRepository.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e, stackTrace) {
      logger.error('Error reverse geocoding coordinates', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}

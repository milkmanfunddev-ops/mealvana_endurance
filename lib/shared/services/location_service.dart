import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:location_iq/location_iq.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'report/report.dart';
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
    report: ref.watch(reportProvider),
    locationRepository: ref.watch(locationRepositoryProvider),
  );
}

class LocationService {
  final Report _report;
  final LocationRepository locationRepository;
  static const Duration _failureCooldown = Duration(minutes: 2);
  static DateTime? _lastFailureAt;
  static LocationFailureReason? _lastFailureReason;
  final String _instanceId = DateTime.now().microsecondsSinceEpoch.toString();

  LocationService({required Report report, required this.locationRepository})
    : _report = report;

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
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'location',
        message: 'Error getting last known location',
      );
      return null;
    }
  }

  /// Get current device location
  /// Returns null if permission denied or location unavailable
  Future<domain.Location?> getCurrentLocation() async {
    try {
      _report.debug(
        'Starting location fetch',
        area: 'location',
        data: {
          'instance_id': _instanceId,
          'cooldown_active': _isInFailureCooldown(),
          'last_failure_reason': _lastFailureReason?.name,
        },
      );
      if (_isInFailureCooldown()) {
        final lastKnown = await _getLastKnownLocation();
        if (lastKnown != null) {
          _report.info(
            'Using last known location during cooldown',
            area: 'location',
          );
          _lastFailureReason = null;
          return lastKnown;
        }
        _report.degraded(
          const LoggedFault(
            'Skipping location fetch due to recent failure',
            context: 'location',
          ),
          area: 'location',
        );
        _lastFailureReason = LocationFailureReason.recentFailure;
        return null;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _report.debug(
        'Location services enabled',
        area: 'location',
        data: {'enabled': serviceEnabled},
      );
      if (!serviceEnabled) {
        _report.degraded(
          const LoggedFault(
            'Location services are disabled',
            context: 'location',
          ),
          area: 'location',
        );
        _lastFailureReason = LocationFailureReason.servicesDisabled;
        return null;
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      _report.debug(
        'Location permission status',
        area: 'location',
        data: {'permission': permission.name},
      );

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _report.degraded(
            const LoggedFault('Location permission denied by user'),
            area: 'location',
          );
          _lastFailureReason = LocationFailureReason.permissionDenied;
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _report.degraded(
          const LoggedFault('Location permission permanently denied'),
          area: 'location',
        );
        _lastFailureReason = LocationFailureReason.permissionDeniedForever;
        return null;
      }

      // Get current position
      _report.debug(
        'Requesting current position',
        area: 'location',
        data: {'accuracy': 'low', 'timeout_seconds': 20},
      );
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 20),
      );

      _lastFailureAt = null;
      _lastFailureReason = null;
      _report.debug(
        'Location acquired',
        area: 'location',
        data: {'lat': position.latitude, 'lng': position.longitude},
      );
      return domain.Location(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e, stackTrace) {
      if (e is TimeoutException) {
        _report.degraded(
          const LoggedFault('Location request timed out', context: 'location'),
          area: 'location',
        );
        _lastFailureReason = LocationFailureReason.timeout;
      } else {
        _report.fault(
          e,
          stackTrace: stackTrace,
          area: 'location',
          message: 'Error getting current location',
        );
        _lastFailureReason = LocationFailureReason.unknown;
      }

      final lastKnown = await _getLastKnownLocation();
      if (lastKnown != null) {
        _report.degraded(
          const LoggedFault(
            'Using last known location after failure',
            context: 'location',
          ),
          area: 'location',
        );
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
      _report.fault(
        e,
        area: 'location',
        message: 'Error checking location permission',
      );
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
      _report.fault(
        e,
        area: 'location',
        message: 'Error requesting location permission',
      );
      return false;
    }
  }

  /// Open app settings for location permissions
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      _report.fault(
        e,
        area: 'location',
        message: 'Error opening location settings',
      );
      return false;
    }
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      _report.fault(e, area: 'location', message: 'Error opening app settings');
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
  Future<List<LocationIQAutocompleteResult>> searchLocations(
    String query, {
    int limit = 5,
  }) async {
    try {
      return await locationRepository.searchLocations(query, limit: limit);
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'location',
        message: 'Error searching locations',
      );
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
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'location',
        message: 'Error geocoding address',
      );
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
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'location',
        message: 'Error reverse geocoding coordinates',
      );
      return null;
    }
  }
}

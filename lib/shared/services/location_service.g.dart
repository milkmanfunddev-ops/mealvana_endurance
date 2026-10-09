// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Location service using geolocator and LocationIQ
/// Handles GPS location fetching with proper permission handling
/// and provides geocoding/address autocomplete functionality

@ProviderFor(locationService)
const locationServiceProvider = LocationServiceProvider._();

/// Location service using geolocator and LocationIQ
/// Handles GPS location fetching with proper permission handling
/// and provides geocoding/address autocomplete functionality

final class LocationServiceProvider
    extends
        $FunctionalProvider<LocationService, LocationService, LocationService>
    with $Provider<LocationService> {
  /// Location service using geolocator and LocationIQ
  /// Handles GPS location fetching with proper permission handling
  /// and provides geocoding/address autocomplete functionality
  const LocationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationServiceHash();

  @$internal
  @override
  $ProviderElement<LocationService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocationService create(Ref ref) {
    return locationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocationService>(value),
    );
  }
}

String _$locationServiceHash() => r'1a8bc7760cc0c55e705facfa0d05832db6b2f366';

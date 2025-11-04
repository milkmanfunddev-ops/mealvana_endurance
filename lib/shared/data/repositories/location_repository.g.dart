// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Repository for location-based operations using LocationIQ API.
///
/// Provides geocoding and address autocomplete functionality for finding
/// event locations, venues, and addresses.
///
/// **Data Layer (FOA)**: Handles external API calls to LocationIQ.

@ProviderFor(locationRepository)
const locationRepositoryProvider = LocationRepositoryProvider._();

/// Repository for location-based operations using LocationIQ API.
///
/// Provides geocoding and address autocomplete functionality for finding
/// event locations, venues, and addresses.
///
/// **Data Layer (FOA)**: Handles external API calls to LocationIQ.

final class LocationRepositoryProvider
    extends
        $FunctionalProvider<
          LocationRepository,
          LocationRepository,
          LocationRepository
        >
    with $Provider<LocationRepository> {
  /// Repository for location-based operations using LocationIQ API.
  ///
  /// Provides geocoding and address autocomplete functionality for finding
  /// event locations, venues, and addresses.
  ///
  /// **Data Layer (FOA)**: Handles external API calls to LocationIQ.
  const LocationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationRepositoryHash();

  @$internal
  @override
  $ProviderElement<LocationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocationRepository create(Ref ref) {
    return locationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocationRepository>(value),
    );
  }
}

String _$locationRepositoryHash() =>
    r'2526190538b40cd146beb2ca33ce901ef47fe5f8';

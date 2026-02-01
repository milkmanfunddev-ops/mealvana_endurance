// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'athlete_zones_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that reads athlete zones from the active Training Peaks integration.
///
/// Returns null if:
/// - No Training Peaks integration is connected
/// - No zone data has been fetched yet
/// - Zone data failed to parse
///
/// Zone data is fetched during sync (see training_peaks_sync_service.dart)
/// and stored in the integration record as JSON.

@ProviderFor(athleteZones)
const athleteZonesProvider = AthleteZonesFamily._();

/// Provider that reads athlete zones from the active Training Peaks integration.
///
/// Returns null if:
/// - No Training Peaks integration is connected
/// - No zone data has been fetched yet
/// - Zone data failed to parse
///
/// Zone data is fetched during sync (see training_peaks_sync_service.dart)
/// and stored in the integration record as JSON.

final class AthleteZonesProvider
    extends
        $FunctionalProvider<
          AsyncValue<AthleteZones?>,
          AthleteZones?,
          FutureOr<AthleteZones?>
        >
    with $FutureModifier<AthleteZones?>, $FutureProvider<AthleteZones?> {
  /// Provider that reads athlete zones from the active Training Peaks integration.
  ///
  /// Returns null if:
  /// - No Training Peaks integration is connected
  /// - No zone data has been fetched yet
  /// - Zone data failed to parse
  ///
  /// Zone data is fetched during sync (see training_peaks_sync_service.dart)
  /// and stored in the integration record as JSON.
  const AthleteZonesProvider._({
    required AthleteZonesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'athleteZonesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$athleteZonesHash();

  @override
  String toString() {
    return r'athleteZonesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AthleteZones?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AthleteZones?> create(Ref ref) {
    final argument = this.argument as String;
    return athleteZones(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AthleteZonesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$athleteZonesHash() => r'6a732ca44c691410e1ca2f946e3c3caa25668542';

/// Provider that reads athlete zones from the active Training Peaks integration.
///
/// Returns null if:
/// - No Training Peaks integration is connected
/// - No zone data has been fetched yet
/// - Zone data failed to parse
///
/// Zone data is fetched during sync (see training_peaks_sync_service.dart)
/// and stored in the integration record as JSON.

final class AthleteZonesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AthleteZones?>, String> {
  const AthleteZonesFamily._()
    : super(
        retry: null,
        name: r'athleteZonesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that reads athlete zones from the active Training Peaks integration.
  ///
  /// Returns null if:
  /// - No Training Peaks integration is connected
  /// - No zone data has been fetched yet
  /// - Zone data failed to parse
  ///
  /// Zone data is fetched during sync (see training_peaks_sync_service.dart)
  /// and stored in the integration record as JSON.

  AthleteZonesProvider call(String userId) =>
      AthleteZonesProvider._(argument: userId, from: this);

  @override
  String toString() => r'athleteZonesProvider';
}

/// Provider for just the Zone 2 pace (most commonly needed for auto-suggest)

@ProviderFor(zone2PaceMinPerMile)
const zone2PaceMinPerMileProvider = Zone2PaceMinPerMileFamily._();

/// Provider for just the Zone 2 pace (most commonly needed for auto-suggest)

final class Zone2PaceMinPerMileProvider
    extends $FunctionalProvider<AsyncValue<double?>, double?, FutureOr<double?>>
    with $FutureModifier<double?>, $FutureProvider<double?> {
  /// Provider for just the Zone 2 pace (most commonly needed for auto-suggest)
  const Zone2PaceMinPerMileProvider._({
    required Zone2PaceMinPerMileFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'zone2PaceMinPerMileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$zone2PaceMinPerMileHash();

  @override
  String toString() {
    return r'zone2PaceMinPerMileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<double?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double?> create(Ref ref) {
    final argument = this.argument as String;
    return zone2PaceMinPerMile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is Zone2PaceMinPerMileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$zone2PaceMinPerMileHash() =>
    r'500131490e98bac0435f86fb71a94025c1e5ecb1';

/// Provider for just the Zone 2 pace (most commonly needed for auto-suggest)

final class Zone2PaceMinPerMileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double?>, String> {
  const Zone2PaceMinPerMileFamily._()
    : super(
        retry: null,
        name: r'zone2PaceMinPerMileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for just the Zone 2 pace (most commonly needed for auto-suggest)

  Zone2PaceMinPerMileProvider call(String userId) =>
      Zone2PaceMinPerMileProvider._(argument: userId, from: this);

  @override
  String toString() => r'zone2PaceMinPerMileProvider';
}

/// Provider for threshold pace

@ProviderFor(thresholdPaceMinPerMile)
const thresholdPaceMinPerMileProvider = ThresholdPaceMinPerMileFamily._();

/// Provider for threshold pace

final class ThresholdPaceMinPerMileProvider
    extends $FunctionalProvider<AsyncValue<double?>, double?, FutureOr<double?>>
    with $FutureModifier<double?>, $FutureProvider<double?> {
  /// Provider for threshold pace
  const ThresholdPaceMinPerMileProvider._({
    required ThresholdPaceMinPerMileFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'thresholdPaceMinPerMileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$thresholdPaceMinPerMileHash();

  @override
  String toString() {
    return r'thresholdPaceMinPerMileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<double?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double?> create(Ref ref) {
    final argument = this.argument as String;
    return thresholdPaceMinPerMile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ThresholdPaceMinPerMileProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$thresholdPaceMinPerMileHash() =>
    r'7bf3c8e0a818e1af7ca71a17c8e7551be648e424';

/// Provider for threshold pace

final class ThresholdPaceMinPerMileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double?>, String> {
  const ThresholdPaceMinPerMileFamily._()
    : super(
        retry: null,
        name: r'thresholdPaceMinPerMileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for threshold pace

  ThresholdPaceMinPerMileProvider call(String userId) =>
      ThresholdPaceMinPerMileProvider._(argument: userId, from: this);

  @override
  String toString() => r'thresholdPaceMinPerMileProvider';
}

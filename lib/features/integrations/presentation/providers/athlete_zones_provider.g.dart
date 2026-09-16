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

/// D-2 provenance feed: the TP-sourced FTP (watts), or null when TP is not
/// connected / carries no power zones.

@ProviderFor(tpFtpWatts)
const tpFtpWattsProvider = TpFtpWattsFamily._();

/// D-2 provenance feed: the TP-sourced FTP (watts), or null when TP is not
/// connected / carries no power zones.

final class TpFtpWattsProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, FutureOr<int?>>
    with $FutureModifier<int?>, $FutureProvider<int?> {
  /// D-2 provenance feed: the TP-sourced FTP (watts), or null when TP is not
  /// connected / carries no power zones.
  const TpFtpWattsProvider._({
    required TpFtpWattsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tpFtpWattsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tpFtpWattsHash();

  @override
  String toString() {
    return r'tpFtpWattsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int?> create(Ref ref) {
    final argument = this.argument as String;
    return tpFtpWatts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TpFtpWattsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tpFtpWattsHash() => r'5632f500abeef5740cc00b1fbc25ad47e5b36da9';

/// D-2 provenance feed: the TP-sourced FTP (watts), or null when TP is not
/// connected / carries no power zones.

final class TpFtpWattsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int?>, String> {
  const TpFtpWattsFamily._()
    : super(
        retry: null,
        name: r'tpFtpWattsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// D-2 provenance feed: the TP-sourced FTP (watts), or null when TP is not
  /// connected / carries no power zones.

  TpFtpWattsProvider call(String userId) =>
      TpFtpWattsProvider._(argument: userId, from: this);

  @override
  String toString() => r'tpFtpWattsProvider';
}

/// D-2 provenance feed: the TP-derived swim CSS (sec/100m).

@ProviderFor(tpCssSecondsPer100m)
const tpCssSecondsPer100mProvider = TpCssSecondsPer100mFamily._();

/// D-2 provenance feed: the TP-derived swim CSS (sec/100m).

final class TpCssSecondsPer100mProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, FutureOr<int?>>
    with $FutureModifier<int?>, $FutureProvider<int?> {
  /// D-2 provenance feed: the TP-derived swim CSS (sec/100m).
  const TpCssSecondsPer100mProvider._({
    required TpCssSecondsPer100mFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tpCssSecondsPer100mProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tpCssSecondsPer100mHash();

  @override
  String toString() {
    return r'tpCssSecondsPer100mProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int?> create(Ref ref) {
    final argument = this.argument as String;
    return tpCssSecondsPer100m(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TpCssSecondsPer100mProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tpCssSecondsPer100mHash() =>
    r'2bab26065b199d3e974912e576f0eaff9fbb9465';

/// D-2 provenance feed: the TP-derived swim CSS (sec/100m).

final class TpCssSecondsPer100mFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int?>, String> {
  const TpCssSecondsPer100mFamily._()
    : super(
        retry: null,
        name: r'tpCssSecondsPer100mProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// D-2 provenance feed: the TP-derived swim CSS (sec/100m).

  TpCssSecondsPer100mProvider call(String userId) =>
      TpCssSecondsPer100mProvider._(argument: userId, from: this);

  @override
  String toString() => r'tpCssSecondsPer100mProvider';
}

/// D-2 staleness: true when the TP zones cache is older than the ruled
/// 24 h window (the zones clock — integration.updatedAt tracks the fetch).

@ProviderFor(tpZonesStale)
const tpZonesStaleProvider = TpZonesStaleFamily._();

/// D-2 staleness: true when the TP zones cache is older than the ruled
/// 24 h window (the zones clock — integration.updatedAt tracks the fetch).

final class TpZonesStaleProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// D-2 staleness: true when the TP zones cache is older than the ruled
  /// 24 h window (the zones clock — integration.updatedAt tracks the fetch).
  const TpZonesStaleProvider._({
    required TpZonesStaleFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tpZonesStaleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tpZonesStaleHash();

  @override
  String toString() {
    return r'tpZonesStaleProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return tpZonesStale(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TpZonesStaleProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tpZonesStaleHash() => r'efdb405715c972594cf5e84bbb664e496889669c';

/// D-2 staleness: true when the TP zones cache is older than the ruled
/// 24 h window (the zones clock — integration.updatedAt tracks the fetch).

final class TpZonesStaleFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  const TpZonesStaleFamily._()
    : super(
        retry: null,
        name: r'tpZonesStaleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// D-2 staleness: true when the TP zones cache is older than the ruled
  /// 24 h window (the zones clock — integration.updatedAt tracks the fetch).

  TpZonesStaleProvider call(String userId) =>
      TpZonesStaleProvider._(argument: userId, from: this);

  @override
  String toString() => r'tpZonesStaleProvider';
}

/// D-2b provenance feed (TP fallback): the athlete weight (kg) TP reported
/// on the basic profile, or null when TP is not connected. Garmin remains
/// the ruled primary body-comp source; this fills the badge when Garmin has
/// no reading (Xuan, 2026-09-13: every field a provider carries shows its
/// badge).

@ProviderFor(tpAthleteWeightKg)
const tpAthleteWeightKgProvider = TpAthleteWeightKgFamily._();

/// D-2b provenance feed (TP fallback): the athlete weight (kg) TP reported
/// on the basic profile, or null when TP is not connected. Garmin remains
/// the ruled primary body-comp source; this fills the badge when Garmin has
/// no reading (Xuan, 2026-09-13: every field a provider carries shows its
/// badge).

final class TpAthleteWeightKgProvider
    extends $FunctionalProvider<AsyncValue<double?>, double?, FutureOr<double?>>
    with $FutureModifier<double?>, $FutureProvider<double?> {
  /// D-2b provenance feed (TP fallback): the athlete weight (kg) TP reported
  /// on the basic profile, or null when TP is not connected. Garmin remains
  /// the ruled primary body-comp source; this fills the badge when Garmin has
  /// no reading (Xuan, 2026-09-13: every field a provider carries shows its
  /// badge).
  const TpAthleteWeightKgProvider._({
    required TpAthleteWeightKgFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tpAthleteWeightKgProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tpAthleteWeightKgHash();

  @override
  String toString() {
    return r'tpAthleteWeightKgProvider'
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
    return tpAthleteWeightKg(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TpAthleteWeightKgProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tpAthleteWeightKgHash() => r'cb979d623a9c32e50e304052901768dde8222312';

/// D-2b provenance feed (TP fallback): the athlete weight (kg) TP reported
/// on the basic profile, or null when TP is not connected. Garmin remains
/// the ruled primary body-comp source; this fills the badge when Garmin has
/// no reading (Xuan, 2026-09-13: every field a provider carries shows its
/// badge).

final class TpAthleteWeightKgFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double?>, String> {
  const TpAthleteWeightKgFamily._()
    : super(
        retry: null,
        name: r'tpAthleteWeightKgProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// D-2b provenance feed (TP fallback): the athlete weight (kg) TP reported
  /// on the basic profile, or null when TP is not connected. Garmin remains
  /// the ruled primary body-comp source; this fills the badge when Garmin has
  /// no reading (Xuan, 2026-09-13: every field a provider carries shows its
  /// badge).

  TpAthleteWeightKgProvider call(String userId) =>
      TpAthleteWeightKgProvider._(argument: userId, from: this);

  @override
  String toString() => r'tpAthleteWeightKgProvider';
}

/// TP-reported identity fields for profile provenance badges (name, birth
/// month "YYYY-MM", gender) — null when TP is not connected.

@ProviderFor(tpAthleteIdentity)
const tpAthleteIdentityProvider = TpAthleteIdentityFamily._();

/// TP-reported identity fields for profile provenance badges (name, birth
/// month "YYYY-MM", gender) — null when TP is not connected.

final class TpAthleteIdentityProvider
    extends
        $FunctionalProvider<
          AsyncValue<({String? birthMonth, String? gender, String? name})?>,
          ({String? birthMonth, String? gender, String? name})?,
          FutureOr<({String? birthMonth, String? gender, String? name})?>
        >
    with
        $FutureModifier<({String? birthMonth, String? gender, String? name})?>,
        $FutureProvider<({String? birthMonth, String? gender, String? name})?> {
  /// TP-reported identity fields for profile provenance badges (name, birth
  /// month "YYYY-MM", gender) — null when TP is not connected.
  const TpAthleteIdentityProvider._({
    required TpAthleteIdentityFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tpAthleteIdentityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tpAthleteIdentityHash();

  @override
  String toString() {
    return r'tpAthleteIdentityProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<({String? birthMonth, String? gender, String? name})?>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<({String? birthMonth, String? gender, String? name})?> create(
    Ref ref,
  ) {
    final argument = this.argument as String;
    return tpAthleteIdentity(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TpAthleteIdentityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tpAthleteIdentityHash() => r'e3461f932bb41ebda30e2e7a30316800e660a6ef';

/// TP-reported identity fields for profile provenance badges (name, birth
/// month "YYYY-MM", gender) — null when TP is not connected.

final class TpAthleteIdentityFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<({String? birthMonth, String? gender, String? name})?>,
          String
        > {
  const TpAthleteIdentityFamily._()
    : super(
        retry: null,
        name: r'tpAthleteIdentityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// TP-reported identity fields for profile provenance badges (name, birth
  /// month "YYYY-MM", gender) — null when TP is not connected.

  TpAthleteIdentityProvider call(String userId) =>
      TpAthleteIdentityProvider._(argument: userId, from: this);

  @override
  String toString() => r'tpAthleteIdentityProvider';
}

/// FS-reported athlete name (from the OAuth token response at connect) —
/// null when FS is not connected. Joins the identity badges per Xuan's
/// 2026-09-13 ruling: every provider with a non-null value shows its badge.

@ProviderFor(fsAthleteName)
const fsAthleteNameProvider = FsAthleteNameFamily._();

/// FS-reported athlete name (from the OAuth token response at connect) —
/// null when FS is not connected. Joins the identity badges per Xuan's
/// 2026-09-13 ruling: every provider with a non-null value shows its badge.

final class FsAthleteNameProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// FS-reported athlete name (from the OAuth token response at connect) —
  /// null when FS is not connected. Joins the identity badges per Xuan's
  /// 2026-09-13 ruling: every provider with a non-null value shows its badge.
  const FsAthleteNameProvider._({
    required FsAthleteNameFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'fsAthleteNameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fsAthleteNameHash();

  @override
  String toString() {
    return r'fsAthleteNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return fsAthleteName(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FsAthleteNameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fsAthleteNameHash() => r'ce4bdb0c007804fa723b2c2b11149975c0da01d4';

/// FS-reported athlete name (from the OAuth token response at connect) —
/// null when FS is not connected. Joins the identity badges per Xuan's
/// 2026-09-13 ruling: every provider with a non-null value shows its badge.

final class FsAthleteNameFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  const FsAthleteNameFamily._()
    : super(
        retry: null,
        name: r'fsAthleteNameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// FS-reported athlete name (from the OAuth token response at connect) —
  /// null when FS is not connected. Joins the identity badges per Xuan's
  /// 2026-09-13 ruling: every provider with a non-null value shows its badge.

  FsAthleteNameProvider call(String userId) =>
      FsAthleteNameProvider._(argument: userId, from: this);

  @override
  String toString() => r'fsAthleteNameProvider';
}

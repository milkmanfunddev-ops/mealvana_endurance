// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carbs_per_hour_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pure logic for the post-workout carbs/hr summary.

@ProviderFor(carbsPerHourService)
const carbsPerHourServiceProvider = CarbsPerHourServiceProvider._();

/// Pure logic for the post-workout carbs/hr summary.

final class CarbsPerHourServiceProvider
    extends
        $FunctionalProvider<
          CarbsPerHourService,
          CarbsPerHourService,
          CarbsPerHourService
        >
    with $Provider<CarbsPerHourService> {
  /// Pure logic for the post-workout carbs/hr summary.
  const CarbsPerHourServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbsPerHourServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbsPerHourServiceHash();

  @$internal
  @override
  $ProviderElement<CarbsPerHourService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CarbsPerHourService create(Ref ref) {
    return carbsPerHourService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CarbsPerHourService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CarbsPerHourService>(value),
    );
  }
}

String _$carbsPerHourServiceHash() =>
    r'027bdfc780e24dbb014b7e2ca69eee9e9f631b3d';

/// The same-sport fueling baseline for the activity being reviewed.
///
/// Reads the user's recent completed efforts of [activityType] and reduces
/// them to qualifying per-session carbs/hr (oldest → newest, windowed). The
/// current session is excluded so it isn't compared against itself.

@ProviderFor(carbsPerHourBaseline)
const carbsPerHourBaselineProvider = CarbsPerHourBaselineFamily._();

/// The same-sport fueling baseline for the activity being reviewed.
///
/// Reads the user's recent completed efforts of [activityType] and reduces
/// them to qualifying per-session carbs/hr (oldest → newest, windowed). The
/// current session is excluded so it isn't compared against itself.

final class CarbsPerHourBaselineProvider
    extends
        $FunctionalProvider<
          AsyncValue<CarbsPerHourBaseline>,
          CarbsPerHourBaseline,
          FutureOr<CarbsPerHourBaseline>
        >
    with
        $FutureModifier<CarbsPerHourBaseline>,
        $FutureProvider<CarbsPerHourBaseline> {
  /// The same-sport fueling baseline for the activity being reviewed.
  ///
  /// Reads the user's recent completed efforts of [activityType] and reduces
  /// them to qualifying per-session carbs/hr (oldest → newest, windowed). The
  /// current session is excluded so it isn't compared against itself.
  const CarbsPerHourBaselineProvider._({
    required CarbsPerHourBaselineFamily super.from,
    required (String, ActivityType) super.argument,
  }) : super(
         retry: null,
         name: r'carbsPerHourBaselineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carbsPerHourBaselineHash();

  @override
  String toString() {
    return r'carbsPerHourBaselineProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<CarbsPerHourBaseline> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CarbsPerHourBaseline> create(Ref ref) {
    final argument = this.argument as (String, ActivityType);
    return carbsPerHourBaseline(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is CarbsPerHourBaselineProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carbsPerHourBaselineHash() =>
    r'484e2774a7a6d0cec82d1a4b696d8d114688087f';

/// The same-sport fueling baseline for the activity being reviewed.
///
/// Reads the user's recent completed efforts of [activityType] and reduces
/// them to qualifying per-session carbs/hr (oldest → newest, windowed). The
/// current session is excluded so it isn't compared against itself.

final class CarbsPerHourBaselineFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<CarbsPerHourBaseline>,
          (String, ActivityType)
        > {
  const CarbsPerHourBaselineFamily._()
    : super(
        retry: null,
        name: r'carbsPerHourBaselineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The same-sport fueling baseline for the activity being reviewed.
  ///
  /// Reads the user's recent completed efforts of [activityType] and reduces
  /// them to qualifying per-session carbs/hr (oldest → newest, windowed). The
  /// current session is excluded so it isn't compared against itself.

  CarbsPerHourBaselineProvider call(
    String activityId,
    ActivityType activityType,
  ) => CarbsPerHourBaselineProvider._(
    argument: (activityId, activityType),
    from: this,
  );

  @override
  String toString() => r'carbsPerHourBaselineProvider';
}

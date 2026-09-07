// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brick_creation_available_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the Brick entry point should be offered for a given day.
///
/// Offered when the day holds 2+ brick-eligible workouts (swim / bike / run,
/// not already a brick) spanning 2+ sports. Adjacency is NOT required and
/// the caller's ordering is irrelevant (ruled Lee, 2026-08-26 — see
/// brick_eligibility.dart); the legs are linked in the order the athlete
/// picks them.

@ProviderFor(isBrickCreationAvailable)
const isBrickCreationAvailableProvider = IsBrickCreationAvailableFamily._();

/// Whether the Brick entry point should be offered for a given day.
///
/// Offered when the day holds 2+ brick-eligible workouts (swim / bike / run,
/// not already a brick) spanning 2+ sports. Adjacency is NOT required and
/// the caller's ordering is irrelevant (ruled Lee, 2026-08-26 — see
/// brick_eligibility.dart); the legs are linked in the order the athlete
/// picks them.

final class IsBrickCreationAvailableProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the Brick entry point should be offered for a given day.
  ///
  /// Offered when the day holds 2+ brick-eligible workouts (swim / bike / run,
  /// not already a brick) spanning 2+ sports. Adjacency is NOT required and
  /// the caller's ordering is irrelevant (ruled Lee, 2026-08-26 — see
  /// brick_eligibility.dart); the legs are linked in the order the athlete
  /// picks them.
  const IsBrickCreationAvailableProvider._({
    required IsBrickCreationAvailableFamily super.from,
    required ({List<Activity> activities, DateTime selectedDate})
    super.argument,
  }) : super(
         retry: null,
         name: r'isBrickCreationAvailableProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isBrickCreationAvailableHash();

  @override
  String toString() {
    return r'isBrickCreationAvailableProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument =
        this.argument as ({List<Activity> activities, DateTime selectedDate});
    return isBrickCreationAvailable(
      ref,
      activities: argument.activities,
      selectedDate: argument.selectedDate,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsBrickCreationAvailableProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isBrickCreationAvailableHash() =>
    r'fa6914ba3bc3cb13dc27f8b2a843a5b4f9565a00';

/// Whether the Brick entry point should be offered for a given day.
///
/// Offered when the day holds 2+ brick-eligible workouts (swim / bike / run,
/// not already a brick) spanning 2+ sports. Adjacency is NOT required and
/// the caller's ordering is irrelevant (ruled Lee, 2026-08-26 — see
/// brick_eligibility.dart); the legs are linked in the order the athlete
/// picks them.

final class IsBrickCreationAvailableFamily extends $Family
    with
        $FunctionalFamilyOverride<
          bool,
          ({List<Activity> activities, DateTime selectedDate})
        > {
  const IsBrickCreationAvailableFamily._()
    : super(
        retry: null,
        name: r'isBrickCreationAvailableProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether the Brick entry point should be offered for a given day.
  ///
  /// Offered when the day holds 2+ brick-eligible workouts (swim / bike / run,
  /// not already a brick) spanning 2+ sports. Adjacency is NOT required and
  /// the caller's ordering is irrelevant (ruled Lee, 2026-08-26 — see
  /// brick_eligibility.dart); the legs are linked in the order the athlete
  /// picks them.

  IsBrickCreationAvailableProvider call({
    required List<Activity> activities,
    required DateTime selectedDate,
  }) => IsBrickCreationAvailableProvider._(
    argument: (activities: activities, selectedDate: selectedDate),
    from: this,
  );

  @override
  String toString() => r'isBrickCreationAvailableProvider';
}

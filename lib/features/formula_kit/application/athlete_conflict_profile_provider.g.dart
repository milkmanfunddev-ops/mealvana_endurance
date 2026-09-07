// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'athlete_conflict_profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The athlete's allergy + diet db values, read once from the profile for the
/// formula-pin conflict surface (FP-4a/4b/7/8 —
/// `docs/ssot/spec/design/components/formula-pin-surface.md`).
///
/// Mirrors how the client plan solver reads the profile
/// (`ClientPlanService`: `authServiceProvider` → `getCurrentUser()` →
/// `allergies` / `dietaryPreference`). `none` normalizes to no diet
/// constraint. Read-only derived data — conflict *evaluation* stays in the
/// pure domain (`evaluateFormulaProfileConflict`).

@ProviderFor(athleteConflictProfile)
const athleteConflictProfileProvider = AthleteConflictProfileProvider._();

/// The athlete's allergy + diet db values, read once from the profile for the
/// formula-pin conflict surface (FP-4a/4b/7/8 —
/// `docs/ssot/spec/design/components/formula-pin-surface.md`).
///
/// Mirrors how the client plan solver reads the profile
/// (`ClientPlanService`: `authServiceProvider` → `getCurrentUser()` →
/// `allergies` / `dietaryPreference`). `none` normalizes to no diet
/// constraint. Read-only derived data — conflict *evaluation* stays in the
/// pure domain (`evaluateFormulaProfileConflict`).

final class AthleteConflictProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<AthleteConflictProfile>,
          AthleteConflictProfile,
          FutureOr<AthleteConflictProfile>
        >
    with
        $FutureModifier<AthleteConflictProfile>,
        $FutureProvider<AthleteConflictProfile> {
  /// The athlete's allergy + diet db values, read once from the profile for the
  /// formula-pin conflict surface (FP-4a/4b/7/8 —
  /// `docs/ssot/spec/design/components/formula-pin-surface.md`).
  ///
  /// Mirrors how the client plan solver reads the profile
  /// (`ClientPlanService`: `authServiceProvider` → `getCurrentUser()` →
  /// `allergies` / `dietaryPreference`). `none` normalizes to no diet
  /// constraint. Read-only derived data — conflict *evaluation* stays in the
  /// pure domain (`evaluateFormulaProfileConflict`).
  const AthleteConflictProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'athleteConflictProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$athleteConflictProfileHash();

  @$internal
  @override
  $FutureProviderElement<AthleteConflictProfile> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AthleteConflictProfile> create(Ref ref) {
    return athleteConflictProfile(ref);
  }
}

String _$athleteConflictProfileHash() =>
    r'28a1c785859b85c1fd601244be095c9247ed6d94';

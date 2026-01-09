// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'athlete_data_sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that syncs a specific athlete's data from Supabase (on-demand)
/// This is triggered when a coach views athlete details and taps refresh
/// Fetches events, activities, and carb loading plans for the specified athlete
///
/// Note: Does NOT invalidate athleteDetailController - the controller handles
/// reloading its own data after this sync completes

@ProviderFor(athleteDataSync)
const athleteDataSyncProvider = AthleteDataSyncFamily._();

/// Provider that syncs a specific athlete's data from Supabase (on-demand)
/// This is triggered when a coach views athlete details and taps refresh
/// Fetches events, activities, and carb loading plans for the specified athlete
///
/// Note: Does NOT invalidate athleteDetailController - the controller handles
/// reloading its own data after this sync completes

final class AthleteDataSyncProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Provider that syncs a specific athlete's data from Supabase (on-demand)
  /// This is triggered when a coach views athlete details and taps refresh
  /// Fetches events, activities, and carb loading plans for the specified athlete
  ///
  /// Note: Does NOT invalidate athleteDetailController - the controller handles
  /// reloading its own data after this sync completes
  const AthleteDataSyncProvider._({
    required AthleteDataSyncFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'athleteDataSyncProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$athleteDataSyncHash();

  @override
  String toString() {
    return r'athleteDataSyncProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as (String, String);
    return athleteDataSync(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is AthleteDataSyncProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$athleteDataSyncHash() => r'f357a719bb4d7de8cdae1e7cd356addf0d4a9756';

/// Provider that syncs a specific athlete's data from Supabase (on-demand)
/// This is triggered when a coach views athlete details and taps refresh
/// Fetches events, activities, and carb loading plans for the specified athlete
///
/// Note: Does NOT invalidate athleteDetailController - the controller handles
/// reloading its own data after this sync completes

final class AthleteDataSyncFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, (String, String)> {
  const AthleteDataSyncFamily._()
    : super(
        retry: null,
        name: r'athleteDataSyncProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that syncs a specific athlete's data from Supabase (on-demand)
  /// This is triggered when a coach views athlete details and taps refresh
  /// Fetches events, activities, and carb loading plans for the specified athlete
  ///
  /// Note: Does NOT invalidate athleteDetailController - the controller handles
  /// reloading its own data after this sync completes

  AthleteDataSyncProvider call(String relationshipId, String athleteUserId) =>
      AthleteDataSyncProvider._(
        argument: (relationshipId, athleteUserId),
        from: this,
      );

  @override
  String toString() => r'athleteDataSyncProvider';
}

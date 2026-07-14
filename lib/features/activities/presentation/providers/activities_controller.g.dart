// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activities_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing activities
/// Handles activity CRUD operations (create, read, update, delete)
///
/// NEW SYNC PATTERN (Phase 5.1):
/// - Uses ensureSynced() for dependency-aware, staleness-based sync
/// - Syncs activities (and users dependency) only when stale (>24h)
/// - Errors handled gracefully - user sees cached data on failure

@ProviderFor(ActivitiesController)
const activitiesControllerProvider = ActivitiesControllerProvider._();

/// Controller for managing activities
/// Handles activity CRUD operations (create, read, update, delete)
///
/// NEW SYNC PATTERN (Phase 5.1):
/// - Uses ensureSynced() for dependency-aware, staleness-based sync
/// - Syncs activities (and users dependency) only when stale (>24h)
/// - Errors handled gracefully - user sees cached data on failure
final class ActivitiesControllerProvider
    extends $AsyncNotifierProvider<ActivitiesController, List<Activity>> {
  /// Controller for managing activities
  /// Handles activity CRUD operations (create, read, update, delete)
  ///
  /// NEW SYNC PATTERN (Phase 5.1):
  /// - Uses ensureSynced() for dependency-aware, staleness-based sync
  /// - Syncs activities (and users dependency) only when stale (>24h)
  /// - Errors handled gracefully - user sees cached data on failure
  const ActivitiesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activitiesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activitiesControllerHash();

  @$internal
  @override
  ActivitiesController create() => ActivitiesController();
}

String _$activitiesControllerHash() =>
    r'720a8804b31542c69e40a3550351fb835c6c9898';

/// Controller for managing activities
/// Handles activity CRUD operations (create, read, update, delete)
///
/// NEW SYNC PATTERN (Phase 5.1):
/// - Uses ensureSynced() for dependency-aware, staleness-based sync
/// - Syncs activities (and users dependency) only when stale (>24h)
/// - Errors handled gracefully - user sees cached data on failure

abstract class _$ActivitiesController extends $AsyncNotifier<List<Activity>> {
  FutureOr<List<Activity>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<Activity>>, List<Activity>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Activity>>, List<Activity>>,
              AsyncValue<List<Activity>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for getting a specific activity by ID

@ProviderFor(activityDetail)
const activityDetailProvider = ActivityDetailFamily._();

/// Provider for getting a specific activity by ID

final class ActivityDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<Activity?>,
          Activity?,
          FutureOr<Activity?>
        >
    with $FutureModifier<Activity?>, $FutureProvider<Activity?> {
  /// Provider for getting a specific activity by ID
  const ActivityDetailProvider._({
    required ActivityDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activityDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activityDetailHash();

  @override
  String toString() {
    return r'activityDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Activity?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Activity?> create(Ref ref) {
    final argument = this.argument as String;
    return activityDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActivityDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activityDetailHash() => r'2ca5051738620538348cae7e046e00bde88fc3fd';

/// Provider for getting a specific activity by ID

final class ActivityDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Activity?>, String> {
  const ActivityDetailFamily._()
    : super(
        retry: null,
        name: r'activityDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for getting a specific activity by ID

  ActivityDetailProvider call(String activityId) =>
      ActivityDetailProvider._(argument: activityId, from: this);

  @override
  String toString() => r'activityDetailProvider';
}

/// Provider for getting all activities

@ProviderFor(allActivities)
const allActivitiesProvider = AllActivitiesProvider._();

/// Provider for getting all activities

final class AllActivitiesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Activity>>,
          List<Activity>,
          FutureOr<List<Activity>>
        >
    with $FutureModifier<List<Activity>>, $FutureProvider<List<Activity>> {
  /// Provider for getting all activities
  const AllActivitiesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allActivitiesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allActivitiesHash();

  @$internal
  @override
  $FutureProviderElement<List<Activity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Activity>> create(Ref ref) {
    return allActivities(ref);
  }
}

String _$allActivitiesHash() => r'1e3220fef429b420532ac38d3d9cc01c529ea17e';

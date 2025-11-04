// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activities_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing activities
/// Handles activity CRUD operations (create, read, update, delete)

@ProviderFor(ActivitiesController)
const activitiesControllerProvider = ActivitiesControllerProvider._();

/// Controller for managing activities
/// Handles activity CRUD operations (create, read, update, delete)
final class ActivitiesControllerProvider
    extends $AsyncNotifierProvider<ActivitiesController, List<Activity>> {
  /// Controller for managing activities
  /// Handles activity CRUD operations (create, read, update, delete)
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
    r'feb58f4d2d859bb514017e0af45873d826ef550b';

/// Controller for managing activities
/// Handles activity CRUD operations (create, read, update, delete)

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

String _$activityDetailHash() => r'6ce2885023ebe56af134af147ba8a146c1a0bf46';

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

String _$allActivitiesHash() => r'06a6131f76ce494ea0463a5400432791ca223764';

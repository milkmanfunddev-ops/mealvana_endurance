// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Activity Detail Controller
/// Manages activity viewing, updates, and completion
///
/// SIMPLIFIED: Uses only activityId as the provider family parameter.
/// All data is loaded from the database. This eliminates provider instance
/// mismatches that caused food swap/add operations to not persist.

@ProviderFor(ActivityDetailController)
const activityDetailControllerProvider = ActivityDetailControllerFamily._();

/// Activity Detail Controller
/// Manages activity viewing, updates, and completion
///
/// SIMPLIFIED: Uses only activityId as the provider family parameter.
/// All data is loaded from the database. This eliminates provider instance
/// mismatches that caused food swap/add operations to not persist.
final class ActivityDetailControllerProvider
    extends
        $AsyncNotifierProvider<ActivityDetailController, ActivityDetailState> {
  /// Activity Detail Controller
  /// Manages activity viewing, updates, and completion
  ///
  /// SIMPLIFIED: Uses only activityId as the provider family parameter.
  /// All data is loaded from the database. This eliminates provider instance
  /// mismatches that caused food swap/add operations to not persist.
  const ActivityDetailControllerProvider._({
    required ActivityDetailControllerFamily super.from,
    required ({String activityId, bool isNewActivity}) super.argument,
  }) : super(
         retry: null,
         name: r'activityDetailControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activityDetailControllerHash();

  @override
  String toString() {
    return r'activityDetailControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ActivityDetailController create() => ActivityDetailController();

  @override
  bool operator ==(Object other) {
    return other is ActivityDetailControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activityDetailControllerHash() =>
    r'b67bbcad18690590fabfed0c21b97edc2217ca27';

/// Activity Detail Controller
/// Manages activity viewing, updates, and completion
///
/// SIMPLIFIED: Uses only activityId as the provider family parameter.
/// All data is loaded from the database. This eliminates provider instance
/// mismatches that caused food swap/add operations to not persist.

final class ActivityDetailControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ActivityDetailController,
          AsyncValue<ActivityDetailState>,
          ActivityDetailState,
          FutureOr<ActivityDetailState>,
          ({String activityId, bool isNewActivity})
        > {
  const ActivityDetailControllerFamily._()
    : super(
        retry: null,
        name: r'activityDetailControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Activity Detail Controller
  /// Manages activity viewing, updates, and completion
  ///
  /// SIMPLIFIED: Uses only activityId as the provider family parameter.
  /// All data is loaded from the database. This eliminates provider instance
  /// mismatches that caused food swap/add operations to not persist.

  ActivityDetailControllerProvider call({
    required String activityId,
    bool isNewActivity = false,
  }) => ActivityDetailControllerProvider._(
    argument: (activityId: activityId, isNewActivity: isNewActivity),
    from: this,
  );

  @override
  String toString() => r'activityDetailControllerProvider';
}

/// Activity Detail Controller
/// Manages activity viewing, updates, and completion
///
/// SIMPLIFIED: Uses only activityId as the provider family parameter.
/// All data is loaded from the database. This eliminates provider instance
/// mismatches that caused food swap/add operations to not persist.

abstract class _$ActivityDetailController
    extends $AsyncNotifier<ActivityDetailState> {
  late final _$args = ref.$arg as ({String activityId, bool isNewActivity});
  String get activityId => _$args.activityId;
  bool get isNewActivity => _$args.isNewActivity;

  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      activityId: _$args.activityId,
      isNewActivity: _$args.isNewActivity,
    );
    final ref =
        this.ref as $Ref<AsyncValue<ActivityDetailState>, ActivityDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ActivityDetailState>, ActivityDetailState>,
              AsyncValue<ActivityDetailState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

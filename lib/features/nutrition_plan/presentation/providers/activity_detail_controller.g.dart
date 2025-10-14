// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Activity Detail Controller
/// Manages activity creation, updates, and completion

@ProviderFor(ActivityDetailController)
const activityDetailControllerProvider = ActivityDetailControllerFamily._();

/// Activity Detail Controller
/// Manages activity creation, updates, and completion
final class ActivityDetailControllerProvider
    extends
        $AsyncNotifierProvider<ActivityDetailController, ActivityDetailState> {
  /// Activity Detail Controller
  /// Manages activity creation, updates, and completion
  const ActivityDetailControllerProvider._({
    required ActivityDetailControllerFamily super.from,
    required ({
      String mode,
      String? activityId,
      PendingActivityData? pendingActivityData,
      MacroTargets? macroTargets,
    })
    super.argument,
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
    r'31d3276591c6c40bef3a94958b5936352ac4f7e0';

/// Activity Detail Controller
/// Manages activity creation, updates, and completion

final class ActivityDetailControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ActivityDetailController,
          AsyncValue<ActivityDetailState>,
          ActivityDetailState,
          FutureOr<ActivityDetailState>,
          ({
            String mode,
            String? activityId,
            PendingActivityData? pendingActivityData,
            MacroTargets? macroTargets,
          })
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
  /// Manages activity creation, updates, and completion

  ActivityDetailControllerProvider call({
    required String mode,
    String? activityId,
    PendingActivityData? pendingActivityData,
    MacroTargets? macroTargets,
  }) => ActivityDetailControllerProvider._(
    argument: (
      mode: mode,
      activityId: activityId,
      pendingActivityData: pendingActivityData,
      macroTargets: macroTargets,
    ),
    from: this,
  );

  @override
  String toString() => r'activityDetailControllerProvider';
}

/// Activity Detail Controller
/// Manages activity creation, updates, and completion

abstract class _$ActivityDetailController
    extends $AsyncNotifier<ActivityDetailState> {
  late final _$args =
      ref.$arg
          as ({
            String mode,
            String? activityId,
            PendingActivityData? pendingActivityData,
            MacroTargets? macroTargets,
          });
  String get mode => _$args.mode;
  String? get activityId => _$args.activityId;
  PendingActivityData? get pendingActivityData => _$args.pendingActivityData;
  MacroTargets? get macroTargets => _$args.macroTargets;

  FutureOr<ActivityDetailState> build({
    required String mode,
    String? activityId,
    PendingActivityData? pendingActivityData,
    MacroTargets? macroTargets,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      mode: _$args.mode,
      activityId: _$args.activityId,
      pendingActivityData: _$args.pendingActivityData,
      macroTargets: _$args.macroTargets,
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

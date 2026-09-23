// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_activity_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for the coach view of an activity

@ProviderFor(CoachActivityDetailController)
const coachActivityDetailControllerProvider =
    CoachActivityDetailControllerFamily._();

/// Controller for the coach view of an activity
final class CoachActivityDetailControllerProvider
    extends
        $AsyncNotifierProvider<
          CoachActivityDetailController,
          CoachActivityDetailState
        > {
  /// Controller for the coach view of an activity
  const CoachActivityDetailControllerProvider._({
    required CoachActivityDetailControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'coachActivityDetailControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$coachActivityDetailControllerHash();

  @override
  String toString() {
    return r'coachActivityDetailControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CoachActivityDetailController create() => CoachActivityDetailController();

  @override
  bool operator ==(Object other) {
    return other is CoachActivityDetailControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$coachActivityDetailControllerHash() =>
    r'af42114bc6a94f845ca20b2cd0fbac5490476196';

/// Controller for the coach view of an activity

final class CoachActivityDetailControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CoachActivityDetailController,
          AsyncValue<CoachActivityDetailState>,
          CoachActivityDetailState,
          FutureOr<CoachActivityDetailState>,
          String
        > {
  const CoachActivityDetailControllerFamily._()
    : super(
        retry: null,
        name: r'coachActivityDetailControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Controller for the coach view of an activity

  CoachActivityDetailControllerProvider call(String activityId) =>
      CoachActivityDetailControllerProvider._(argument: activityId, from: this);

  @override
  String toString() => r'coachActivityDetailControllerProvider';
}

/// Controller for the coach view of an activity

abstract class _$CoachActivityDetailController
    extends $AsyncNotifier<CoachActivityDetailState> {
  late final _$args = ref.$arg as String;
  String get activityId => _$args;

  FutureOr<CoachActivityDetailState> build(String activityId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref
            as $Ref<
              AsyncValue<CoachActivityDetailState>,
              CoachActivityDetailState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<CoachActivityDetailState>,
                CoachActivityDetailState
              >,
              AsyncValue<CoachActivityDetailState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

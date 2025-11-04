// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_completions_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing activity completions
/// Handles recording and updating activity completion data

@ProviderFor(ActivityCompletionsController)
const activityCompletionsControllerProvider =
    ActivityCompletionsControllerProvider._();

/// Controller for managing activity completions
/// Handles recording and updating activity completion data
final class ActivityCompletionsControllerProvider
    extends $AsyncNotifierProvider<ActivityCompletionsController, void> {
  /// Controller for managing activity completions
  /// Handles recording and updating activity completion data
  const ActivityCompletionsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activityCompletionsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activityCompletionsControllerHash();

  @$internal
  @override
  ActivityCompletionsController create() => ActivityCompletionsController();
}

String _$activityCompletionsControllerHash() =>
    r'676069ce45bc69a0c458e5bba9956e9ace61feb4';

/// Controller for managing activity completions
/// Handles recording and updating activity completion data

abstract class _$ActivityCompletionsController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}

/// Provider for getting completion data for a specific activity

@ProviderFor(activityCompletion)
const activityCompletionProvider = ActivityCompletionFamily._();

/// Provider for getting completion data for a specific activity

final class ActivityCompletionProvider
    extends
        $FunctionalProvider<
          AsyncValue<ActivityCompletion?>,
          ActivityCompletion?,
          FutureOr<ActivityCompletion?>
        >
    with
        $FutureModifier<ActivityCompletion?>,
        $FutureProvider<ActivityCompletion?> {
  /// Provider for getting completion data for a specific activity
  const ActivityCompletionProvider._({
    required ActivityCompletionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activityCompletionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activityCompletionHash();

  @override
  String toString() {
    return r'activityCompletionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ActivityCompletion?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ActivityCompletion?> create(Ref ref) {
    final argument = this.argument as String;
    return activityCompletion(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActivityCompletionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activityCompletionHash() =>
    r'f3827266e2c62c2247b03c2d15d914f401e20509';

/// Provider for getting completion data for a specific activity

final class ActivityCompletionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ActivityCompletion?>, String> {
  const ActivityCompletionFamily._()
    : super(
        retry: null,
        name: r'activityCompletionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for getting completion data for a specific activity

  ActivityCompletionProvider call(String activityId) =>
      ActivityCompletionProvider._(argument: activityId, from: this);

  @override
  String toString() => r'activityCompletionProvider';
}

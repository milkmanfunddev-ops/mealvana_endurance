// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Simple controller for feedback submission using our new system
/// This replaces the old feedback controller with our new feedback workflow

@ProviderFor(FeedbackController)
const feedbackControllerProvider = FeedbackControllerProvider._();

/// Simple controller for feedback submission using our new system
/// This replaces the old feedback controller with our new feedback workflow
final class FeedbackControllerProvider
    extends $AsyncNotifierProvider<FeedbackController, void> {
  /// Simple controller for feedback submission using our new system
  /// This replaces the old feedback controller with our new feedback workflow
  const FeedbackControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedbackControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedbackControllerHash();

  @$internal
  @override
  FeedbackController create() => FeedbackController();
}

String _$feedbackControllerHash() =>
    r'4ad8938ea269bea2c8350db8e0b0fef939797be4';

/// Simple controller for feedback submission using our new system
/// This replaces the old feedback controller with our new feedback workflow

abstract class _$FeedbackController extends $AsyncNotifier<void> {
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

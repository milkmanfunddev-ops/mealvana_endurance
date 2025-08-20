// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$feedbackControllerHash() =>
    r'4ad8938ea269bea2c8350db8e0b0fef939797be4';

/// Simple controller for feedback submission using our new system
/// This replaces the old feedback controller with our new feedback workflow
///
/// Copied from [FeedbackController].
@ProviderFor(FeedbackController)
final feedbackControllerProvider =
    AutoDisposeAsyncNotifierProvider<FeedbackController, void>.internal(
  FeedbackController.new,
  name: r'feedbackControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$feedbackControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FeedbackController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

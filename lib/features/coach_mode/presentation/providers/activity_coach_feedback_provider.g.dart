// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_coach_feedback_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that loads coach feedback for a specific activity
/// Used to show feedback on the ActivityDetailScreen

@ProviderFor(activityCoachFeedback)
const activityCoachFeedbackProvider = ActivityCoachFeedbackFamily._();

/// Provider that loads coach feedback for a specific activity
/// Used to show feedback on the ActivityDetailScreen

final class ActivityCoachFeedbackProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CoachFeedback>>,
          List<CoachFeedback>,
          FutureOr<List<CoachFeedback>>
        >
    with
        $FutureModifier<List<CoachFeedback>>,
        $FutureProvider<List<CoachFeedback>> {
  /// Provider that loads coach feedback for a specific activity
  /// Used to show feedback on the ActivityDetailScreen
  const ActivityCoachFeedbackProvider._({
    required ActivityCoachFeedbackFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activityCoachFeedbackProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activityCoachFeedbackHash();

  @override
  String toString() {
    return r'activityCoachFeedbackProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CoachFeedback>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CoachFeedback>> create(Ref ref) {
    final argument = this.argument as String;
    return activityCoachFeedback(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActivityCoachFeedbackProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activityCoachFeedbackHash() =>
    r'47dea39b8fcd38aa6e7404eabfadc5954add42fd';

/// Provider that loads coach feedback for a specific activity
/// Used to show feedback on the ActivityDetailScreen

final class ActivityCoachFeedbackFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<CoachFeedback>>, String> {
  const ActivityCoachFeedbackFamily._()
    : super(
        retry: null,
        name: r'activityCoachFeedbackProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that loads coach feedback for a specific activity
  /// Used to show feedback on the ActivityDetailScreen

  ActivityCoachFeedbackProvider call(String activityId) =>
      ActivityCoachFeedbackProvider._(argument: activityId, from: this);

  @override
  String toString() => r'activityCoachFeedbackProvider';
}

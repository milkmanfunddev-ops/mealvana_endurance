// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_coach_feedback_sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that syncs coach messages for a specific activity from Supabase
/// AND subscribes to Supabase Realtime for instant updates.
///
/// When the widget is displayed, this provider:
/// 1. Syncs existing messages from Supabase to local DB
/// 2. Sets up a Realtime subscription for new activity comments
/// 3. Invalidates the feedback provider whenever new data arrives

@ProviderFor(activityCoachFeedbackSync)
const activityCoachFeedbackSyncProvider = ActivityCoachFeedbackSyncFamily._();

/// Provider that syncs coach messages for a specific activity from Supabase
/// AND subscribes to Supabase Realtime for instant updates.
///
/// When the widget is displayed, this provider:
/// 1. Syncs existing messages from Supabase to local DB
/// 2. Sets up a Realtime subscription for new activity comments
/// 3. Invalidates the feedback provider whenever new data arrives

final class ActivityCoachFeedbackSyncProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Provider that syncs coach messages for a specific activity from Supabase
  /// AND subscribes to Supabase Realtime for instant updates.
  ///
  /// When the widget is displayed, this provider:
  /// 1. Syncs existing messages from Supabase to local DB
  /// 2. Sets up a Realtime subscription for new activity comments
  /// 3. Invalidates the feedback provider whenever new data arrives
  const ActivityCoachFeedbackSyncProvider._({
    required ActivityCoachFeedbackSyncFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activityCoachFeedbackSyncProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activityCoachFeedbackSyncHash();

  @override
  String toString() {
    return r'activityCoachFeedbackSyncProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as String;
    return activityCoachFeedbackSync(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActivityCoachFeedbackSyncProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activityCoachFeedbackSyncHash() =>
    r'18d8de51e5e858e9a07344f718880d15ce4c088c';

/// Provider that syncs coach messages for a specific activity from Supabase
/// AND subscribes to Supabase Realtime for instant updates.
///
/// When the widget is displayed, this provider:
/// 1. Syncs existing messages from Supabase to local DB
/// 2. Sets up a Realtime subscription for new activity comments
/// 3. Invalidates the feedback provider whenever new data arrives

final class ActivityCoachFeedbackSyncFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<void>, String> {
  const ActivityCoachFeedbackSyncFamily._()
    : super(
        retry: null,
        name: r'activityCoachFeedbackSyncProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider that syncs coach messages for a specific activity from Supabase
  /// AND subscribes to Supabase Realtime for instant updates.
  ///
  /// When the widget is displayed, this provider:
  /// 1. Syncs existing messages from Supabase to local DB
  /// 2. Sets up a Realtime subscription for new activity comments
  /// 3. Invalidates the feedback provider whenever new data arrives

  ActivityCoachFeedbackSyncProvider call(String activityId) =>
      ActivityCoachFeedbackSyncProvider._(argument: activityId, from: this);

  @override
  String toString() => r'activityCoachFeedbackSyncProvider';
}

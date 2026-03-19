import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/logging_service.dart';
import '../../application/coach_service.dart';
import '../../domain/coach_message.dart';

part 'athlete_feedback_controller.g.dart';

/// State for the athlete feedback screen
/// Shows all messages/comments from coaches to this athlete
class AthleteFeedbackState {
  final List<CoachMessage> allMessages;

  const AthleteFeedbackState({this.allMessages = const []});

  bool get isEmpty => allMessages.isEmpty;
  bool get hasMessages => allMessages.isNotEmpty;
  int get messageCount => allMessages.length;

  AthleteFeedbackState copyWith({List<CoachMessage>? allMessages}) {
    return AthleteFeedbackState(allMessages: allMessages ?? this.allMessages);
  }
}

@riverpod
class AthleteFeedbackController extends _$AthleteFeedbackController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<AthleteFeedbackState> build() async {
    return _loadMessages();
  }

  /// Load local messages immediately, sync in background
  Future<AthleteFeedbackState> _loadMessages() async {
    // 1. Load local data IMMEDIATELY
    final coaches = await _coachService.getMyCoaches();

    if (coaches.isEmpty) {
      // Still try background sync - we may not have synced relationships yet
      unawaited(_backgroundSync());
      return const AthleteFeedbackState();
    }

    final allMessages = <CoachMessage>[];

    for (final relationship in coaches) {
      final messages = await _coachService.getConversation(
        coachUserId: relationship.coachUserId,
        athleteUserId: relationship.athleteUserId,
      );

      final coachMessages = messages.where((m) => m.isSentByCoach);
      allMessages.addAll(coachMessages);
    }

    allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // 2. Background sync (fire-and-forget) - fixes bug where new coach messages weren't showing
    unawaited(_backgroundSync());

    return AthleteFeedbackState(allMessages: allMessages);
  }

  /// Background sync: fetches latest relationships and coach data, then refreshes UI
  Future<void> _backgroundSync() async {
    final coachService = ref.read(coachServiceProvider);
    final logger = ref.read(appLoggerProvider);

    try {
      await coachService.syncRelationshipsFromSupabase();
      await coachService.syncMyCoachesData();
      if (!ref.mounted) return;
      ref.invalidateSelf();
    } catch (e, stackTrace) {
      logger.error(
        'Background sync failed',
        context: 'ATHLETE_FEEDBACK_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../application/coach_service.dart';
import '../../domain/coach_message.dart';

part 'athlete_feedback_controller.g.dart';

/// State for the athlete feedback screen
/// Shows all messages/comments from coaches to this athlete
class AthleteFeedbackState {
  final List<CoachMessage> allMessages;

  const AthleteFeedbackState({
    this.allMessages = const [],
  });

  bool get isEmpty => allMessages.isEmpty;
  bool get hasMessages => allMessages.isNotEmpty;
  int get messageCount => allMessages.length;

  AthleteFeedbackState copyWith({
    List<CoachMessage>? allMessages,
  }) {
    return AthleteFeedbackState(
      allMessages: allMessages ?? this.allMessages,
    );
  }
}

@riverpod
class AthleteFeedbackController extends _$AthleteFeedbackController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<AthleteFeedbackState> build() async {
    return _loadMessages();
  }

  Future<AthleteFeedbackState> _loadMessages() async {
    // Get all active coach relationships for this athlete
    final coaches = await _coachService.getMyCoaches();

    if (coaches.isEmpty) {
      return const AthleteFeedbackState();
    }

    // Collect all messages from all coaches
    final allMessages = <CoachMessage>[];

    for (final relationship in coaches) {
      // Get conversation with this coach
      final messages = await _coachService.getConversation(
        coachUserId: relationship.coachUserId,
        athleteUserId: relationship.athleteUserId,
      );

      // Filter to only messages from coach (not athlete's own messages)
      final coachMessages = messages.where((m) => m.isSentByCoach);
      allMessages.addAll(coachMessages);
    }

    // Sort by date (newest first)
    allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return AthleteFeedbackState(
      allMessages: allMessages,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

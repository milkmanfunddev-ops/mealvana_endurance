import 'coach_athlete_relationship.dart';
import 'coach_message.dart';

/// State for the unified coach chat screen
/// Works for both coach and athlete perspectives
class CoachChatState {
  const CoachChatState({
    required this.relationship,
    this.messages = const [],
    this.pendingMessages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    required this.currentUserId,
  });

  final CoachAthleteRelationship relationship;
  final List<CoachMessage> messages; // Successfully sent messages from Supabase
  final List<CoachMessage> pendingMessages; // Messages being sent or failed
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String currentUserId;

  /// All messages (sent + pending) in chronological order
  /// Uses stable sort with createdAt as primary key and id as tiebreaker
  List<CoachMessage> get allMessages {
    final all = [...messages, ...pendingMessages];
    all.sort((a, b) {
      final timeComparison = a.createdAt.compareTo(b.createdAt);
      if (timeComparison != 0) return timeComparison;
      // Use message ID as tiebreaker for stable sort when timestamps are identical
      return a.id.compareTo(b.id);
    });
    return all;
  }

  /// Whether the current user is the coach in this conversation
  bool get isCurrentUserCoach => currentUserId == relationship.coachUserId;

  /// Whether the current user is the athlete in this conversation
  bool get isCurrentUserAthlete => currentUserId == relationship.athleteUserId;

  /// The ID of the other participant in the conversation
  String get otherParticipantId => isCurrentUserCoach
      ? relationship.athleteUserId
      : relationship.coachUserId;

  /// Display name of the other participant
  String get otherParticipantName => isCurrentUserCoach
      ? relationship.athleteDisplayName ?? 'Athlete'
      : relationship.coachDisplayName ?? 'Coach';

  /// The role label for the current user (for display)
  String get currentUserRole => isCurrentUserCoach ? 'Coach' : 'Athlete';

  /// The role label for the other participant (for display)
  String get otherParticipantRole => isCurrentUserCoach ? 'Athlete' : 'Coach';

  CoachChatState copyWith({
    CoachAthleteRelationship? relationship,
    List<CoachMessage>? messages,
    List<CoachMessage>? pendingMessages,
    bool? isLoading,
    bool? isSending,
    String? error,
    String? currentUserId,
  }) {
    return CoachChatState(
      relationship: relationship ?? this.relationship,
      messages: messages ?? this.messages,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }

  @override
  String toString() {
    return 'CoachChatState('
        'relationship: ${relationship.id}, '
        'messages: ${messages.length}, '
        'isCurrentUserCoach: $isCurrentUserCoach, '
        'isLoading: $isLoading, '
        'isSending: $isSending, '
        'error: $error)';
  }
}

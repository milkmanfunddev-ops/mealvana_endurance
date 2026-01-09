/// Message send status for offline queue management
enum MessageStatus {
  sending, // Message is being sent (optimistic)
  sent, // Message successfully saved to Supabase
  failed, // Message failed to send (will retry)
}

/// Coach message domain model
/// Represents a bidirectional message between a coach and an athlete.
/// Can also be used for comments on nutrition plans or activities.
class CoachMessage {
  final String id;
  final String coachUserId; // The coach in this conversation
  final String athleteUserId; // The athlete in this conversation
  final String senderUserId; // Who sent this specific message (coach or athlete)
  final String messageText;
  final String? nutritionPlanId; // Optional: comment on a nutrition plan
  final String? activityId; // Optional: comment on an activity
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional: populated when fetching messages with user info
  final String? senderDisplayName;

  // Message status for offline queue management (null = sent, for backward compatibility)
  final MessageStatus status;

  const CoachMessage({
    required this.id,
    required this.coachUserId,
    required this.athleteUserId,
    required this.senderUserId,
    required this.messageText,
    this.nutritionPlanId,
    this.activityId,
    this.isRead = false,
    required this.createdAt,
    required this.updatedAt,
    this.senderDisplayName,
    this.status = MessageStatus.sent,
  });

  CoachMessage copyWith({
    String? id,
    String? coachUserId,
    String? athleteUserId,
    String? senderUserId,
    String? messageText,
    String? nutritionPlanId,
    String? activityId,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? senderDisplayName,
    MessageStatus? status,
  }) {
    return CoachMessage(
      id: id ?? this.id,
      coachUserId: coachUserId ?? this.coachUserId,
      athleteUserId: athleteUserId ?? this.athleteUserId,
      senderUserId: senderUserId ?? this.senderUserId,
      messageText: messageText ?? this.messageText,
      nutritionPlanId: nutritionPlanId ?? this.nutritionPlanId,
      activityId: activityId ?? this.activityId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      status: status ?? this.status,
    );
  }

  factory CoachMessage.fromJson(Map<String, dynamic> json) {
    return CoachMessage(
      id: json['id'] as String,
      coachUserId: json['coach_user_id'] as String,
      athleteUserId: json['athlete_user_id'] as String,
      senderUserId: json['sender_user_id'] as String,
      messageText: json['message_text'] as String,
      nutritionPlanId: json['nutrition_plan_id'] as String?,
      activityId: json['activity_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // Optional joined field
      senderDisplayName: json['sender_display_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coach_user_id': coachUserId,
      'athlete_user_id': athleteUserId,
      'sender_user_id': senderUserId,
      'message_text': messageText,
      'nutrition_plan_id': nutritionPlanId,
      'activity_id': activityId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Whether this message was sent by the coach
  bool get isSentByCoach => senderUserId == coachUserId;

  /// Whether this message was sent by the athlete
  bool get isSentByAthlete => senderUserId == athleteUserId;

  /// Whether this message is a comment on a nutrition plan
  bool get isNutritionPlanComment => nutritionPlanId != null;

  /// Whether this message is a comment on an activity
  bool get isActivityComment => activityId != null;

  /// Whether this is a general conversation message (not linked to plan/activity)
  bool get isGeneralMessage => !isNutritionPlanComment && !isActivityComment;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

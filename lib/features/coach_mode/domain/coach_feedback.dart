/// Feedback type enum
enum FeedbackType {
  general,
  activity,
  nutrition,
  progress,
  goal;

  static FeedbackType fromString(String value) {
    return FeedbackType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FeedbackType.general,
    );
  }
}

/// Coach feedback domain model
/// Represents feedback from a coach to an athlete
class CoachFeedback {
  final String id;
  final String relationshipId;
  final String coachId;
  final String athleteUserId;
  final String? activityId;
  final String? nutritionPlanId;
  final String feedbackText;
  final FeedbackType feedbackType;
  final bool isVisibleToAthlete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CoachFeedback({
    required this.id,
    required this.relationshipId,
    required this.coachId,
    required this.athleteUserId,
    this.activityId,
    this.nutritionPlanId,
    required this.feedbackText,
    this.feedbackType = FeedbackType.general,
    this.isVisibleToAthlete = true,
    required this.createdAt,
    required this.updatedAt,
  });

  CoachFeedback copyWith({
    String? id,
    String? relationshipId,
    String? coachId,
    String? athleteUserId,
    String? activityId,
    String? nutritionPlanId,
    String? feedbackText,
    FeedbackType? feedbackType,
    bool? isVisibleToAthlete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CoachFeedback(
      id: id ?? this.id,
      relationshipId: relationshipId ?? this.relationshipId,
      coachId: coachId ?? this.coachId,
      athleteUserId: athleteUserId ?? this.athleteUserId,
      activityId: activityId ?? this.activityId,
      nutritionPlanId: nutritionPlanId ?? this.nutritionPlanId,
      feedbackText: feedbackText ?? this.feedbackText,
      feedbackType: feedbackType ?? this.feedbackType,
      isVisibleToAthlete: isVisibleToAthlete ?? this.isVisibleToAthlete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CoachFeedback.fromJson(Map<String, dynamic> json) {
    return CoachFeedback(
      id: json['id'] as String,
      relationshipId: json['relationship_id'] as String,
      coachId: json['coach_id'] as String,
      athleteUserId: json['athlete_user_id'] as String,
      activityId: json['activity_id'] as String?,
      nutritionPlanId: json['nutrition_plan_id'] as String?,
      feedbackText: json['feedback_text'] as String,
      feedbackType: FeedbackType.fromString(json['feedback_type'] as String),
      isVisibleToAthlete: json['is_visible_to_athlete'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'relationship_id': relationshipId,
      'coach_id': coachId,
      'athlete_user_id': athleteUserId,
      'activity_id': activityId,
      'nutrition_plan_id': nutritionPlanId,
      'feedback_text': feedbackText,
      'feedback_type': feedbackType.name,
      'is_visible_to_athlete': isVisibleToAthlete,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Check if this feedback is linked to a specific entity
  bool get isLinkedToActivity => activityId != null;
  bool get isLinkedToNutritionPlan => nutritionPlanId != null;
  bool get isGeneral => !isLinkedToActivity && !isLinkedToNutritionPlan;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachFeedback &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

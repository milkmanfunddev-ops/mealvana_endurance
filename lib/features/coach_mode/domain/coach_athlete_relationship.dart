/// Relationship status enum
enum RelationshipStatus {
  pending,
  active,
  declined,
  archived;

  static RelationshipStatus fromString(String value) {
    return RelationshipStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RelationshipStatus.pending,
    );
  }
}

/// Coach-Athlete relationship domain model
/// Represents a connection between a coach (user with is_coach=true) and an athlete
class CoachAthleteRelationship {
  final String id;
  final String coachUserId; // References users.id (user with is_coach=true)
  final String athleteUserId; // References users.id (the athlete)
  final RelationshipStatus status;
  final String requestedBy; // 'coach' or 'athlete'
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional: populated when fetching relationships with user info
  final String? coachDisplayName;
  final String? athleteDisplayName;

  const CoachAthleteRelationship({
    required this.id,
    required this.coachUserId,
    required this.athleteUserId,
    this.status = RelationshipStatus.pending,
    required this.requestedBy,
    required this.requestedAt,
    this.acceptedAt,
    this.declinedAt,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    this.coachDisplayName,
    this.athleteDisplayName,
  });

  CoachAthleteRelationship copyWith({
    String? id,
    String? coachUserId,
    String? athleteUserId,
    RelationshipStatus? status,
    String? requestedBy,
    DateTime? requestedAt,
    DateTime? acceptedAt,
    DateTime? declinedAt,
    DateTime? archivedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? coachDisplayName,
    String? athleteDisplayName,
  }) {
    return CoachAthleteRelationship(
      id: id ?? this.id,
      coachUserId: coachUserId ?? this.coachUserId,
      athleteUserId: athleteUserId ?? this.athleteUserId,
      status: status ?? this.status,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedAt: requestedAt ?? this.requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      declinedAt: declinedAt ?? this.declinedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coachDisplayName: coachDisplayName ?? this.coachDisplayName,
      athleteDisplayName: athleteDisplayName ?? this.athleteDisplayName,
    );
  }

  factory CoachAthleteRelationship.fromJson(Map<String, dynamic> json) {
    return CoachAthleteRelationship(
      id: json['id'] as String,
      coachUserId: json['coach_user_id'] as String,
      athleteUserId: json['athlete_user_id'] as String,
      status: RelationshipStatus.fromString(json['status'] as String),
      requestedBy: json['requested_by'] as String,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      declinedAt: json['declined_at'] != null
          ? DateTime.parse(json['declined_at'] as String)
          : null,
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // Optional joined fields
      coachDisplayName: json['coach_display_name'] as String?,
      athleteDisplayName: json['athlete_display_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coach_user_id': coachUserId,
      'athlete_user_id': athleteUserId,
      'status': status.name,
      'requested_by': requestedBy,
      'requested_at': requestedAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'declined_at': declinedAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Whether this relationship is active (accepted and not archived)
  bool get isActive => status == RelationshipStatus.active;

  /// Whether this relationship is pending acceptance
  bool get isPending => status == RelationshipStatus.pending;

  /// Whether this request was initiated by the coach
  bool get wasRequestedByCoach => requestedBy == 'coach';

  /// Whether this request was initiated by the athlete
  bool get wasRequestedByAthlete => requestedBy == 'athlete';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachAthleteRelationship &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

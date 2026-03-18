/// Coach specialization types
enum CoachSpecialization {
  running,
  cycling,
  swimming,
  triathlon,
  nutrition,
  strengthAndConditioning,
  mentalPerformance;

  String get name {
    return switch (this) {
      CoachSpecialization.running => 'running',
      CoachSpecialization.cycling => 'cycling',
      CoachSpecialization.swimming => 'swimming',
      CoachSpecialization.triathlon => 'triathlon',
      CoachSpecialization.nutrition => 'nutrition',
      CoachSpecialization.strengthAndConditioning =>
        'strength_and_conditioning',
      CoachSpecialization.mentalPerformance => 'mental_performance',
    };
  }

  /// Human-readable display name for UI
  String get displayName {
    return switch (this) {
      CoachSpecialization.running => 'Running',
      CoachSpecialization.cycling => 'Cycling',
      CoachSpecialization.swimming => 'Swimming',
      CoachSpecialization.triathlon => 'Triathlon',
      CoachSpecialization.nutrition => 'Nutrition',
      CoachSpecialization.strengthAndConditioning => 'Strength & Conditioning',
      CoachSpecialization.mentalPerformance => 'Mental Performance',
    };
  }

  static CoachSpecialization? fromString(String value) {
    return switch (value.toLowerCase()) {
      'running' => CoachSpecialization.running,
      'cycling' => CoachSpecialization.cycling,
      'swimming' => CoachSpecialization.swimming,
      'triathlon' => CoachSpecialization.triathlon,
      'nutrition' => CoachSpecialization.nutrition,
      'strength_and_conditioning' =>
        CoachSpecialization.strengthAndConditioning,
      'mental_performance' => CoachSpecialization.mentalPerformance,
      _ => null,
    };
  }
}

/// Coach model representing data from coaches table
/// Coaches are users who have applied and been approved to coach athletes
class Coach {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String? bio;
  final String status; // pending, approved, rejected
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Coach({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.bio,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display name combining first and last name
  String get displayName => '$firstName $lastName';

  /// Check if coach application is approved
  bool get isApproved => status == 'approved';

  /// Check if coach application is pending
  bool get isPending => status == 'pending';

  /// Check if coach application is rejected
  bool get isRejected => status == 'rejected';

  factory Coach.fromJson(Map<String, dynamic> json) {
    return Coach(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      bio: json['bio'] as String?,
      status: json['application_status'] as String? ?? 'pending',
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'bio': bio,
      'application_status': status,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Coach copyWith({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? email,
    String? bio,
    String? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Coach(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coach && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Simple coach info from users table (is_coach = true)
/// Used when checking if a user is a coach
class CoachInfo {
  final String userId;
  final String deviceId;
  final bool isCoach;
  final String? displayName; // From users.sender_name

  const CoachInfo({
    required this.userId,
    required this.deviceId,
    required this.isCoach,
    this.displayName,
  });

  factory CoachInfo.fromJson(Map<String, dynamic> json) {
    return CoachInfo(
      userId: json['id'] as String,
      deviceId: json['device_id'] as String,
      isCoach: json['is_coach'] as bool? ?? false,
      displayName: json['sender_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': userId,
      'device_id': deviceId,
      'is_coach': isCoach,
      'sender_name': displayName,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachInfo &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}

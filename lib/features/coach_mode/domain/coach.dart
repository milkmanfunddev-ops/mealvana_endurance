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
      CoachSpecialization.strengthAndConditioning => 'strength_and_conditioning',
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
      'strength_and_conditioning' => CoachSpecialization.strengthAndConditioning,
      'mental_performance' => CoachSpecialization.mentalPerformance,
      _ => null,
    };
  }
}

/// Simple coach info from users table (is_coach = true)
/// Used when checking if a user is a coach
/// Note: Coach registration is handled externally via Notion Forms
class CoachInfo {
  final String userId;
  final String deviceId;
  final bool isCoach;

  const CoachInfo({
    required this.userId,
    required this.deviceId,
    required this.isCoach,
  });

  factory CoachInfo.fromJson(Map<String, dynamic> json) {
    return CoachInfo(
      userId: json['id'] as String,
      deviceId: json['device_id'] as String,
      isCoach: json['is_coach'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': userId,
      'device_id': deviceId,
      'is_coach': isCoach,
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

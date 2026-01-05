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

/// Coach domain model
/// Represents a user with coaching capabilities
class Coach {
  final String id;
  final String userId;
  final String deviceId;
  final String coachName;
  final String? bio;
  final List<String> certifications;
  final List<String> specializations;
  final String? businessName;
  final String? websiteUrl;
  final String? email;
  final String? phone;
  final bool isActive;
  final bool isVerified;
  final int maxAthletes;
  final bool autoAcceptRequests;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Coach({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.coachName,
    this.bio,
    this.certifications = const [],
    this.specializations = const [],
    this.businessName,
    this.websiteUrl,
    this.email,
    this.phone,
    this.isActive = true,
    this.isVerified = false,
    this.maxAthletes = 50,
    this.autoAcceptRequests = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Coach copyWith({
    String? id,
    String? userId,
    String? deviceId,
    String? coachName,
    String? bio,
    List<String>? certifications,
    List<String>? specializations,
    String? businessName,
    String? websiteUrl,
    String? email,
    String? phone,
    bool? isActive,
    bool? isVerified,
    int? maxAthletes,
    bool? autoAcceptRequests,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Coach(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      coachName: coachName ?? this.coachName,
      bio: bio ?? this.bio,
      certifications: certifications ?? this.certifications,
      specializations: specializations ?? this.specializations,
      businessName: businessName ?? this.businessName,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      maxAthletes: maxAthletes ?? this.maxAthletes,
      autoAcceptRequests: autoAcceptRequests ?? this.autoAcceptRequests,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Coach.fromJson(Map<String, dynamic> json) {
    return Coach(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      deviceId: json['device_id'] as String,
      coachName: json['coach_name'] as String,
      bio: json['bio'] as String?,
      certifications: (json['certifications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      specializations: (json['specializations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      businessName: json['business_name'] as String?,
      websiteUrl: json['website_url'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      maxAthletes: json['max_athletes'] as int? ?? 50,
      autoAcceptRequests: json['auto_accept_requests'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'device_id': deviceId,
      'coach_name': coachName,
      'bio': bio,
      'certifications': certifications,
      'specializations': specializations,
      'business_name': businessName,
      'website_url': websiteUrl,
      'email': email,
      'phone': phone,
      'is_active': isActive,
      'is_verified': isVerified,
      'max_athletes': maxAthletes,
      'auto_accept_requests': autoAcceptRequests,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coach && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Alias for coachName for UI consistency
  String get displayName => coachName;

  /// Get specializations as typed enum values
  List<CoachSpecialization> get specializationsTyped {
    return specializations
        .map((s) => CoachSpecialization.fromString(s))
        .whereType<CoachSpecialization>()
        .toList();
  }

  /// Create a copy with typed specializations
  Coach copyWithSpecializations(List<CoachSpecialization> specs) {
    return copyWith(
      specializations: specs.map((s) => s.name).toList(),
    );
  }
}

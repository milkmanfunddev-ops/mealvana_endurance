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

/// Permission level enum
enum PermissionLevel {
  viewOnly,
  fullAccess,
  custom;

  static PermissionLevel fromString(String value) {
    switch (value) {
      case 'view_only':
        return PermissionLevel.viewOnly;
      case 'full_access':
        return PermissionLevel.fullAccess;
      case 'custom':
        return PermissionLevel.custom;
      default:
        return PermissionLevel.viewOnly;
    }
  }

  String toDbValue() {
    switch (this) {
      case PermissionLevel.viewOnly:
        return 'view_only';
      case PermissionLevel.fullAccess:
        return 'full_access';
      case PermissionLevel.custom:
        return 'custom';
    }
  }
}

/// Custom permissions for granular access control
class CustomPermissions {
  final bool viewActivities;
  final bool viewNutritionPlans;
  final bool viewCompletions;
  final bool viewNotes;
  final bool viewFoodPreferences;
  final bool createActivities;
  final bool createNutritionPlans;
  final bool modifyActivities;
  final bool modifyNutritionPlans;
  final bool deleteActivities;
  final bool deleteNutritionPlans;
  final bool addNotes;

  const CustomPermissions({
    this.viewActivities = true,
    this.viewNutritionPlans = true,
    this.viewCompletions = true,
    this.viewNotes = true,
    this.viewFoodPreferences = false,
    this.createActivities = false,
    this.createNutritionPlans = false,
    this.modifyActivities = false,
    this.modifyNutritionPlans = false,
    this.deleteActivities = false,
    this.deleteNutritionPlans = false,
    this.addNotes = true,
  });

  factory CustomPermissions.fromJson(Map<String, dynamic> json) {
    return CustomPermissions(
      viewActivities: json['view_activities'] as bool? ?? true,
      viewNutritionPlans: json['view_nutrition_plans'] as bool? ?? true,
      viewCompletions: json['view_completions'] as bool? ?? true,
      viewNotes: json['view_notes'] as bool? ?? true,
      viewFoodPreferences: json['view_food_preferences'] as bool? ?? false,
      createActivities: json['create_activities'] as bool? ?? false,
      createNutritionPlans: json['create_nutrition_plans'] as bool? ?? false,
      modifyActivities: json['modify_activities'] as bool? ?? false,
      modifyNutritionPlans: json['modify_nutrition_plans'] as bool? ?? false,
      deleteActivities: json['delete_activities'] as bool? ?? false,
      deleteNutritionPlans: json['delete_nutrition_plans'] as bool? ?? false,
      addNotes: json['add_notes'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'view_activities': viewActivities,
      'view_nutrition_plans': viewNutritionPlans,
      'view_completions': viewCompletions,
      'view_notes': viewNotes,
      'view_food_preferences': viewFoodPreferences,
      'create_activities': createActivities,
      'create_nutrition_plans': createNutritionPlans,
      'modify_activities': modifyActivities,
      'modify_nutrition_plans': modifyNutritionPlans,
      'delete_activities': deleteActivities,
      'delete_nutrition_plans': deleteNutritionPlans,
      'add_notes': addNotes,
    };
  }

  /// Default view-only permissions
  static const viewOnly = CustomPermissions();

  /// Full access permissions
  static const fullAccess = CustomPermissions(
    viewActivities: true,
    viewNutritionPlans: true,
    viewCompletions: true,
    viewNotes: true,
    viewFoodPreferences: true,
    createActivities: true,
    createNutritionPlans: true,
    modifyActivities: true,
    modifyNutritionPlans: true,
    deleteActivities: true,
    deleteNutritionPlans: true,
    addNotes: true,
  );
}

/// Coach-Athlete relationship domain model
class CoachAthleteRelationship {
  final String id;
  final String coachId;
  final String athleteUserId;
  final String athleteDeviceId;
  final RelationshipStatus status;
  final PermissionLevel permissionLevel;
  final CustomPermissions customPermissions;
  final String requestedBy; // 'coach' or 'athlete'
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? archivedAt;
  final String? coachNotes;
  final String? athleteNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CoachAthleteRelationship({
    required this.id,
    required this.coachId,
    required this.athleteUserId,
    required this.athleteDeviceId,
    this.status = RelationshipStatus.pending,
    this.permissionLevel = PermissionLevel.viewOnly,
    this.customPermissions = const CustomPermissions(),
    required this.requestedBy,
    required this.requestedAt,
    this.acceptedAt,
    this.declinedAt,
    this.archivedAt,
    this.coachNotes,
    this.athleteNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  CoachAthleteRelationship copyWith({
    String? id,
    String? coachId,
    String? athleteUserId,
    String? athleteDeviceId,
    RelationshipStatus? status,
    PermissionLevel? permissionLevel,
    CustomPermissions? customPermissions,
    String? requestedBy,
    DateTime? requestedAt,
    DateTime? acceptedAt,
    DateTime? declinedAt,
    DateTime? archivedAt,
    String? coachNotes,
    String? athleteNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CoachAthleteRelationship(
      id: id ?? this.id,
      coachId: coachId ?? this.coachId,
      athleteUserId: athleteUserId ?? this.athleteUserId,
      athleteDeviceId: athleteDeviceId ?? this.athleteDeviceId,
      status: status ?? this.status,
      permissionLevel: permissionLevel ?? this.permissionLevel,
      customPermissions: customPermissions ?? this.customPermissions,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedAt: requestedAt ?? this.requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      declinedAt: declinedAt ?? this.declinedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      coachNotes: coachNotes ?? this.coachNotes,
      athleteNotes: athleteNotes ?? this.athleteNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CoachAthleteRelationship.fromJson(Map<String, dynamic> json) {
    return CoachAthleteRelationship(
      id: json['id'] as String,
      coachId: json['coach_id'] as String,
      athleteUserId: json['athlete_user_id'] as String,
      athleteDeviceId: json['athlete_device_id'] as String,
      status: RelationshipStatus.fromString(json['status'] as String),
      permissionLevel:
          PermissionLevel.fromString(json['permission_level'] as String),
      customPermissions: json['custom_permissions'] != null
          ? CustomPermissions.fromJson(
              json['custom_permissions'] as Map<String, dynamic>)
          : const CustomPermissions(),
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
      coachNotes: json['coach_notes'] as String?,
      athleteNotes: json['athlete_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coach_id': coachId,
      'athlete_user_id': athleteUserId,
      'athlete_device_id': athleteDeviceId,
      'status': status.name,
      'permission_level': permissionLevel.toDbValue(),
      'custom_permissions': customPermissions.toJson(),
      'requested_by': requestedBy,
      'requested_at': requestedAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'declined_at': declinedAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
      'coach_notes': coachNotes,
      'athlete_notes': athleteNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Check if coach has a specific permission
  bool hasPermission(String permission) {
    if (status != RelationshipStatus.active) return false;

    if (permissionLevel == PermissionLevel.fullAccess) return true;

    if (permissionLevel == PermissionLevel.viewOnly) {
      return permission.startsWith('view');
    }

    // Custom permissions
    final json = customPermissions.toJson();
    return json[permission] as bool? ?? false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachAthleteRelationship &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

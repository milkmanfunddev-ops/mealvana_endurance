/// Activity domain model for calendar feature
class Activity {
  const Activity({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.title,
    required this.scheduledDateTime,
    this.status = ActivityStatus.planned,
    
    // Activity parameters
    this.distanceMiles,
    this.durationMinutes,
    this.paceTargetMinutesPerMile,
    this.intensityLevel,
    
    // Completion data
    this.completedAt,
    this.completionRating,
    this.completionNotes,
    this.actualDistanceMiles,
    this.actualDurationMinutes,
    
    // Metadata
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final ActivityType activityType;
  final String title;
  final DateTime scheduledDateTime;
  final ActivityStatus status;
  
  // Activity parameters
  final double? distanceMiles;
  final int? durationMinutes;
  final double? paceTargetMinutesPerMile;
  final IntensityLevel? intensityLevel;
  
  // Completion data
  final DateTime? completedAt;
  final int? completionRating;
  final String? completionNotes;
  final double? actualDistanceMiles;
  final int? actualDurationMinutes;
  
  // Metadata
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Activity copyWith({
    String? id,
    String? userId,
    ActivityType? activityType,
    String? title,
    DateTime? scheduledDateTime,
    ActivityStatus? status,
    double? distanceMiles,
    int? durationMinutes,
    double? paceTargetMinutesPerMile,
    IntensityLevel? intensityLevel,
    DateTime? completedAt,
    int? completionRating,
    String? completionNotes,
    double? actualDistanceMiles,
    int? actualDurationMinutes,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      activityType: activityType ?? this.activityType,
      title: title ?? this.title,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      status: status ?? this.status,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      paceTargetMinutesPerMile: paceTargetMinutesPerMile ?? this.paceTargetMinutesPerMile,
      intensityLevel: intensityLevel ?? this.intensityLevel,
      completedAt: completedAt ?? this.completedAt,
      completionRating: completionRating ?? this.completionRating,
      completionNotes: completionNotes ?? this.completionNotes,
      actualDistanceMiles: actualDistanceMiles ?? this.actualDistanceMiles,
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Activity &&
        other.id == id &&
        other.userId == userId &&
        other.activityType == activityType &&
        other.title == title &&
        other.scheduledDateTime == scheduledDateTime &&
        other.status == status &&
        other.distanceMiles == distanceMiles &&
        other.durationMinutes == durationMinutes &&
        other.paceTargetMinutesPerMile == paceTargetMinutesPerMile &&
        other.intensityLevel == intensityLevel &&
        other.completedAt == completedAt &&
        other.completionRating == completionRating &&
        other.completionNotes == completionNotes &&
        other.actualDistanceMiles == actualDistanceMiles &&
        other.actualDurationMinutes == actualDurationMinutes &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        activityType.hashCode ^
        title.hashCode ^
        scheduledDateTime.hashCode ^
        status.hashCode ^
        distanceMiles.hashCode ^
        durationMinutes.hashCode ^
        paceTargetMinutesPerMile.hashCode ^
        intensityLevel.hashCode ^
        completedAt.hashCode ^
        completionRating.hashCode ^
        completionNotes.hashCode ^
        actualDistanceMiles.hashCode ^
        actualDurationMinutes.hashCode ^
        notes.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        deletedAt.hashCode;
  }

  @override
  String toString() {
    return 'Activity(id: $id, userId: $userId, activityType: $activityType, title: $title, scheduledDateTime: $scheduledDateTime, status: $status)';
  }
}

/// Activity type enum
enum ActivityType {
  running,
  cycling,
  swimming,
}

/// Activity status enum
enum ActivityStatus {
  planned,
  inProgress,
  completed,
  skipped,
}

/// Intensity level enum
enum IntensityLevel {
  easy,
  moderate,
  hard,
  race,
}

/// Activity extensions for utility methods
extension ActivityExtensions on Activity {
  bool get isCompleted => status == ActivityStatus.completed;
  bool get isPlanned => status == ActivityStatus.planned;
  bool get isRunning => activityType == ActivityType.running;
  bool get isCycling => activityType == ActivityType.cycling;
  bool get isSwimming => activityType == ActivityType.swimming;
  
  /// Get formatted pace if available
  String? get formattedPace {
    if (paceTargetMinutesPerMile == null) return null;
    final minutes = paceTargetMinutesPerMile!.floor();
    final seconds = ((paceTargetMinutesPerMile! - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}/mi";
  }
  
  /// Get formatted duration if available
  String? get formattedDuration {
    if (durationMinutes == null) return null;
    final hours = durationMinutes! ~/ 60;
    final minutes = durationMinutes! % 60;
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    }
    return "${minutes}m";
  }
  
  /// Check if activity is in the past
  bool get isInPast => scheduledDateTime.isBefore(DateTime.now());
  
  /// Check if activity is today
  bool get isToday {
    final now = DateTime.now();
    return scheduledDateTime.year == now.year &&
           scheduledDateTime.month == now.month &&
           scheduledDateTime.day == now.day;
  }
}
/// Event domain model for calendar feature
class Event {
  const Event({
    required this.id,
    this.activityId, // Now nullable - events can exist without activities
    required this.eventType,
    this.eventSubtype,
    
    // Event details
    this.eventName,
    this.location,
    this.registrationUrl,
    this.startTime,
    
    // Goals and targets
    this.goalTimeMinutes,
    this.goalPaceMinutesPerMile,
    this.predictedFinishTimeMinutes,
    
    // Carb loading configuration
    this.hasCarbLoading = false,
    this.carbLoadingDays,
    this.carbLoadingStartDate,

    // Nutrition plan tracking
    this.hasNutritionPlan = false,
    
    // Registration and logistics
    this.bibNumber,
    this.waveStartTime,
    this.packetPickupInfo,
    
    // Results
    this.actualFinishTimeMinutes,
    this.finalPlacement,
    this.ageGroupPlacement,
    
    // Metadata
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? activityId; // Nullable - events can exist without activities
  final EventType eventType;
  final String? eventSubtype;
  
  // Event details
  final String? eventName;
  final String? location;
  final String? registrationUrl;
  final String? startTime;
  
  // Goals and targets
  final int? goalTimeMinutes;
  final double? goalPaceMinutesPerMile;
  final int? predictedFinishTimeMinutes;
  
  // Carb loading configuration
  final bool hasCarbLoading;
  final int? carbLoadingDays;
  final DateTime? carbLoadingStartDate;

  // Nutrition plan tracking
  final bool hasNutritionPlan;
  
  // Registration and logistics
  final String? bibNumber;
  final String? waveStartTime;
  final String? packetPickupInfo;
  
  // Results
  final int? actualFinishTimeMinutes;
  final int? finalPlacement;
  final int? ageGroupPlacement;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  Event copyWith({
    String? id,
    String? activityId,
    EventType? eventType,
    String? eventSubtype,
    String? eventName,
    String? location,
    String? registrationUrl,
    String? startTime,
    int? goalTimeMinutes,
    double? goalPaceMinutesPerMile,
    int? predictedFinishTimeMinutes,
    bool? hasCarbLoading,
    int? carbLoadingDays,
    DateTime? carbLoadingStartDate,
    bool? hasNutritionPlan,
    String? bibNumber,
    String? waveStartTime,
    String? packetPickupInfo,
    int? actualFinishTimeMinutes,
    int? finalPlacement,
    int? ageGroupPlacement,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      eventType: eventType ?? this.eventType,
      eventSubtype: eventSubtype ?? this.eventSubtype,
      eventName: eventName ?? this.eventName,
      location: location ?? this.location,
      registrationUrl: registrationUrl ?? this.registrationUrl,
      startTime: startTime ?? this.startTime,
      goalTimeMinutes: goalTimeMinutes ?? this.goalTimeMinutes,
      goalPaceMinutesPerMile: goalPaceMinutesPerMile ?? this.goalPaceMinutesPerMile,
      predictedFinishTimeMinutes: predictedFinishTimeMinutes ?? this.predictedFinishTimeMinutes,
      hasCarbLoading: hasCarbLoading ?? this.hasCarbLoading,
      carbLoadingDays: carbLoadingDays ?? this.carbLoadingDays,
      carbLoadingStartDate: carbLoadingStartDate ?? this.carbLoadingStartDate,
      hasNutritionPlan: hasNutritionPlan ?? this.hasNutritionPlan,
      bibNumber: bibNumber ?? this.bibNumber,
      waveStartTime: waveStartTime ?? this.waveStartTime,
      packetPickupInfo: packetPickupInfo ?? this.packetPickupInfo,
      actualFinishTimeMinutes: actualFinishTimeMinutes ?? this.actualFinishTimeMinutes,
      finalPlacement: finalPlacement ?? this.finalPlacement,
      ageGroupPlacement: ageGroupPlacement ?? this.ageGroupPlacement,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event &&
        other.id == id &&
        other.activityId == activityId &&
        other.eventType == eventType &&
        other.eventSubtype == eventSubtype &&
        other.eventName == eventName &&
        other.location == location &&
        other.registrationUrl == registrationUrl &&
        other.startTime == startTime &&
        other.goalTimeMinutes == goalTimeMinutes &&
        other.goalPaceMinutesPerMile == goalPaceMinutesPerMile &&
        other.predictedFinishTimeMinutes == predictedFinishTimeMinutes &&
        other.hasCarbLoading == hasCarbLoading &&
        other.carbLoadingDays == carbLoadingDays &&
        other.carbLoadingStartDate == carbLoadingStartDate &&
        other.hasNutritionPlan == hasNutritionPlan &&
        other.bibNumber == bibNumber &&
        other.waveStartTime == waveStartTime &&
        other.packetPickupInfo == packetPickupInfo &&
        other.actualFinishTimeMinutes == actualFinishTimeMinutes &&
        other.finalPlacement == finalPlacement &&
        other.ageGroupPlacement == ageGroupPlacement &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        activityId.hashCode ^
        eventType.hashCode ^
        eventSubtype.hashCode ^
        eventName.hashCode ^
        location.hashCode ^
        registrationUrl.hashCode ^
        startTime.hashCode ^
        goalTimeMinutes.hashCode ^
        goalPaceMinutesPerMile.hashCode ^
        predictedFinishTimeMinutes.hashCode ^
        hasCarbLoading.hashCode ^
        carbLoadingDays.hashCode ^
        carbLoadingStartDate.hashCode ^
        hasNutritionPlan.hashCode ^
        bibNumber.hashCode ^
        waveStartTime.hashCode ^
        packetPickupInfo.hashCode ^
        actualFinishTimeMinutes.hashCode ^
        finalPlacement.hashCode ^
        ageGroupPlacement.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'Event(id: $id, activityId: $activityId, eventType: $eventType, eventName: $eventName, location: $location)';
  }
}

/// Event type enum - represents the primary sport category
enum EventType {
  running,
  cycling,
  swimming,
  triathlon,
  duathlon,
  multisport,
}

/// Extension to convert EventType to database-compatible string
extension EventTypeExtension on EventType {
  /// Convert to database-compatible snake_case string
  String get dbValue {
    switch (this) {
      case EventType.running:
        return 'running';
      case EventType.cycling:
        return 'cycling';
      case EventType.swimming:
        return 'swimming';
      case EventType.triathlon:
        return 'triathlon';
      case EventType.duathlon:
        return 'duathlon';
      case EventType.multisport:
        return 'multisport';
    }
  }

  /// Get display name for the sport category
  String get displayName {
    switch (this) {
      case EventType.running:
        return 'Running';
      case EventType.cycling:
        return 'Cycling';
      case EventType.swimming:
        return 'Swimming';
      case EventType.triathlon:
        return 'Triathlon';
      case EventType.duathlon:
        return 'Duathlon';
      case EventType.multisport:
        return 'Multi-Sport';
    }
  }

  /// Get emoji icon for the sport category
  String get icon {
    switch (this) {
      case EventType.running:
        return '🏃';
      case EventType.cycling:
        return '🚴';
      case EventType.swimming:
        return '🏊';
      case EventType.triathlon:
        return '⚡';
      case EventType.duathlon:
        return '🔄';
      case EventType.multisport:
        return '🎯';
    }
  }

  /// Parse from database string to EventType
  static EventType fromDbValue(String value) {
    switch (value) {
      case 'running':
        return EventType.running;
      case 'cycling':
        return EventType.cycling;
      case 'swimming':
        return EventType.swimming;
      case 'triathlon':
        return EventType.triathlon;
      case 'duathlon':
        return EventType.duathlon;
      case 'multisport':
        return EventType.multisport;
      // Legacy support for old running event types
      case 'marathon':
      case 'half_marathon':
      case '10k':
      case '5k':
      case 'ultra_50k':
      case 'ultra_50m':
      case 'ultra_100k':
      case 'ultra_100m':
      case 'custom':
        return EventType.running;
      default:
        return EventType.running;
    }
  }
}

/// Event extensions for utility methods
extension EventExtensions on Event {
  /// Get formatted event type name (combines category and subtype)
  String get formattedEventType {
    if (eventSubtype != null && eventSubtype!.isNotEmpty) {
      return eventSubtype!;
    }
    return eventType.displayName;
  }
  
  /// Get formatted goal time if available
  String? get formattedGoalTime {
    if (goalTimeMinutes == null) return null;
    final hours = goalTimeMinutes! ~/ 60;
    final minutes = goalTimeMinutes! % 60;
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    }
    return "${minutes}m";
  }
  
  /// Get formatted goal pace if available
  String? get formattedGoalPace {
    if (goalPaceMinutesPerMile == null) return null;
    final minutes = goalPaceMinutesPerMile!.floor();
    final seconds = ((goalPaceMinutesPerMile! - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}/mi";
  }
  
  /// Check if event has results
  bool get hasResults => actualFinishTimeMinutes != null;
  
  /// Get formatted actual time if available
  String? get formattedActualTime {
    if (actualFinishTimeMinutes == null) return null;
    final hours = actualFinishTimeMinutes! ~/ 60;
    final minutes = actualFinishTimeMinutes! % 60;
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    }
    return "${minutes}m";
  }
}
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

/// Event type enum
enum EventType {
  marathon,
  halfMarathon,
  tenK,
  fiveK,
  ultra50K,
  ultra50M,
  ultra100K,
  ultra100M,
  custom,
}

/// Extension to convert EventType to database-compatible string
extension EventTypeExtension on EventType {
  /// Convert to database-compatible snake_case string
  String get dbValue {
    switch (this) {
      case EventType.marathon:
        return 'marathon';
      case EventType.halfMarathon:
        return 'half_marathon';
      case EventType.tenK:
        return '10k';
      case EventType.fiveK:
        return '5k';
      case EventType.ultra50K:
        return 'ultra_50k';
      case EventType.ultra50M:
        return 'ultra_50m';
      case EventType.ultra100K:
        return 'ultra_100k';
      case EventType.ultra100M:
        return 'ultra_100m';
      case EventType.custom:
        return 'custom';
    }
  }

  /// Parse from database string to EventType
  static EventType fromDbValue(String value) {
    switch (value) {
      case 'marathon':
        return EventType.marathon;
      case 'half_marathon':
        return EventType.halfMarathon;
      case '10k':
        return EventType.tenK;
      case '5k':
        return EventType.fiveK;
      case 'ultra_50k':
        return EventType.ultra50K;
      case 'ultra_50m':
        return EventType.ultra50M;
      case 'ultra_100k':
        return EventType.ultra100K;
      case 'ultra_100m':
        return EventType.ultra100M;
      case 'custom':
        return EventType.custom;
      default:
        return EventType.marathon;
    }
  }
}

/// Event extensions for utility methods
extension EventExtensions on Event {
  /// Get formatted event type name
  String get formattedEventType {
    switch (eventType) {
      case EventType.marathon:
        return 'Marathon';
      case EventType.halfMarathon:
        return 'Half Marathon';
      case EventType.tenK:
        return '10K';
      case EventType.fiveK:
        return '5K';
      case EventType.ultra50K:
        return '50K Ultra';
      case EventType.ultra50M:
        return '50 Mile Ultra';
      case EventType.ultra100K:
        return '100K Ultra';
      case EventType.ultra100M:
        return '100 Mile Ultra';
      case EventType.custom:
        return eventSubtype ?? 'Custom Event';
    }
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
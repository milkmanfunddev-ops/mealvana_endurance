import '../../../shared/domain/activity_type.dart';
import '../../../shared/utils/unit_formatter.dart';

/// Event domain model for calendar feature
class Event {
  const Event({
    required this.id,
    required this.userId, // User ID for direct filtering (eliminates need for joins)
    this.activityId, // Now nullable - events can exist without activities
    required this.eventType, // Event type: running, cycling, swimming, triathlon, duathlon, multisport
    this.eventSubtype,

    // Event details
    this.eventName,
    this.location,
    this.registrationUrl,
    this.eventDate, // Primary event date for calendar
    this.startTime, // Optional precise start time
    // Goals and targets
    this.goalTimeMinutes,
    this.goalPaceMinutesPerMile,
    this.predictedFinishTimeMinutes,

    // Carb loading configuration
    this.hasCarbLoading = false,
    this.carbLoadingDays,
    this.carbLoadingStartDate,

    // OBSOLETE: Use activityId != null instead
    @Deprecated('Use activityId != null to check for nutrition plan')
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

    // Sync tracking (offline-first architecture)
    this.needsUpload,
    this.localUpdatedAt,
  });

  final String id;
  final String
  userId; // User ID for direct filtering (eliminates need for joins)
  final String? activityId; // Nullable - events can exist without activities
  final ActivityType
  eventType; // Event type: running, cycling, swimming, triathlon, duathlon, multisport
  final String?
  eventSubtype; // Race distance: 'marathon', 'half_marathon', '10k', etc.

  // Event details
  final String? eventName;
  final String? location;
  final String? registrationUrl;
  final DateTime? eventDate; // Primary event date for calendar displays
  final String? startTime; // Optional precise start time with timezone

  // Goals and targets
  final int? goalTimeMinutes;
  final double? goalPaceMinutesPerMile;
  final int? predictedFinishTimeMinutes;

  // Carb loading configuration
  final bool hasCarbLoading;
  final int? carbLoadingDays;
  final DateTime? carbLoadingStartDate;

  // OBSOLETE: Use activityId != null instead
  @Deprecated('Use activityId != null to check for nutrition plan')
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

  // Sync tracking (offline-first architecture)
  final bool? needsUpload;
  final DateTime? localUpdatedAt;

  /// Serialize event to JSON for edge function payload
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'activityId': activityId,
      'eventType': eventType.dbValue, // Maps to event_type column in database
      'eventSubtype': eventSubtype,
      'eventName': eventName,
      'location': location,
      'registrationUrl': registrationUrl,
      'eventDate': eventDate?.toIso8601String(),
      'startTime': startTime,
      'goalTimeMinutes': goalTimeMinutes,
      'goalPaceMinutesPerMile': goalPaceMinutesPerMile,
      'predictedFinishTimeMinutes': predictedFinishTimeMinutes,
      'hasCarbLoading': hasCarbLoading,
      'carbLoadingDays': carbLoadingDays,
      'carbLoadingStartDate': carbLoadingStartDate?.toIso8601String(),
      'hasNutritionPlan':
          hasNutritionPlan, // OBSOLETE: kept for backward compatibility
      'bibNumber': bibNumber,
      'waveStartTime': waveStartTime,
      'packetPickupInfo': packetPickupInfo,
      'actualFinishTimeMinutes': actualFinishTimeMinutes,
      'finalPlacement': finalPlacement,
      'ageGroupPlacement': ageGroupPlacement,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Event copyWith({
    String? id,
    String? userId,
    String? activityId,
    ActivityType? eventType,
    String? eventSubtype,
    String? eventName,
    String? location,
    String? registrationUrl,
    DateTime? eventDate,
    String? startTime,
    int? goalTimeMinutes,
    double? goalPaceMinutesPerMile,
    int? predictedFinishTimeMinutes,
    bool? hasCarbLoading,
    int? carbLoadingDays,
    DateTime? carbLoadingStartDate,
    @Deprecated('Use activityId != null to check for nutrition plan')
    bool? hasNutritionPlan,
    String? bibNumber,
    String? waveStartTime,
    String? packetPickupInfo,
    int? actualFinishTimeMinutes,
    int? finalPlacement,
    int? ageGroupPlacement,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? needsUpload,
    DateTime? localUpdatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      activityId: activityId ?? this.activityId,
      eventType: eventType ?? this.eventType,
      eventSubtype: eventSubtype ?? this.eventSubtype,
      eventName: eventName ?? this.eventName,
      location: location ?? this.location,
      registrationUrl: registrationUrl ?? this.registrationUrl,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      goalTimeMinutes: goalTimeMinutes ?? this.goalTimeMinutes,
      goalPaceMinutesPerMile:
          goalPaceMinutesPerMile ?? this.goalPaceMinutesPerMile,
      predictedFinishTimeMinutes:
          predictedFinishTimeMinutes ?? this.predictedFinishTimeMinutes,
      hasCarbLoading: hasCarbLoading ?? this.hasCarbLoading,
      carbLoadingDays: carbLoadingDays ?? this.carbLoadingDays,
      carbLoadingStartDate: carbLoadingStartDate ?? this.carbLoadingStartDate,
      hasNutritionPlan: hasNutritionPlan ?? this.hasNutritionPlan,
      bibNumber: bibNumber ?? this.bibNumber,
      waveStartTime: waveStartTime ?? this.waveStartTime,
      packetPickupInfo: packetPickupInfo ?? this.packetPickupInfo,
      actualFinishTimeMinutes:
          actualFinishTimeMinutes ?? this.actualFinishTimeMinutes,
      finalPlacement: finalPlacement ?? this.finalPlacement,
      ageGroupPlacement: ageGroupPlacement ?? this.ageGroupPlacement,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      needsUpload: needsUpload ?? this.needsUpload,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
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

// Note: Old EventType enum (for race distances) has been removed. The Event model now uses:
// - eventType (ActivityType): Sport category - 'running', 'cycling', 'swimming', 'triathlon', 'duathlon', 'multisport'
// - eventSubtype (String?): Race distance - 'marathon', 'half_marathon', '10k', '5k', etc.

/// Event extensions for utility methods
extension EventExtensions on Event {
  /// Get formatted event type and subtype name
  String get formattedEventType {
    final sportName = eventType.displayName;
    if (eventSubtype != null && eventSubtype!.isNotEmpty) {
      // Format common event subtypes nicely
      final formatted = eventSubtype!
          .replaceAll('_', ' ')
          .split(' ')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
      return '$sportName - $formatted';
    }
    return sportName;
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
    return '${UnitFormatter.formatMinutesAsMinSec(goalPaceMinutesPerMile!)}/mi';
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

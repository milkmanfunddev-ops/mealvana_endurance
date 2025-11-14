/// Shared activity type enum used across activities, events, and nutrition features
/// Represents the type of endurance activity or event
///
/// Single-sport types: running, cycling, swimming
/// Multi-sport types: triathlon, duathlon, multisport
enum ActivityType {
  running,
  cycling,
  swimming,
  triathlon,
  duathlon,
  multisport;

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case ActivityType.running:
        return 'Run';
      case ActivityType.cycling:
        return 'Ride';
      case ActivityType.swimming:
        return 'Swim';
      case ActivityType.triathlon:
        return 'Triathlon';
      case ActivityType.duathlon:
        return 'Duathlon';
      case ActivityType.multisport:
        return 'Multisport';
    }
  }

  /// Get activity icon for UI (Material Icons)
  String get iconName {
    switch (this) {
      case ActivityType.running:
        return 'directions_run';
      case ActivityType.cycling:
        return 'directions_bike';
      case ActivityType.swimming:
        return 'pool';
      case ActivityType.triathlon:
        return 'pool'; // Could use a custom triathlon icon
      case ActivityType.duathlon:
        return 'directions_run'; // Run + Bike
      case ActivityType.multisport:
        return 'sports'; // Generic sports icon
    }
  }

  /// Get database-compatible value (matches Postgres activity_type_enum)
  String get dbValue {
    switch (this) {
      case ActivityType.running:
        return 'running';
      case ActivityType.cycling:
        return 'cycling';
      case ActivityType.swimming:
        return 'swimming';
      case ActivityType.triathlon:
        return 'triathlon';
      case ActivityType.duathlon:
        return 'duathlon';
      case ActivityType.multisport:
        return 'multisport';
    }
  }

  /// Check if this is a single-sport activity type
  bool get isSingleSport {
    return this == ActivityType.running ||
        this == ActivityType.cycling ||
        this == ActivityType.swimming;
  }

  /// Check if this is a multi-sport activity type
  bool get isMultiSport {
    return this == ActivityType.triathlon ||
        this == ActivityType.duathlon ||
        this == ActivityType.multisport;
  }

  /// Create ActivityType from database value
  static ActivityType fromDbValue(String dbValue) {
    switch (dbValue.toLowerCase()) {
      case 'running':
        return ActivityType.running;
      case 'cycling':
        return ActivityType.cycling;
      case 'swimming':
        return ActivityType.swimming;
      case 'triathlon':
        return ActivityType.triathlon;
      case 'duathlon':
        return ActivityType.duathlon;
      case 'multisport':
        return ActivityType.multisport;
      default:
        return ActivityType.running; // Default fallback
    }
  }
}

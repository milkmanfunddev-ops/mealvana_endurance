/// Shared activity type enum used across calendar and nutrition features
/// Represents the type of endurance activity (running, cycling, swimming)
enum ActivityType {
  running,
  cycling,
  swimming;

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case ActivityType.running:
        return 'Run';
      case ActivityType.cycling:
        return 'Ride';
      case ActivityType.swimming:
        return 'Swim';
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
    }
  }
}

import 'package:flutter/material.dart';

/// Shared activity type enum used across activities, events, and nutrition features
/// Represents the type of endurance activity or event
///
/// Single-sport types: running, cycling, swimming
/// Multi-sport types: triathlon, duathlon, multisport
/// Brick workouts: brick (combined consecutive training sessions)
/// Import-only catch-all: other (strength/hiking/walking/yoga/etc. imported
/// from providers that we don't natively support — see [isImportOnly])
enum ActivityType {
  running,
  cycling,
  swimming,
  triathlon,
  duathlon,
  multisport,
  brick,
  other;

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
      case ActivityType.brick:
        return 'Brick';
      case ActivityType.other:
        return 'Workout';
    }
  }

  /// Get activity icon for UI (Material Icons) as a string name.
  /// Prefer [icon] (IconData) in widgets — this is kept for any code that
  /// still stores/serializes icon names as strings.
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
      case ActivityType.brick:
        return 'link'; // Chain link icon representing connected sports
      case ActivityType.other:
        return 'fitness_center';
    }
  }

  /// Get activity icon for UI (real [IconData], for direct use in `Icon()`).
  IconData get icon {
    switch (this) {
      case ActivityType.running:
        return Icons.directions_run;
      case ActivityType.cycling:
        return Icons.directions_bike;
      case ActivityType.swimming:
        return Icons.pool;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
        return Icons.emoji_events; // Generic multi-sport icon
      case ActivityType.brick:
        return Icons.link; // Chain link icon representing connected sports
      case ActivityType.other:
        return Icons.fitness_center;
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
      case ActivityType.brick:
        return 'brick';
      case ActivityType.other:
        return 'other';
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
        this == ActivityType.multisport ||
        this == ActivityType.brick;
  }

  /// Check if this is a brick workout
  bool get isBrick {
    return this == ActivityType.brick;
  }

  /// True for activity types that can only arrive via provider import
  /// (Garmin/TrainingPeaks/FinalSurge/etc.) and are never manually created
  /// in-app. Import-only activities can be deleted but not edited, and never
  /// get a generated nutrition plan.
  bool get isImportOnly {
    return this == ActivityType.other;
  }

  /// True for activity types a user can manually create in-app.
  /// Convenience inverse of [isImportOnly].
  bool get isCreatable => !isImportOnly;

  /// Create ActivityType from database value.
  /// Unknown/unrecognized values map to [ActivityType.other] rather than
  /// silently misclassifying them as a run.
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
      case 'brick':
        return ActivityType.brick;
      case 'other':
        return ActivityType.other;
      default:
        return ActivityType
            .other; // Safe fallback — do not silently call it a run
    }
  }

  /// Get section title for nutrition plan phases (Before/During/After)
  /// Returns activity-specific titles like "Before Swim", "During Ride", etc.
  String getSectionTitle(String phase) {
    final activityWord = displayName;
    switch (phase.toLowerCase()) {
      case 'before':
      case 'before_run':
      case 'before-run':
      case 'pre-run':
      case 'pre':
        return 'Before $activityWord';
      case 'during':
      case 'during_run':
      case 'during-run':
      case 'during_cycling':
      case 'during_swim':
        return 'During $activityWord';
      case 'after':
      case 'after_run':
      case 'after-run':
      case 'after_cycling':
      case 'after_swim':
      case 'post-run':
      case 'post':
        return 'After $activityWord';
      default:
        return phase;
    }
  }
}

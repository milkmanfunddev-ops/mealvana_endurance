import 'package:drift/drift.dart';
import '../../../features/auth/domain/user_preferences.dart' as domain;

/// User profiles table definition for Drift
/// Stores user biometric data and preferences
@DataClassName('UserProfileEntry')
class UserProfilesTable extends Table {
  /// Device ID used as user identifier (maps to device_id in Supabase users table)
  TextColumn get id => text()();
  
  /// User's gender (stored as string enum)
  TextColumn get gender => text()();
  
  /// User's birthday
  DateTimeColumn get birthday => dateTime()();
  
  /// Height in feet (integer part)
  IntColumn get heightFeet => integer()();
  
  /// Height in inches (remaining part)
  IntColumn get heightInches => integer()();
  
  /// Weight in pounds
  RealColumn get weightPounds => real()();
  
  /// Whether user runs with a water bottle
  BoolColumn get runsWithWaterBottle => boolean()();
  
  /// Gut training level (stored as string enum)
  TextColumn get gutTraining => text()();
  
  /// Whether user has completed onboarding
  BoolColumn get onboardingCompleted => boolean().withDefault(const Constant(false))();
  
  /// When the profile was created
  DateTimeColumn get createdAt => dateTime()();
  
  /// When the profile was last updated
  DateTimeColumn get updatedAt => dateTime()();
  
  /// App version when profile was created/updated
  TextColumn get appVersion => text()();
  
  /// Notification preferences
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get defaultReminderDay => integer().withDefault(const Constant(4))(); // Thursday
  IntColumn get defaultReminderHour => integer().withDefault(const Constant(17))(); // 5 PM
  IntColumn get defaultReminderMinute => integer().withDefault(const Constant(0))();
  BoolColumn get defaultReminderRecurring => boolean().withDefault(const Constant(false))();
  
  /// Temporary plan storage (unsaved plan that persists through app restart)
  TextColumn get tempPlanData => text().nullable()();
  
  /// Whether the swipe hint animation has been shown to this user
  BoolColumn get swipeHintShown => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'users';
}

// Extensions and helpers removed - conversions handled in app_database.dart
// to avoid circular dependency issues with generated code
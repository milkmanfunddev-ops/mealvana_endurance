import 'package:drift/drift.dart';
import 'dart:convert';

/// User profiles table definition for Drift - matches Supabase users table schema
/// Stores user biometric data and preferences
@DataClassName('UserProfileEntry')
class UserProfilesTable extends Table {
  /// UUID primary key (matches Supabase users.id)
  /// Note: During migration from device_id, this accepts any string length
  /// Will eventually be UUID-only after full migration to Supabase Auth
  TextColumn get id => text()();

  /// Device ID used to identify the device (matches Supabase users.device_id)
  /// NOT unique - multiple users can share the same device (family devices)
  /// This will become nullable during auth migration (legacy field)
  TextColumn get deviceId => text().named('device_id')();

  /// Auth columns for Supabase authentication integration
  /// Explicit reference to Supabase auth.uid() - this is the canonical user ID
  TextColumn get authUserId => text().withLength(min: 36, max: 36).nullable().named('auth_user_id')();

  /// OAuth provider used: 'anonymous', 'google', 'apple', 'email'
  TextColumn get authProvider => text().withDefault(const Constant('anonymous')).named('auth_provider')();

  /// Whether this user is anonymous (not linked to permanent account)
  BoolColumn get isAnonymous => boolean().withDefault(const Constant(true)).named('is_anonymous')();

  /// When the profile was created (matches Supabase users.created_at)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the profile was last updated (matches Supabase users.updated_at)
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  /// User's gender (stored as string enum: 'male', 'female', 'other')
  TextColumn get gender => text().nullable()();

  /// User's birthday
  DateTimeColumn get birthday => dateTime().nullable()();

  /// Height in feet (integer part)
  IntColumn get heightFeet => integer().nullable().named('height_feet')();

  /// Height in inches (remaining part)
  IntColumn get heightInches => integer().nullable().named('height_inches')();

  /// Weight in pounds (numeric with 2 decimal places to match Supabase)
  RealColumn get weightPounds => real().nullable().named('weight_pounds')();

  /// Whether user runs with a water bottle
  BoolColumn get runsWithWaterBottle => boolean().withDefault(const Constant(false)).named('runs_with_water_bottle')();

  /// Food preferences stored as JSONB (matches Supabase users.food_preferences)
  TextColumn get foodPreferences => text().map(const FoodPreferencesJsonConverter()).withDefault(const Constant('{}')).named('food_preferences')();

  /// Preferred distance unit: 'miles' or 'kilometers'
  TextColumn get preferredDistanceUnit => text().withDefault(const Constant('miles')).named('preferred_distance_unit')();

  /// Preferred pace unit: 'minPerMile' or 'minPerKm'
  TextColumn get preferredPaceUnit => text().withDefault(const Constant('minPerMile')).named('preferred_pace_unit')();

  /// Gut training level (stored as string enum: 'low', 'moderate', 'high')
  TextColumn get gutTrainingLevel => text().withDefault(const Constant('moderate')).named('gut_training_level')();

  /// Sweat rate category (stored as string enum: 'light', 'medium', 'heavy')
  TextColumn get sweatRate => text().withDefault(const Constant('medium')).named('sweat_rate')();

  /// Whether user has completed onboarding
  BoolColumn get onboardingCompleted => boolean().withDefault(const Constant(false)).named('onboarding_completed')();

  /// Last time user was active
  DateTimeColumn get lastActiveAt => dateTime().withDefault(currentDateAndTime).named('last_active_at')();

  /// App version when profile was created/updated
  TextColumn get appVersion => text().nullable().named('app_version')();

  /// Notification preferences (matches Supabase users schema)
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(false)).named('notifications_enabled')();
  IntColumn get defaultReminderDay => integer().withDefault(const Constant(4)).named('default_reminder_day')(); // Thursday
  IntColumn get defaultReminderHour => integer().withDefault(const Constant(17)).named('default_reminder_hour')(); // 5 PM
  IntColumn get defaultReminderMinute => integer().withDefault(const Constant(0)).named('default_reminder_minute')();
  BoolColumn get defaultReminderRecurring => boolean().withDefault(const Constant(false)).named('default_reminder_recurring')();

  /// Temporary plan storage (unsaved plan that persists through app restart) - Drift-only field
  TextColumn get tempPlanData => text().nullable().named('temp_plan_data')();

  /// Whether the swipe hint animation has been shown to this user - Drift-only field
  BoolColumn get swipeHintShown => boolean().withDefault(const Constant(false)).named('swipe_hint_shown')();

  // NEW: Calendar preferences
  TextColumn get calendarWeekStart => text().withDefault(const Constant('monday')).named('calendar_week_start')(); // 'sunday', 'monday'
  TextColumn get defaultActivityTime => text().withDefault(const Constant('07:00:00')).named('default_activity_time')();
  TextColumn get defaultActivityDay => text().withDefault(const Constant('saturday')).named('default_activity_day')(); // Day of week
  BoolColumn get autoGenerateNutrition => boolean().withDefault(const Constant(true)).named('auto_generate_nutrition')();
  BoolColumn get completionReminders => boolean().withDefault(const Constant(true)).named('completion_reminders')();

  // Sharing preferences
  TextColumn get senderName => text().nullable().named('sender_name')(); // Name used when sharing plans

  // Default pace/speed for workout estimation
  RealColumn get defaultRunningPaceMinPerMile => real().nullable().named('default_running_pace_min_per_mile')(); // Minutes per mile
  RealColumn get defaultCyclingSpeedMph => real().nullable().named('default_cycling_speed_mph')(); // Miles per hour
  IntColumn get defaultSwimmingPacePer100Sec => integer().nullable().named('default_swimming_pace_per_100_sec')(); // Seconds per 100 yards/meters

  // User identity - optional first and last name for coach mode identification
  /// User's first name (optional, used for coach mode athlete identification)
  TextColumn get firstName => text().nullable().named('first_name')();
  /// User's last name (optional, used for coach mode athlete identification)
  TextColumn get lastName => text().nullable().named('last_name')();

  /// User's email address (optional, captured from auth or entered manually)
  TextColumn get email => text().nullable().named('email')();

  // NEW: Dietary preference and allergies for onboarding revamp
  /// User's dietary preference (single-select, nullable - user can skip in onboarding)
  /// Values: omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb
  TextColumn get dietaryPreference => text().nullable().named('dietary_preference')();

  /// User's allergies stored as PostgreSQL array format (e.g., '{dairy,gluten,peanuts}')
  /// Values: dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts
  TextColumn get allergies => text().withDefault(const Constant('{}')).named('allergies')();

  /// User's preferred unit system for display (imperial or metric)
  /// Values: imperial, metric
  /// Default: imperial (US-centric app)
  TextColumn get unitSystem => text()
      .withDefault(const Constant('imperial'))
      .named('unit_system')();

  /// User-configured nutrition target overrides stored as JSON.
  /// Null means "use algorithm defaults" for all fields.
  TextColumn get nutritionTargetOverrides => text().nullable().named('nutrition_target_overrides')();

  // Daily macro calculation fields
  /// Body fat percentage (optional, for Cunningham RMR formula)
  RealColumn get bodyFatPct => real().nullable().named('body_fat_pct')();

  /// Lifestyle activity level: desk, mixed, active, very_active
  TextColumn get lifestyle => text().withDefault(const Constant('mixed')).named('lifestyle')();

  /// Typical weekly training hours (for volume tier calculation)
  RealColumn get typicalWeeklyHours => real().nullable().named('typical_weekly_hours')();

  /// Whether user opts in to carb cycling on easy days
  BoolColumn get carbCycleOptIn => boolean().withDefault(const Constant(false)).named('carb_cycle_opt_in')();

  /// Training phase: base, build, peak, taper, race_week, off_season
  TextColumn get trainingPhase => text().withDefault(const Constant('base')).named('training_phase')();

  /// Sync tracking: whether this record needs to be uploaded to Supabase
  /// Used for background sync after onboarding registration
  BoolColumn get needsUpload => boolean().withDefault(const Constant(false)).named('needs_upload')();

  // NOTE: is_coach column removed - coach status is now determined by
  // checking the coaches table for an approved record.
  // The column may still exist in older databases but is no longer used.

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'users';

  @override
  List<String> get customConstraints => [
    // Note: device_id is NOT unique - multiple users can share the same device
    "CHECK (gender IN ('male', 'female', 'other') OR gender IS NULL)",
    "CHECK (gut_training_level IN ('low', 'moderate', 'high'))",
    "CHECK (sweat_rate IN ('light', 'medium', 'heavy'))",
    "CHECK (preferred_distance_unit IN ('miles', 'kilometers'))",
    "CHECK (preferred_pace_unit IN ('minPerMile', 'minPerKm'))",
    "CHECK (calendar_week_start IN ('sunday', 'monday'))",
    "CHECK (default_activity_day IN ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'))",
    "CHECK (auth_provider IN ('anonymous', 'email', 'google', 'apple'))",
    "CHECK (dietary_preference IN ('omnivore', 'vegetarian', 'pescatarian', 'vegan', 'mediterranean', 'paleo', 'keto', 'low_carb') OR dietary_preference IS NULL)",
    "CHECK (unit_system IN ('imperial', 'metric'))",
    "CHECK (lifestyle IN ('desk', 'mixed', 'active', 'very_active'))",
    "CHECK (training_phase IN ('base', 'build', 'peak', 'taper', 'race_week', 'off_season'))",
  ];
}

/// JSON type converter for food preferences JSONB field
class FoodPreferencesJsonConverter extends TypeConverter<Map<String, dynamic>, String> {
  const FoodPreferencesJsonConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    try {
      return Map<String, dynamic>.from(
        const JsonDecoder().convert(fromDb)
      );
    } catch (e) {
      return {};
    }
  }

  @override
  String toSql(Map<String, dynamic> value) {
    return const JsonEncoder().convert(value);
  }
}

// Extensions and helpers removed - conversions handled in app_database.dart
// to avoid circular dependency issues with generated code
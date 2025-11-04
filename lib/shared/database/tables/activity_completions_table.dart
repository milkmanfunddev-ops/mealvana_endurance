import 'package:drift/drift.dart';

/// Table for detailed completion data with voice notes and ratings
@DataClassName('ActivityCompletion')
class ActivityCompletionsTable extends Table {
  TextColumn get id => text()(); // PRIMARY KEY
  TextColumn get activityId => text().unique().named('activity_id')(); // FOREIGN KEY to activities.id
  TextColumn get userId => text().named('user_id')(); // FOREIGN KEY to user_profiles.id
  
  // Completion details
  DateTimeColumn get completedAt => dateTime().named('completed_at')();
  TextColumn get completionType => text().withDefault(const Constant('manual')).named('completion_type')(); // 'manual', 'automatic', 'imported'
  
  // Performance data
  RealColumn get actualDistanceMiles => real().nullable().named('actual_distance_miles')();
  IntColumn get actualDurationMinutes => integer().nullable().named('actual_duration_minutes')();
  RealColumn get averagePaceMinutesPerMile => real().nullable().named('average_pace_minutes_per_mile')();
  IntColumn get maxHeartRate => integer().nullable().named('max_heart_rate')();
  IntColumn get averageHeartRate => integer().nullable().named('average_heart_rate')();
  IntColumn get caloriesBurned => integer().nullable().named('calories_burned')();
  
  // User feedback
  IntColumn get effortRating => integer().nullable().named('effort_rating')(); // How hard was the workout (1-5)
  IntColumn get nutritionRating => integer().nullable().named('nutrition_rating')(); // How well did nutrition work (1-5)
  IntColumn get overallSatisfaction => integer().nullable().named('overall_satisfaction')(); // Overall experience (1-5)
  
  // Notes and feedback
  TextColumn get textNotes => text().nullable().named('text_notes')();
  TextColumn get voiceNoteId => text().nullable().named('voice_note_id')(); // References existing voice note entry when available
  BoolColumn get hasVoiceRecording => boolean().withDefault(const Constant(false)).named('has_voice_recording')();
  
  // Conditions
  TextColumn get weatherConditions => text().nullable().named('weather_conditions')();
  IntColumn get temperatureFahrenheit => integer().nullable().named('temperature_fahrenheit')();
  IntColumn get humidityPercent => integer().nullable().named('humidity_percent')();
  
  // Analysis (populated by background processing)
  RealColumn get nutritionAdherenceScore => real().nullable().named('nutrition_adherence_score')(); // 0.0 to 1.0 based on plan execution
  RealColumn get performanceVsTarget => real().nullable().named('performance_vs_target')(); // Actual performance vs. planned

  // Sync tracking (offline-first architecture)
  BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();
  DateTimeColumn get localUpdatedAt => dateTime().nullable().named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};
  
  @override
  String get tableName => 'activity_completions';
  
  @override
  List<String> get customConstraints => [
    "CHECK (completion_type IN ('manual', 'automatic', 'imported'))",
    'CHECK (effort_rating IS NULL OR (effort_rating >= 1 AND effort_rating <= 5))',
    'CHECK (nutrition_rating IS NULL OR (nutrition_rating >= 1 AND nutrition_rating <= 5))',
    'CHECK (overall_satisfaction IS NULL OR (overall_satisfaction >= 1 AND overall_satisfaction <= 5))',
    'CHECK (nutrition_adherence_score IS NULL OR (nutrition_adherence_score >= 0.0 AND nutrition_adherence_score <= 1.0))',
  ];
}
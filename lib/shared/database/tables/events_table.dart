import 'package:drift/drift.dart';

/// Table for specialized event data linked to activities
@DataClassName('Event')
class EventsTable extends Table {
  TextColumn get id => text()(); // PRIMARY KEY
  TextColumn get activityId => text().nullable().named('activity_id')(); // OPTIONAL FOREIGN KEY to activities.id (events may exist without an activity)
  TextColumn get userId => text().named('user_id')(); // FOREIGN KEY to user_profiles.id

  // Event classification
  TextColumn get eventType => text().named('event_type')(); // 'marathon', 'half_marathon', '10k', '5k', 'ultra_50k', 'ultra_50m', 'ultra_100k', 'ultra_100m', 'custom'
  TextColumn get eventSubtype => text().nullable().named('event_subtype')(); // For custom categorization
  
  // Event details
  TextColumn get eventName => text().nullable().named('event_name')();
  TextColumn get location => text().nullable().named('location')();
  TextColumn get registrationUrl => text().nullable().named('registration_url')();
  TextColumn get startTime => text().nullable().named('start_time')(); // Separate from activity scheduled_date_time for precise race start
  
  // Goals and targets
  IntColumn get goalTimeMinutes => integer().nullable().named('goal_time_minutes')();
  RealColumn get goalPaceMinutesPerMile => real().nullable().named('goal_pace_minutes_per_mile')();
  IntColumn get predictedFinishTimeMinutes => integer().nullable().named('predicted_finish_time_minutes')();
  
  // Carb loading configuration
  BoolColumn get hasCarbLoading => boolean().withDefault(const Constant(false)).named('has_carb_loading')();
  IntColumn get carbLoadingDays => integer().nullable().named('carb_loading_days')(); // 1, 2, 3, 7
  DateTimeColumn get carbLoadingStartDate => dateTime().nullable().named('carb_loading_start_date')();

  // Nutrition plan tracking
  BoolColumn get hasNutritionPlan => boolean().withDefault(const Constant(false)).named('has_nutrition_plan')();
  
  // Registration and logistics
  TextColumn get bibNumber => text().nullable().named('bib_number')();
  TextColumn get waveStartTime => text().nullable().named('wave_start_time')();
  TextColumn get packetPickupInfo => text().nullable().named('packet_pickup_info')();
  
  // Results (post-event)
  IntColumn get actualFinishTimeMinutes => integer().nullable().named('actual_finish_time_minutes')();
  IntColumn get finalPlacement => integer().nullable().named('final_placement')();
  IntColumn get ageGroupPlacement => integer().nullable().named('age_group_placement')();
  
  // Metadata
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  // Sync tracking (offline-first architecture)
  BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();
  DateTimeColumn get localUpdatedAt => dateTime().nullable().named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};
  
  @override
  String get tableName => 'events';
  
  @override
  List<String> get customConstraints => [
    "CHECK (event_type IN ('marathon', 'half_marathon', '10k', '5k', 'ultra_50k', 'ultra_50m', 'ultra_100k', 'ultra_100m', 'custom'))",
    'CHECK (carb_loading_days IS NULL OR carb_loading_days IN (1, 2, 3, 7))',
  ];
}
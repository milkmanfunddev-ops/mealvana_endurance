import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Enhanced carb loading plans table for events
@DataClassName('CarbLoadingPlan')
class CarbLoadingPlansTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())(); // PRIMARY KEY (UUID)
  TextColumn get eventId => text().nullable().named('event_id')(); // FOREIGN KEY to events.id (nullable: can have standalone plans)
  TextColumn get userId => text().named('user_id')(); // FOREIGN KEY to users.id (UUID)
  
  // Plan configuration
  IntColumn get totalDays => integer().named('total_days')(); // 1, 2, 3, 7
  DateTimeColumn get startDate => dateTime().named('start_date')();
  DateTimeColumn get endDate => dateTime().named('end_date')();
  
  // Daily targets (calculated from user weight and plan duration)
  IntColumn get dailyCarbTargetGrams => integer().named('daily_carb_target_grams')();
  IntColumn get dailyCalorieTarget => integer().nullable().named('daily_calorie_target')();
  
  // Plan metadata
  DateTimeColumn get generatedAt => dateTime().named('generated_at')();
  TextColumn get algorithmVersion => text().withDefault(const Constant('v1.0')).named('algorithm_version')();
  
  // Completion tracking
  RealColumn get adherenceScore => real().nullable().named('adherence_score')(); // 0.0 to 1.0 based on logged meals
  DateTimeColumn get completedAt => dateTime().nullable().named('completed_at')();

  // Sync tracking (offline-first architecture)
  BoolColumn get needsUpload =>
      boolean().withDefault(const Constant(false)).named('needs_upload')();
  DateTimeColumn get localUpdatedAt =>
      dateTime().clientDefault(() => DateTime.now()).named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'carb_loading_plans';
  
  @override
  List<String> get customConstraints => [
    'CHECK (total_days IN (1, 2, 3, 7))',
    'CHECK (adherence_score IS NULL OR (adherence_score >= 0.0 AND adherence_score <= 1.0))',
  ];
}

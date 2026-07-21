import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Individual day entries within a carb loading plan
@DataClassName('CarbLoadingDay')
class CarbLoadingDaysTable extends Table {
  TextColumn get id =>
      text().clientDefault(() => const Uuid().v4())(); // PRIMARY KEY (UUID)
  TextColumn get carbLoadingPlanId => text().named(
    'carb_loading_plan_id',
  )(); // FOREIGN KEY to carb_loading_plans.id

  // Day information
  DateTimeColumn get planDate => dateTime().named('plan_date')();
  IntColumn get dayNumber => integer().named(
    'day_number',
  )(); // 1, 2, 3, etc. (1 = first day, last number = race day - 1)

  // Daily targets
  IntColumn get carbTargetGrams => integer().named('carb_target_grams')();
  RealColumn get carbProtocolGPerKg => real()
      .withDefault(const Constant(8.0))
      .named(
        'carb_protocol_g_per_kg',
      )(); // Carbohydrate protocol (e.g., 8.0 for 8g/kg bodyweight)
  IntColumn get calorieTarget => integer().nullable().named('calorie_target')();
  IntColumn get mealCount => integer()
      .withDefault(const Constant(6))
      .named('meal_count')(); // breakfast, snack, lunch, snack, dinner, evening

  // Meal distribution (percentages that sum to 1.0)
  RealColumn get breakfastPercent =>
      real().withDefault(const Constant(0.25)).named('breakfast_percent')();
  RealColumn get morningSnackPercent =>
      real().withDefault(const Constant(0.10)).named('morning_snack_percent')();
  RealColumn get lunchPercent =>
      real().withDefault(const Constant(0.25)).named('lunch_percent')();
  RealColumn get afternoonSnackPercent => real()
      .withDefault(const Constant(0.15))
      .named('afternoon_snack_percent')();
  RealColumn get dinnerPercent =>
      real().withDefault(const Constant(0.20)).named('dinner_percent')();
  RealColumn get eveningSnackPercent =>
      real().withDefault(const Constant(0.05)).named('evening_snack_percent')();

  // Progress tracking
  IntColumn get loggedCarbsGrams =>
      integer().withDefault(const Constant(0)).named('logged_carbs_grams')();
  IntColumn get loggedCalories =>
      integer().withDefault(const Constant(0)).named('logged_calories')();
  BoolColumn get completed =>
      boolean().withDefault(const Constant(false)).named('completed')();

  // Sync tracking (offline-first architecture)
  BoolColumn get needsUpload =>
      boolean().withDefault(const Constant(false)).named('needs_upload')();
  DateTimeColumn get localUpdatedAt => dateTime()
      .clientDefault(() => DateTime.now())
      .named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'carb_loading_days';

  @override
  List<String> get customConstraints => [
    'CHECK (day_number > 0)',
    'CHECK (carb_target_grams > 0)',
    'CHECK (meal_count > 0)',
    'CHECK (breakfast_percent >= 0.0 AND breakfast_percent <= 1.0)',
    'CHECK (morning_snack_percent >= 0.0 AND morning_snack_percent <= 1.0)',
    'CHECK (lunch_percent >= 0.0 AND lunch_percent <= 1.0)',
    'CHECK (afternoon_snack_percent >= 0.0 AND afternoon_snack_percent <= 1.0)',
    'CHECK (dinner_percent >= 0.0 AND dinner_percent <= 1.0)',
    'CHECK (evening_snack_percent >= 0.0 AND evening_snack_percent <= 1.0)',
    'CHECK (logged_carbs_grams >= 0)',
    'CHECK (logged_calories >= 0)',
  ];

  @override
  List<Set<Column>> get uniqueKeys => [
    {carbLoadingPlanId, planDate}, // One entry per plan per date
  ];
}

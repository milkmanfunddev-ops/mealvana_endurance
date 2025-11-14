import 'package:drift/drift.dart';

/// Carb Loading Foods table - global default foods for carb loading
/// These are pre-seeded foods available to all users (cereal, pasta, etc.)
@DataClassName('CarbLoadingFood')
class CarbLoadingFoodsTable extends Table {
  TextColumn get id => text()(); // PRIMARY KEY (UUID)
  TextColumn get name => text()(); // 'cereal', 'pasta_marinara', 'banana'
  TextColumn get displayName => text().named('display_name')(); // 'Cereal (1/2 cup dry)'
  TextColumn get displayNamePlural => text().nullable().named('display_name_plural')(); // 'Cereals (1/2 cup dry)'
  RealColumn get carbsPerServing => real().named('carbs_per_serving')(); // 14.0
  TextColumn get imageAddress => text().nullable().named('image_address')();
  BoolColumn get isDefault => boolean().withDefault(const Constant(true)).named('is_default')(); // Pre-seeded vs admin-added

  // Array-based meal types column (stored as JSON string in SQLite, array in Postgres)
  /// Meal types: array of meal_type_enum values (e.g., ['breakfast', 'lunch', 'dinner'])
  TextColumn get mealTypes => text().nullable().named('meal_types')();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'carb_loading_foods';

  @override
  List<String> get customConstraints => [
    'CHECK (carbs_per_serving > 0)',
  ];
}

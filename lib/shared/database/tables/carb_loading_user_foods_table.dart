import 'package:drift/drift.dart';

/// Carb Loading User Foods table - user-created carb loading foods
/// Users can add custom foods, scan barcodes, or import from nutrition plan foods
@DataClassName('CarbLoadingUserFood')
class CarbLoadingUserFoodsTable extends Table {
  TextColumn get id => text()(); // PRIMARY KEY (UUID)
  TextColumn get deviceId => text().named('device_id')(); // Device that created this food
  TextColumn get userId => text().named('user_id')(); // User ID (UUID) - references users.id
  TextColumn get clientFoodId => text().nullable().named('client_food_id')(); // Client-side ID for sync tracking
  TextColumn get name => text()(); // 'my_favorite_pasta'
  TextColumn get displayName => text().named('display_name')(); // 'My Favorite Pasta (2 cups)'
  TextColumn get displayNamePlural => text().nullable().named('display_name_plural')(); // 'My Favorite Pasta (2 cups)'
  RealColumn get carbsPerServing => real().named('carbs_per_serving')(); // 65.0
  TextColumn get imageAddress => text().nullable().named('image_address')();
  TextColumn get barcode => text().nullable()(); // Barcode if scanned via barcode scanner
  TextColumn get sourceFoodId => text().nullable().named('source_food_id')(); // FK to foods.id (if imported from nutrition plan)
  TextColumn get sourceUserFoodId => text().nullable().named('source_user_food_id')(); // FK to user_foods.id (if imported from user's custom foods)

  // Array-based meal types column (stored as JSON string in SQLite, array in Postgres)
  /// Meal types: array of meal_type_enum values (e.g., ['breakfast', 'lunch', 'dinner'])
  TextColumn get mealTypes => text().nullable().named('meal_types')();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false)).named('is_deleted')(); // Soft delete to preserve history
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'carb_loading_user_foods';

  @override
  List<String> get customConstraints => [
    'CHECK (carbs_per_serving > 0)',
  ];
}

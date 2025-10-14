import 'package:drift/drift.dart';

/// User Foods table - stores foods that users have added or scanned (matches Supabase user_foods)
@DataClassName('UserFood')
class UserFoodsTable extends Table {
  /// UUID primary key (matches Supabase user_foods.id)
  TextColumn get id => text().withLength(min: 36, max: 36)();

  /// Device ID of the user who created this food (matches Supabase user_foods.device_id)
  TextColumn get deviceId => text().named('device_id')();

  /// Client-generated food ID for offline sync (matches Supabase user_foods.client_food_id)
  TextColumn get clientFoodId => text().nullable().named('client_food_id')();

  /// Barcode if scanned (matches Supabase user_foods.barcode)
  TextColumn get barcode => text().nullable()();

  /// Food name (matches Supabase user_foods.name)
  TextColumn get name => text()();

  /// Display names (matches Supabase user_foods.display_name and display_name_plural)
  TextColumn get displayName => text().nullable().named('display_name')();
  TextColumn get displayNamePlural => text().nullable().named('display_name_plural')();

  /// Description (matches Supabase user_foods.description)
  TextColumn get description => text().nullable()();

  /// Image URL (matches Supabase user_foods.image_address)
  TextColumn get imageAddress => text().nullable().named('image_address')();

  /// Serving information (matches Supabase user_foods.serving_amount and serving_unit)
  RealColumn get servingAmount => real().nullable().named('serving_amount')();
  TextColumn get servingUnit => text().nullable().named('serving_unit')();

  /// Nutritional values per serving (matches Supabase user_foods)
  IntColumn get caloriesPerServing => integer().nullable().named('calories_per_serving')();
  RealColumn get carbsPerServing => real().nullable().named('carbs_per_serving')();
  RealColumn get proteinPerServing => real().nullable().named('protein_per_serving')();
  RealColumn get fatPerServing => real().nullable().named('fat_per_serving')();
  IntColumn get sodiumMg => integer().nullable().named('sodium_mg')();
  RealColumn get fluidMlPerServing => real().nullable().named('fluid_ml_per_serving')();

  /// Product type reference (matches Supabase user_foods.product_type_id)
  TextColumn get productTypeId => text().nullable().named('product_type_id')();

  /// Flags (matches Supabase user_foods)
  BoolColumn get isElectrolyte => boolean().withDefault(const Constant(false)).named('is_electrolyte')();
  BoolColumn get toExcludeFromSolver => boolean().withDefault(const Constant(false)).named('to_exclude_from_solver')();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false)).named('is_deleted')();

  /// Timestamps (matches Supabase user_foods)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();
  DateTimeColumn get clientUpdatedAt => dateTime().nullable().named('client_updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (device_id) REFERENCES users(device_id) ON DELETE CASCADE',
    'FOREIGN KEY (product_type_id) REFERENCES product_types(id)',
    'UNIQUE (device_id, client_food_id)',
  ];
}
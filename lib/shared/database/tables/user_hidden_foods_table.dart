import 'package:drift/drift.dart';

/// User Hidden Foods table - allows users to hide/exclude generic foods (matches Supabase user_hidden_foods)
/// When a user "deletes" a generic food, we actually just hide it from their view and exclude it from recommendations
/// Users can later unhide these foods if desired
@DataClassName('UserHiddenFood')
class UserHiddenFoodsTable extends Table {
  /// Device ID of the user (matches Supabase user_hidden_foods.device_id)
  TextColumn get deviceId => text().named('device_id')();

  /// ID of the food to hide (matches Supabase user_hidden_foods.food_id)
  TextColumn get foodId => text().withLength(min: 36, max: 36).named('food_id')();

  @override
  Set<Column> get primaryKey => {deviceId, foodId};

  @override
  List<String> get customConstraints => [
    // Temporarily removed all foreign keys to fix database creation:
    // 'FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE',
    // 'FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE',
  ];
}
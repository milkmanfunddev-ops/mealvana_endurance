import 'package:drift/drift.dart';

/// User Food Categories table - links user foods to timing categories (matches Supabase user_food_categories)
/// This table allows users to specify if their custom food is for before_run, during_run, or after_run
@DataClassName('UserFoodCategory')
class UserFoodCategoriesTable extends Table {
  /// User food ID (matches Supabase user_food_categories.user_food_id)
  TextColumn get userFoodId => text().withLength(min: 36, max: 36).named('user_food_id')();

  /// Category ID (matches Supabase user_food_categories.category_id)
  IntColumn get categoryId => integer().named('category_id')();

  @override
  Set<Column> get primaryKey => {userFoodId, categoryId};

  @override
  List<String> get customConstraints => [
    // Temporarily removed all foreign keys to fix database creation:
    // 'FOREIGN KEY (user_food_id) REFERENCES user_foods(id) ON DELETE CASCADE',
    // 'FOREIGN KEY (category_id) REFERENCES categories(id)',
  ];
}
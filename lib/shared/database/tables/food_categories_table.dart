import 'package:drift/drift.dart';
import 'foods_table.dart';
import 'categories_table.dart';

/// Many-to-many relationship between foods and categories
@DataClassName('FoodCategoryEntry')
class FoodCategoriesTable extends Table {
  TextColumn get foodId => text().references(FoodsTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get categoryId => integer().references(CategoriesTable, #id)();
  
  @override
  Set<Column> get primaryKey => {foodId, categoryId};
}
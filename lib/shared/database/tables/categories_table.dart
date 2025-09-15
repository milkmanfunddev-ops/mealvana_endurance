import 'package:drift/drift.dart';

/// Categories table - food timing categories (before_run, during_run, after_run)
@DataClassName('CategoryEntry')
class CategoriesTable extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  
  @override
  Set<Column> get primaryKey => {id};
}
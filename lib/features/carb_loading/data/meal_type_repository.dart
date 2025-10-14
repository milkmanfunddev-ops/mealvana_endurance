import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../domain/meal_type.dart' as domain;

part 'meal_type_repository.g.dart';

/// Repository for managing meal types
/// Handles queries for the meal_types reference table
class MealTypeRepository {
  const MealTypeRepository(this._database);

  final AppDatabase _database;

  /// Get all meal types
  Future<List<domain.MealType>> getAllMealTypes() async {
    final query = _database.select(_database.mealTypesTable)
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.id),
      ]);

    final mealTypes = await query.get();
    return mealTypes.map((mt) => domain.MealType.fromId(mt.id)).toList();
  }

  /// Get a specific meal type by ID
  Future<domain.MealType?> getMealTypeById(int id) async {
    final query = _database.select(_database.mealTypesTable)
      ..where((tbl) => tbl.id.equals(id));

    final mealType = await query.getSingleOrNull();
    return mealType != null ? domain.MealType.fromId(mealType.id) : null;
  }

  /// Get a meal type by name
  Future<domain.MealType?> getMealTypeByName(String name) async {
    final query = _database.select(_database.mealTypesTable)
      ..where((tbl) => tbl.name.equals(name));

    final mealType = await query.getSingleOrNull();
    return mealType != null ? domain.MealType.fromId(mealType.id) : null;
  }

  /// Watch all meal types (for real-time updates)
  Stream<List<domain.MealType>> watchAllMealTypes() {
    return (_database.select(_database.mealTypesTable)
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.id),
          ]))
        .watch()
        .map((mealTypes) => mealTypes.map((mt) => domain.MealType.fromId(mt.id)).toList());
  }

  /// Check if a meal type exists
  Future<bool> mealTypeExists(int id) async {
    final query = _database.select(_database.mealTypesTable)
      ..where((tbl) => tbl.id.equals(id));

    final mealType = await query.getSingleOrNull();
    return mealType != null;
  }
}

@riverpod
MealTypeRepository mealTypeRepository(Ref ref) {
  return MealTypeRepository(ref.watch(appDatabaseProvider));
}

import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/activities_table.dart';

part 'activity_dao.g.dart';

/// Data Access Object for activities and nutrition plans.
///
/// This DAO handles:
/// - Activity CRUD operations (nutrition plan related)
/// - Nutrition plan attachment and retrieval
/// - Activity queries by user
@DriftAccessor(tables: [ActivitiesTable])
class ActivityDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityDaoMixin {
  ActivityDao(super.db);

  /// Attach a nutrition plan JSON payload directly to an activity row.
  Future<void> setActivityNutritionPlan({
    required String activityId,
    required String planData,
  }) async {
    await (update(activitiesTable)..where((tbl) => tbl.id.equals(activityId)))
        .write(
      ActivitiesTableCompanion(
        nutritionPlanData: Value(planData),
        needsUpload: const Value(true),
        localUpdatedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Clear the nutrition plan fields for an activity.
  Future<void> clearActivityNutritionPlan(String activityId) async {
    await (update(activitiesTable)..where((tbl) => tbl.id.equals(activityId)))
        .write(
      const ActivitiesTableCompanion(
        nutritionPlanData: Value(null),
        needsUpload: Value(true),
      ),
    );
  }

  /// Fetch an activity row by primary key.
  Future<Activity?> getActivityByIdLocal(String activityId) async {
    final query = select(activitiesTable)
      ..where((tbl) => tbl.id.equals(activityId))
      ..limit(1);
    return await query.getSingleOrNull();
  }

  /// Get the most recently updated activity that has a nutrition plan.
  Future<Activity?> getLatestActivityWithNutritionPlan(String userId) async {
    final query = select(activitiesTable)
      ..where(
        (tbl) => tbl.userId.equals(userId) & tbl.nutritionPlanData.isNotNull(),
      )
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])
      ..limit(1);
    return await query.getSingleOrNull();
  }

}

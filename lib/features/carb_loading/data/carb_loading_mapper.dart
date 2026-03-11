import 'package:drift/drift.dart';
import '../../../shared/database/app_database.dart';

/// Mapper class for converting between Supabase JSON and Drift models
/// for carb loading plans and days.
///
/// This class handles the conversion between:
/// - Supabase JSON (snake_case) ↔ Drift companions
/// - Drift models ↔ Supabase JSON (snake_case)
class CarbLoadingMapper {
  CarbLoadingMapper._(); // Private constructor to prevent instantiation

  // ========================================================================
  // Supabase JSON → Drift Companions
  // ========================================================================

  /// Map Supabase JSON (snake_case) to Drift CarbLoadingPlansTableCompanion
  static CarbLoadingPlansTableCompanion mapPlanJsonToCompanion(
    Map<String, dynamic> json,
  ) {
    return CarbLoadingPlansTableCompanion.insert(
      id: Value(json['id'] as String),
      eventId: json['event_id'] != null
          ? Value(json['event_id'] as String)
          : const Value.absent(),
      userId: json['user_id'] as String,
      totalDays: json['total_days'] as int,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      dailyCarbTargetGrams: json['daily_carb_target_grams'] as int,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      algorithmVersion: json['algorithm_version'] != null
          ? Value(json['algorithm_version'] as String)
          : const Value.absent(),
      adherenceScore: json['adherence_score'] != null
          ? Value((json['adherence_score'] as num).toDouble())
          : const Value.absent(),
      completedAt: json['completed_at'] != null
          ? Value(DateTime.parse(json['completed_at'] as String))
          : const Value.absent(),
      needsUpload: const Value(false), // Coming from server, not dirty
      localUpdatedAt: Value(DateTime.now()),
    );
  }

  /// Map Supabase JSON (snake_case) to Drift CarbLoadingDaysTableCompanion
  static CarbLoadingDaysTableCompanion mapDayJsonToCompanion(
    Map<String, dynamic> json,
  ) {
    return CarbLoadingDaysTableCompanion.insert(
      id: Value(json['id'] as String),
      carbLoadingPlanId: json['carb_loading_plan_id'] as String,
      planDate: DateTime.parse(json['plan_date'] as String),
      dayNumber: json['day_number'] as int,
      carbTargetGrams: json['carb_target_grams'] as int,
      carbProtocolGPerKg: json['carb_protocol_g_per_kg'] != null
          ? Value((json['carb_protocol_g_per_kg'] as num).toDouble())
          : const Value.absent(),
      mealCount: Value(json['meal_count'] as int? ?? 6),
      breakfastPercent: Value(
        (json['breakfast_percent'] as num?)?.toDouble() ?? 16.67,
      ),
      morningSnackPercent: Value(
        (json['morning_snack_percent'] as num?)?.toDouble() ?? 16.67,
      ),
      lunchPercent: Value((json['lunch_percent'] as num?)?.toDouble() ?? 16.67),
      afternoonSnackPercent: Value(
        (json['afternoon_snack_percent'] as num?)?.toDouble() ?? 16.67,
      ),
      dinnerPercent: Value(
        (json['dinner_percent'] as num?)?.toDouble() ?? 16.67,
      ),
      eveningSnackPercent: Value(
        (json['evening_snack_percent'] as num?)?.toDouble() ?? 16.67,
      ),
      loggedCarbsGrams: json['logged_carbs_grams'] != null
          ? Value(json['logged_carbs_grams'] as int)
          : const Value.absent(),
      loggedCalories: json['logged_calories'] != null
          ? Value(json['logged_calories'] as int)
          : const Value.absent(),
      completed: Value(json['completed'] as bool? ?? false),
      needsUpload: const Value(false), // Coming from server, not dirty
      localUpdatedAt: Value(DateTime.now()),
    );
  }

  // ========================================================================
  // Drift Models → Supabase JSON
  // ========================================================================

  /// Map Drift CarbLoadingPlan to Supabase JSON (snake_case)
  static Map<String, dynamic> mapPlanToSupabaseJson(CarbLoadingPlan plan) {
    return {
      'id': plan.id,
      'event_id': plan.eventId,
      'user_id': plan.userId,
      'total_days': plan.totalDays,
      'start_date': plan.startDate.toIso8601String().split('T')[0],
      'end_date': plan.endDate.toIso8601String().split('T')[0],
      'daily_carb_target_grams': plan.dailyCarbTargetGrams,
      'generated_at': plan.generatedAt.toIso8601String(),
      'algorithm_version': plan.algorithmVersion,
      'adherence_score': plan.adherenceScore,
      'completed_at': plan.completedAt?.toIso8601String(),
      'local_updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map Drift CarbLoadingDay to Supabase JSON (snake_case)
  static Map<String, dynamic> mapDayToSupabaseJson(CarbLoadingDay day) {
    return {
      'id': day.id,
      'carb_loading_plan_id': day.carbLoadingPlanId,
      'plan_date': day.planDate.toIso8601String().split('T')[0],
      'day_number': day.dayNumber,
      'carb_target_grams': day.carbTargetGrams,
      'carb_protocol_g_per_kg': day.carbProtocolGPerKg,
      'meal_count': day.mealCount,
      'breakfast_percent': day.breakfastPercent,
      'morning_snack_percent': day.morningSnackPercent,
      'lunch_percent': day.lunchPercent,
      'afternoon_snack_percent': day.afternoonSnackPercent,
      'dinner_percent': day.dinnerPercent,
      'evening_snack_percent': day.eveningSnackPercent,
      'logged_carbs_grams': day.loggedCarbsGrams,
      'logged_calories': day.loggedCalories,
      'completed': day.completed,
      'local_updated_at': DateTime.now().toIso8601String(),
    };
  }
}

import '../../content/application/content_service.dart';
import '../../content/domain/content_keys.dart';
import '../domain/cooking_session.dart';
import '../domain/meal_plan.dart';

/// Plain-text plan summary for the OS share sheet (plan Phase 4.2): the
/// title, the week, each meal as `name × servings`, then the cooking
/// sessions the plan uses. Pure formatting — no model call, no arithmetic
/// beyond counting.
class PlanShareService {
  const PlanShareService._();

  /// Distinct sessions in the plan, in session order (`cook-sun`,
  /// `topup-wed`, `fresh-fri`).
  static List<CookingSession> sessionsOf(MealPlan plan) => [
    for (final session in CookingSession.values)
      if (plan.meals.any((m) => m.session == session)) session,
  ];

  /// The share body; empty when the plan has no meals.
  static String text(
    ContentService content,
    MealPlan plan, {
    required String weekLabel,
    required String Function(CookingSession session) sessionLabel,
  }) {
    if (plan.meals.isEmpty) return '';
    final buffer = StringBuffer()
      ..writeln(content.getValue(ContentKeys.mpPlanShareTitle))
      ..writeln(weekLabel)
      ..writeln();
    for (final meal in plan.meals) {
      buffer.writeln(
        ContentKeys.format(content.getValue(ContentKeys.mpPlanShareMealLine), {
          'name': meal.name,
          'servings': meal.servings,
        }),
      );
    }
    final sessions = sessionsOf(plan);
    if (sessions.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(
          ContentKeys.format(
            content.getValue(ContentKeys.mpPlanShareSessionsLine),
            {'sessions': sessions.map(sessionLabel).join(' · ')},
          ),
        );
    }
    return buffer.toString().trimRight();
  }
}

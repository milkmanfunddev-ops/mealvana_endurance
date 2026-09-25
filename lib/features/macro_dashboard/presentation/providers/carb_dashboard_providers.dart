import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/providers/user_id_provider.dart';
import '../../../carb_loading/data/carb_loading_repository.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../application/carb_dashboard_assembler.dart';
import '../../domain/carb_dashboard_models.dart';

part 'carb_dashboard_providers.g.dart';

/// The loading-day surface data for one date, or null when the date falls in
/// no carb-loading plan — CD-1's negative: a regular day has NO carb surface
/// anywhere in the DOM.
///
/// Composition, not refetching (same shape as [macroDashboardDay]): a food
/// log write invalidates the meal-log providers, this recomputes, and every
/// carb surface — face, slot cards, slot page, breakdown — rebuilds in the
/// same pump (CD-2, the surface's core contract).
@riverpod
Future<CarbDashboardData?> carbDashboardForDate(Ref ref, String dateStr) async {
  final date = DateTime.parse(dateStr);
  final userId = await ref.watch(userIdProvider.future);
  final repository = ref.watch(carbLoadingRepositoryProvider);

  final days = await repository.getCarbLoadingDaysForDateRange(
    userId: userId,
    startDate: date,
    endDate: date,
  );
  if (days.isEmpty) return null;
  final day = days.first;

  final plan = await repository.getCarbLoadingPlanById(day.carbLoadingPlanId);
  final planDays = await repository.getCarbLoadingDaysForPlan(
    day.carbLoadingPlanId,
  );
  final meals = await ref.watch(mealLogsForDateProvider(dateStr).future);

  const assembler = CarbDashboardAssembler();
  return assembler.assemble(
    day: day,
    totalDays: plan?.totalDays ?? planDays.length,
    planDays: planDays,
    meals: meals,
    selectedDate: date,
    now: DateTime.now(),
    eventId: plan?.eventId,
  );
}

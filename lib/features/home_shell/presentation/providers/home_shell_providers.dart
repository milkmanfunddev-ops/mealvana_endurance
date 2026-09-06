/// Home-shell providers — `home-shell@v1` (calendar-sheet channel data).
///
/// Read-only derivations; the sheet's cell data reassembles whenever the
/// activities controller or the meal-log table changes.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/widgets/kyle_design/navigation/kyle_calendar_sheet.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../auth/data/user_repository.dart';
import '../../../meal_logging/data/meal_log_repository.dart';
import '../../application/home_shell_calendar_assembler.dart';

part 'home_shell_providers.g.dart';

/// Distinct `log_date`s carrying ≥ 1 non-deleted meal log in the inclusive
/// `'yyyy-MM-dd'` range — the tint channel's rollup (calendar-sheet.md Q2,
/// binary v1). Empty when there is no authenticated user.
@riverpod
Stream<Set<String>> homeShellLoggedDates(
  Ref ref,
  String startDate,
  String endDate,
) async* {
  final userRepo = await ref.read(userRepositoryProvider.future);
  final user = await userRepo.getCurrentUser();
  final userId = user?.id;
  if (userId == null) {
    yield const <String>{};
    return;
  }
  final repo = ref.read(mealLogRepositoryProvider);
  yield* repo.watchLogDatesInRange(userId, startDate, endDate);
}

/// The calendar sheet's cell data for the month starting at [month]
/// (midnight-normalized first-of-month).
@riverpod
Future<Map<int, KyleCalendarDayData>> homeShellCalendarMonth(
  Ref ref,
  DateTime month,
) async {
  final activities = await ref.watch(activitiesControllerProvider.future);
  final lastDay = DateTime(month.year, month.month + 1, 0);
  final logged = await ref.watch(
    homeShellLoggedDatesProvider(
      logDateKey(month),
      logDateKey(lastDay),
    ).future,
  );
  return assembleCalendarMonth(
    month: month,
    now: DateTime.now(),
    activities: activities,
    loggedDates: logged,
  );
}

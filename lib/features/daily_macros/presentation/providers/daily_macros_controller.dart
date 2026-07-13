import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/data/user_repository.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../application/daily_macro_service.dart';
import '../../data/daily_macro_targets_repository.dart';
import '../../domain/daily_macro_targets.dart';
import '../../domain/macro_cache_invalidation.dart';

part 'daily_macros_controller.g.dart';

class DailyMacrosState {
  final DateTime selectedDate;
  final DailyMacroTargets? dailyMacros;
  final List<DailyMacroTargets?> weeklyMacros;

  /// Reason the daily calculation failed, if any. Populated when the edge
  /// function rejects the input or the user profile is missing required
  /// fields. UI surfaces this instead of a generic empty state.
  final String? calculationError;

  const DailyMacrosState({
    required this.selectedDate,
    this.dailyMacros,
    this.weeklyMacros = const [],
    this.calculationError,
  });
}

@riverpod
class DailyMacrosController extends _$DailyMacrosController {
  /// Last activity list we costed macros against, used to detect *real*
  /// activity changes vs. rebuilds that carry the same activities (a date
  /// switch, an autoDispose recreation, an `invalidateSelf()` refresh that
  /// re-fetches identical rows).
  ///
  /// Compared with [listEquals], NOT `identical`: every re-fetch hands us a new
  /// `List` instance, so an identity check reports "changed" whenever the list
  /// object is merely rebuilt — wiping the user's entire macro cache and firing
  /// two edge-function round trips for no reason. `Activity` has value equality,
  /// so an element-wise compare is what actually answers "did the activities
  /// change?". Mirrors the `listEquals` guard in
  /// `ActivitiesController._refreshInPlace`.
  List<Activity>? _lastActivities;

  @override
  FutureOr<DailyMacrosState> build() async {
    final selectedDate = ref.watch(calendarSelectedDateProvider);

    // Watch activities — when activities change, this controller rebuilds
    final activitiesAsync = ref.watch(activitiesControllerProvider);

    final userRepository = await ref.read(userRepositoryProvider.future);
    final profile = await userRepository.getCurrentUser();

    if (profile == null) {
      return DailyMacrosState(
        selectedDate: selectedDate,
        calculationError:
            'Your profile is not loaded yet. Sign in or finish onboarding to see your nutrition targets.',
      );
    }

    // The awaits above are async gaps; if this auto-dispose provider was
    // disposed meanwhile, reading `ref` throws UnmountedRefException
    // (Sentry MEALVANA-ENDURANCE-A9). Bail out with a harmless state instead.
    if (!ref.mounted) {
      return DailyMacrosState(selectedDate: selectedDate);
    }

    final service = ref.read(dailyMacroServiceProvider);
    final repository = ref.read(dailyMacroTargetsRepositoryProvider);

    // Detect if activities actually changed (not just a rebuild carrying the
    // same activities), and invalidate ONLY the cached days whose inputs moved.
    // `macroDatesToInvalidate` derives that window from the activity diff; see
    // domain/macro_cache_invalidation.dart for why it's the activity's Mon–Sun
    // week plus the day either side, and nothing more.
    final currentActivities = activitiesAsync.value;
    if (_lastActivities != null &&
        currentActivities != null &&
        !listEquals(currentActivities, _lastActivities)) {
      final stale = macroDatesToInvalidate(_lastActivities!, currentActivities);
      if (stale.isNotEmpty) {
        await repository.invalidateDates(profile.id, stale);
      }
    }
    // Don't clobber the baseline with null while activities are loading/errored,
    // or the next real change would compare against nothing and skip the
    // invalidation it owes.
    if (currentActivities != null) {
      _lastActivities = currentActivities;
    }

    // Calculate today's macros first (uses cache if available, else calls edge fn).
    // Catch the precise failure reason so the UI can show it.
    DailyMacroTargets? macros;
    String? calculationError;
    try {
      macros = await service.calculateForDate(
        profile.id,
        selectedDate,
        profile,
      );
      if (macros == null) {
        calculationError =
            'Could not calculate macros for this date. Pull to refresh or try again.';
      }
    } on DailyMacroCalculationException catch (e) {
      calculationError = e.reason;
    } catch (e) {
      calculationError = 'Unexpected error: $e';
    }

    // Read week cache (local lookups only — no network calls)
    final weekMacros = await service.getWeekOverview(
      profile.id,
      selectedDate,
      profile,
    );

    // Calculate uncached week days in parallel in the background
    _calculateWeekInBackground(service, profile.id, selectedDate, profile, weekMacros);

    return DailyMacrosState(
      selectedDate: selectedDate,
      dailyMacros: macros,
      weeklyMacros: weekMacros,
      calculationError: calculationError,
    );
  }

  /// Calculate missing week days via a single edge function call in the background.
  /// On completion, invalidates self so build() re-reads all days from cache.
  void _calculateWeekInBackground(
    DailyMacroService service,
    String userId,
    DateTime selectedDate,
    UserProfile profile,
    List<DailyMacroTargets?> weekMacros,
  ) {
    // Check if there are any uncached days (besides selected date)
    final hasUncached = weekMacros.asMap().entries.any((e) {
      if (e.value != null) return false;
      final startOfWeek = selectedDate.subtract(
        Duration(days: selectedDate.weekday % 7),
      );
      final day = startOfWeek.add(Duration(days: e.key));
      return day.year != selectedDate.year ||
          day.month != selectedDate.month ||
          day.day != selectedDate.day;
    });

    if (!hasUncached) return;

    final link = ref.keepAlive();

    // Snapshot how many days are already cached so we can tell whether the
    // background call actually made progress.
    final priorCachedCount = weekMacros.where((e) => e != null).length;

    Future(() async {
      // Single edge function call for all uncached days
      final result = await service.calculateWeek(userId, selectedDate, profile);

      // Only refresh when the call actually cached new days. Invalidating
      // unconditionally caused an infinite rebuild loop on web: when the edge
      // call fails it caches nothing, so build() -> calculateWeek (fails) ->
      // invalidateSelf() -> build() (still uncached) -> ... forever. Gating on
      // real progress also stops the loop once every day that *can* resolve has.
      final newCachedCount = result.where((e) => e != null).length;
      if (newCachedCount > priorCachedCount) {
        try {
          ref.invalidateSelf();
        } catch (e) {
          if (kDebugMode) {
            print('DailyMacrosController: background invalidation skipped: $e');
          }
        }
      } else if (kDebugMode) {
        print('DailyMacrosController: week calc made no progress; not re-invalidating.');
      }
      link.close();
    });
  }

  /// Force recalculation by invalidating cache
  Future<void> refresh() async {
    final currentState = state.value;
    if (currentState == null) return;

    final userRepository = await ref.read(userRepositoryProvider.future);
    final profile = await userRepository.getCurrentUser();
    if (profile == null) return;

    final repository = ref.read(
      dailyMacroTargetsRepositoryProvider,
    );

    // Invalidate cache for current date
    await repository.invalidateForDate(
      profile.id,
      currentState.selectedDate,
    );

    // Trigger rebuild
    ref.invalidateSelf();
  }
}

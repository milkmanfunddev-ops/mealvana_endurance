import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/data/user_repository.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../../shared/services/performance_telemetry.dart';
import '../../application/daily_macro_service.dart';
import '../../data/daily_macro_targets_repository.dart';
import '../../domain/daily_macro_targets.dart';
import '../../domain/macro_cache_invalidation.dart';

part 'daily_macros_controller.g.dart';

class DailyMacrosState {
  final DateTime selectedDate;
  final DailyMacroTargets? dailyMacros;
  final List<DailyMacroTargets?> weeklyMacros;
  final bool isCalculating;

  /// Reason the daily calculation failed, if any. Populated when the edge
  /// function rejects the input or the user profile is missing required
  /// fields. UI surfaces this instead of a generic empty state.
  final String? calculationError;

  const DailyMacrosState({
    required this.selectedDate,
    this.dailyMacros,
    this.weeklyMacros = const [],
    this.isCalculating = false,
    this.calculationError,
  });

  DailyMacrosState copyWith({
    DateTime? selectedDate,
    DailyMacroTargets? dailyMacros,
    List<DailyMacroTargets?>? weeklyMacros,
    bool? isCalculating,
    String? calculationError,
  }) {
    return DailyMacrosState(
      selectedDate: selectedDate ?? this.selectedDate,
      dailyMacros: dailyMacros ?? this.dailyMacros,
      weeklyMacros: weeklyMacros ?? this.weeklyMacros,
      isCalculating: isCalculating ?? this.isCalculating,
      calculationError: calculationError ?? this.calculationError,
    );
  }
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
  /// two edge-function round trips for no reason. Mirrors the `listEquals` guard
  /// in `ActivitiesController._refreshInPlace`.
  ///
  /// This is only a cheap pre-filter, and a leaky one: `Activity.operator==`
  /// includes sync bookkeeping (`updatedAt`, `lastSyncedAt`, `needsUpload`), so
  /// background sync makes it report "changed" for activities nobody edited.
  /// What actually decides which cached days die is `macroDatesToInvalidate`,
  /// which re-compares on macro inputs alone — so a false positive here costs a
  /// diff, not a wiped cache. Don't "optimize" by invalidating straight off this
  /// check.
  List<Activity>? _lastActivities;
  final Set<String> _backgroundWeeks = {};
  int _buildCount = 0;

  @override
  FutureOr<DailyMacrosState> build() async {
    final stopwatch = Stopwatch()..start();
    _buildCount++;
    DailyMacrosState finish(
      DailyMacrosState result, {
      String cacheStatus = 'unknown',
    }) {
      stopwatch.stop();
      PerformanceTelemetry.recordDuration(
        'daily_macros.controller_build',
        stopwatch.elapsed,
        data: {'build_count': _buildCount, 'cache_status': cacheStatus},
        threshold: const Duration(milliseconds: 500),
      );
      return result;
    }

    final selectedDate = ref.watch(calendarSelectedDateProvider);

    // Watch activities — when activities change, this controller rebuilds
    final activitiesAsync = ref.watch(activitiesControllerProvider);

    final userRepository = await ref.read(userRepositoryProvider.future);
    final profile = await userRepository.getCurrentUser();

    if (profile == null) {
      return finish(
        DailyMacrosState(
          selectedDate: selectedDate,
          calculationError:
              'Your profile is not loaded yet. Sign in or finish onboarding to see your nutrition targets.',
        ),
      );
    }

    // The awaits above are async gaps; if this auto-dispose provider was
    // disposed meanwhile, reading `ref` throws UnmountedRefException
    // (Sentry MEALVANA-ENDURANCE-A9). Bail out with a harmless state instead.
    if (!ref.mounted) {
      return finish(DailyMacrosState(selectedDate: selectedDate));
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
        service.markMacroInputsChanged(profile.id, stale);
        await repository.invalidateDates(profile.id, stale);
        PerformanceTelemetry.record(
          'Macro cache invalidated after activity change',
          category: 'daily_macros',
          data: {'invalidated_days': stale.length},
        );
      }
    }
    // Don't clobber the baseline with null while activities are loading/errored,
    // or the next real change would compare against nothing and skip the
    // invalidation it owes.
    if (currentActivities != null) {
      _lastActivities = currentActivities;
    }

    // Read the local cache only. A miss must not put an edge-function request
    // on the dashboard's first-interaction path; missing days are filled below
    // in the background while the existing spinner/empty state remains usable.
    final weekMacros = await service.getWeekOverview(
      profile.id,
      selectedDate,
      profile,
    );
    final selectedIndex = selectedDate.weekday % 7;
    final macros = selectedIndex >= 0 && selectedIndex < weekMacros.length
        ? weekMacros[selectedIndex]
        : null;
    final calculationError = service.profileValidationError(profile);

    if (calculationError == null) {
      _calculateWeekInBackground(
        service,
        profile.id,
        selectedDate,
        profile,
        weekMacros,
      );
    }

    return finish(
      DailyMacrosState(
        selectedDate: selectedDate,
        dailyMacros: macros,
        weeklyMacros: weekMacros,
        isCalculating:
            calculationError == null && weekMacros.any((day) => day == null),
        calculationError: calculationError,
      ),
      cacheStatus: macros == null ? 'miss' : 'hit',
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
    final hasUncached = weekMacros.any((macros) => macros == null);

    if (!hasUncached) return;

    final selectedDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final startOfWeek = selectedDay.subtract(
      Duration(days: selectedDay.weekday % 7),
    );
    final weekKey = '$userId:${startOfWeek.millisecondsSinceEpoch}';
    if (!_backgroundWeeks.add(weekKey)) {
      PerformanceTelemetry.record(
        'Duplicate controller week request suppressed',
        category: 'daily_macros',
      );
      return;
    }

    final link = ref.keepAlive();

    // Snapshot how many days are already cached so we can tell whether the
    // background call actually made progress.
    final priorCachedCount = weekMacros.where((e) => e != null).length;

    unawaited(
      Future(() async {
        try {
          // Single edge function call for all uncached days. The service also
          // collapses requests across controller rebuilds/instances.
          final result = await service.calculateWeek(
            userId,
            selectedDate,
            profile,
          );

          // Only refresh when the call actually cached new days. Invalidating
          // unconditionally would retry forever when the edge call fails.
          final newCachedCount = result.where((e) => e != null).length;
          if (newCachedCount > priorCachedCount && ref.mounted) {
            ref.invalidateSelf();
          } else if (kDebugMode) {
            print(
              'DailyMacrosController: week calc made no progress; not re-invalidating.',
            );
          }
        } on DailyMacroCalculationException catch (e) {
          final current = ref.mounted ? state.value : null;
          if (current != null) {
            state = AsyncData(
              current.copyWith(
                calculationError: e.reason,
                isCalculating: false,
              ),
            );
          }
        } catch (e) {
          final current = ref.mounted ? state.value : null;
          if (current != null) {
            state = AsyncData(
              current.copyWith(
                calculationError: 'Unexpected error: $e',
                isCalculating: false,
              ),
            );
          }
        } finally {
          _backgroundWeeks.remove(weekKey);
          link.close();
        }
      }),
    );
  }

  /// Force recalculation by invalidating cache
  Future<void> refresh() async {
    final currentState = state.value;
    if (currentState == null) return;

    final userRepository = await ref.read(userRepositoryProvider.future);
    final profile = await userRepository.getCurrentUser();
    if (profile == null) return;

    final repository = ref.read(dailyMacroTargetsRepositoryProvider);

    // Invalidate cache for current date
    await repository.invalidateForDate(profile.id, currentState.selectedDate);

    // Trigger rebuild
    ref.invalidateSelf();
  }
}

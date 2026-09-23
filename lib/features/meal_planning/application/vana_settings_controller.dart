import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/connectivity_checker.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import '../data/user_memory_repository.dart';
import '../data/vana_action_client.dart';
import '../data/vana_exceptions.dart';
import '../domain/ui_action.dart';
import '../domain/user_memory.dart';
import '../domain/vana_part.dart';
import '../domain/vana_setting.dart';
import '../domain/week_start.dart';
import 'meal_plan_controller.dart';
import 'plan_reminder_service.dart';
import '../../subscription/application/write_guard.dart';

part 'vana_settings_controller.g.dart';

/// `/settings/vana`: the switches and "What Vana knows".
class VanaSettingsState {
  const VanaSettingsState({
    this.batchCooking = true,
    this.showMacros = true,
    this.remindersEnabled = false,
    this.memories = const [],
    this.period = const PlanPeriod(),
  });

  /// Server defaults: batch cooking on, macros shown (flipped on with the
  /// Vana chatbot update, plan §4.2 — the athlete can still hide them).
  final bool batchCooking;
  final bool showMacros;

  /// Device-local (shared_preferences via [PlanReminderService]), default
  /// OFF: the check-in + debrief local notifications (plan Phase 3.5).
  final bool remindersEnabled;
  final List<UserMemory> memories;

  /// The plan period (mp-269): the `week_start` and `period_days` settings,
  /// Sunday and seven days until the athlete changes them.
  final PlanPeriod period;

  VanaSettingsState copyWith({
    bool? batchCooking,
    bool? showMacros,
    bool? remindersEnabled,
    List<UserMemory>? memories,
    PlanPeriod? period,
  }) => VanaSettingsState(
    batchCooking: batchCooking ?? this.batchCooking,
    showMacros: showMacros ?? this.showMacros,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    memories: memories ?? this.memories,
    period: period ?? this.period,
  );
}

/// Settings are `user_memories` rows: local-first through
/// [UserMemoryRepository], plus — when online — the `set_setting` action so
/// the server flips `meal_plans.batch_cooking` in the same beat (its `batch`
/// part is folded into [MealPlanController]). Memory deletes are
/// local-first tombstones.
@riverpod
class VanaSettingsController extends _$VanaSettingsController {
  UserMemoryRepository get _repo => ref.read(userMemoryRepositoryProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  static const _context = 'VANA_SETTINGS_CONTROLLER';

  String? _userId;
  StreamSubscription<Map<VanaSetting, Object?>>? _settingsSub;
  StreamSubscription<List<UserMemory>>? _memoriesSub;

  @override
  FutureOr<VanaSettingsState> build() async {
    final userId = await ref.watch(userIdProvider.future);
    // The await above can outlive this auto-dispose controller (the settings
    // screen closes); every ref use below would throw UnmountedRefException.
    if (!ref.mounted) return const VanaSettingsState();
    _userId = userId;
    ref.onDispose(() {
      _settingsSub?.cancel();
      _memoriesSub?.cancel();
    });
    unawaited(_ensureSynced(userId));

    final repo = _repo;
    final settings = await repo.watchSettings(userId).first;
    final memories = await repo.watchMemories(userId).first;
    if (!ref.mounted) return const VanaSettingsState();
    final initial = _fold(
      VanaSettingsState(
        remindersEnabled: ref
            .read(planReminderServiceProvider)
            .remindersEnabled,
      ),
      settings,
      memories,
    );

    _settingsSub = repo.watchSettings(userId).listen((s) {
      final current = state.value;
      if (current == null || !ref.mounted) return;
      state = AsyncData(_fold(current, s, current.memories));
    });
    _memoriesSub = repo.watchMemories(userId).listen((m) {
      final current = state.value;
      if (current == null || !ref.mounted) return;
      state = AsyncData(current.copyWith(memories: m));
    });
    return initial;
  }

  static VanaSettingsState _fold(
    VanaSettingsState base,
    Map<VanaSetting, Object?> settings,
    List<UserMemory> memories,
  ) => base.copyWith(
    batchCooking: _bool(settings[VanaSetting.batchCooking]) ?? true,
    showMacros: _bool(settings[VanaSetting.showMacros]) ?? true,
    period: PlanPeriod.fromSettings(
      weekStart: settings[VanaSetting.weekStart],
      periodDays: settings[VanaSetting.periodDays],
    ),
    memories: memories,
  );

  static bool? _bool(Object? value) => value is bool ? value : null;

  Future<void> _ensureSynced(String userId) async {
    try {
      await ref
          .read(syncCoordinatorProvider.notifier)
          .ensureSynced('user_memories', userId, repository: _repo);
    } catch (e) {
      _logger.warning(
        'user_memories ensureSynced failed (non-fatal)',
        context: _context,
        error: e,
      );
    }
  }

  Future<void> setBatchCooking(bool value) async {
    if (!await ref.canWrite()) return;
    await _setSetting(VanaSetting.batchCooking, value);
  }

  Future<void> setShowMacros(bool value) async {
    if (!await ref.canWrite()) return;
    await _setSetting(VanaSetting.showMacros, value);
  }

  /// The day a plan week starts (`DateTime.monday` … `DateTime.sunday`).
  /// The Plan tab's week follows through the settings row in Drift.
  Future<void> setWeekStart(int weekday) async {
    if (!await ref.canWrite()) return;
    await _setSetting(VanaSetting.weekStart, PlanPeriod.weekdayToWire(weekday));
  }

  /// How many days one plan covers, within [PlanPeriod.minDays] …
  /// [PlanPeriod.maxDays]; anything outside is ignored.
  Future<void> setPeriodDays(int days) async {
    if (!await ref.canWrite()) return;
    if (!PlanPeriod.isValidDays(days)) return;
    await _setSetting(VanaSetting.periodDays, days);
  }

  /// The reminders toggle — a device preference, never a `set_setting`.
  /// Turning it on with a confirmed plan in hand schedules that plan's two
  /// notifications; turning it off cancels them.
  Future<void> setRemindersEnabled(bool value) async {
    if (!await ref.canWrite()) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(remindersEnabled: value));
    state = await AsyncValue.guard(() async {
      await ref
          .read(planReminderServiceProvider)
          .setRemindersEnabled(
            value,
            plan: ref.read(mealPlanControllerProvider).value,
          );
      return state.value ?? current;
    });
  }

  Future<void> _setSetting(VanaSetting setting, Object value) async {
    final userId = _userId;
    final current = state.value;
    if (userId == null || current == null) return;

    final period = current.period;
    state = AsyncData(switch (setting) {
      VanaSetting.batchCooking => current.copyWith(batchCooking: value == true),
      VanaSetting.showMacros => current.copyWith(showMacros: value == true),
      VanaSetting.weekStart => current.copyWith(
        period: PlanPeriod(
          startWeekday:
              PlanPeriod.weekdayFromWire(value) ?? period.startWeekday,
          days: period.days,
        ),
      ),
      VanaSetting.periodDays => current.copyWith(
        period: PlanPeriod(
          startWeekday: period.startWeekday,
          days: value is int ? value : period.days,
        ),
      ),
      // The coverage scope is a chat answer (mp-464), not a sheet setting:
      // nothing here shows it.
      VanaSetting.coverageScope => current,
    });
    state = await AsyncValue.guard(() async {
      await _repo.setSetting(userId, setting, value);
      unawaited(_pushSetting(userId, setting, value));
      return state.value ?? current;
    });
  }

  /// Online: `set_setting` (server also updates the active plan's
  /// `batch_cooking`); offline: the dirty row is replayed by the next sync.
  Future<void> _pushSetting(
    String userId,
    VanaSetting setting,
    Object value,
  ) async {
    if (!await ref.read(connectivityCheckerProvider).isOnline()) return;
    try {
      final result = await ref
          .read(vanaActionClientProvider)
          .run(SetSettingAction(key: setting, value: value));
      for (final part in result.parts) {
        if (part is VanaMemorySavedPart) {
          await _repo.applyServerMemory(part.memory, userId: userId);
        }
      }
      final plan = result.plan;
      if (plan != null) {
        await ref
            .read(mealPlanControllerProvider.notifier)
            .applyServerPlan(plan);
      }
    } on VanaException catch (e) {
      _logger.warning(
        'set_setting action failed; local row stays dirty',
        context: _context,
        error: e,
      );
      final upload = await _repo.uploadDirtyRecords(userId);
      if (!upload.success) {
        _logger.warning(
          'user_memories upload failed',
          context: _context,
          data: {'error': upload.error},
        );
      }
    }
  }

  /// Forget a memory (local-first tombstone; replayed as `is_deleted`).
  Future<void> deleteMemory(String id) async {
    if (!await ref.canWrite()) return;
    final userId = _userId;
    final current = state.value;
    if (userId == null || current == null) return;
    state = AsyncData(
      current.copyWith(
        memories: current.memories.where((m) => m.id != id).toList(),
      ),
    );
    state = await AsyncValue.guard(() async {
      await _repo.deleteMemory(id);
      unawaited(() async {
        final upload = await _repo.uploadDirtyRecords(userId);
        if (!upload.success) {
          _logger.warning(
            'user_memories upload after delete failed',
            context: _context,
            data: {'error': upload.error},
          );
        }
      }());
      return state.value ?? current;
    });
  }
}

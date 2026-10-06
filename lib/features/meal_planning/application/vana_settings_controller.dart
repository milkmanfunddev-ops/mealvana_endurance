import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/connectivity_checker.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import '../data/user_memory_repository.dart';
import '../data/vana_action_client.dart';
import '../data/vana_exceptions.dart';
import '../domain/ui_action.dart';
import '../domain/user_memory.dart';
import '../domain/vana_part.dart';
import '../domain/vana_setting.dart';
import 'meal_plan_controller.dart';
import 'plan_reminder_service.dart';
import '../../../shared/services/report/report.dart';

part 'vana_settings_controller.g.dart';

/// `/settings/vana`: the switches and "What Vana knows".
class VanaSettingsState {
  const VanaSettingsState({
    this.batchCooking = true,
    this.showMacros = true,
    this.remindersEnabled = false,
    this.memories = const [],
  });

  /// Server defaults: batch cooking on, macros shown (flipped on with the
  /// Vana chatbot update, plan §4.2 — the athlete can still hide them).
  final bool batchCooking;
  final bool showMacros;

  /// Device-local (shared_preferences via [PlanReminderService]), default
  /// OFF: the check-in + debrief local notifications (plan Phase 3.5).
  final bool remindersEnabled;
  final List<UserMemory> memories;

  VanaSettingsState copyWith({
    bool? batchCooking,
    bool? showMacros,
    bool? remindersEnabled,
    List<UserMemory>? memories,
  }) => VanaSettingsState(
    batchCooking: batchCooking ?? this.batchCooking,
    showMacros: showMacros ?? this.showMacros,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    memories: memories ?? this.memories,
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
  Report get _report => ref.report;

  static const _context = 'VANA_SETTINGS_CONTROLLER';

  String? _userId;
  StreamSubscription<Map<VanaSetting, bool?>>? _settingsSub;
  StreamSubscription<List<UserMemory>>? _memoriesSub;

  @override
  FutureOr<VanaSettingsState> build() async {
    final repo = _repo;
    final reminderService = ref.read(planReminderServiceProvider);
    ref.onDispose(() {
      _settingsSub?.cancel();
      _memoriesSub?.cancel();
    });
    final userId = await ref.watch(userIdProvider.future);
    _userId = userId;
    unawaited(_ensureSynced(userId));

    final settings = await repo.watchSettings(userId).first;
    final memories = await repo.watchMemories(userId).first;
    final initial = _fold(
      VanaSettingsState(remindersEnabled: reminderService.remindersEnabled),
      settings,
      memories,
    );
    // Disposed during the awaits: onDispose already ran, so subscribing now
    // would leak the streams. The value is discarded either way.
    if (!ref.mounted) return initial;

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
    Map<VanaSetting, bool?> settings,
    List<UserMemory> memories,
  ) => base.copyWith(
    batchCooking: settings[VanaSetting.batchCooking] ?? true,
    showMacros: settings[VanaSetting.showMacros] ?? true,
    memories: memories,
  );

  Future<void> _ensureSynced(String userId) async {
    if (!ref.mounted) return;
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    final repo = _repo;
    final report = _report;
    try {
      await syncCoordinator.ensureSynced(
        'user_memories',
        userId,
        repository: repo,
      );
    } catch (e) {
      report.degraded(
        e,
        area: 'meal_planning',
        message: 'user_memories ensureSynced failed (non-fatal)',
      );
    }
  }

  Future<void> setBatchCooking(bool value) =>
      _setSetting(VanaSetting.batchCooking, value);

  Future<void> setShowMacros(bool value) =>
      _setSetting(VanaSetting.showMacros, value);

  /// The reminders toggle — a device preference, never a `set_setting`.
  /// Turning it on with a confirmed plan in hand schedules that plan's two
  /// notifications; turning it off cancels them.
  Future<void> setRemindersEnabled(bool value) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(remindersEnabled: value));
    final reminderService = ref.read(planReminderServiceProvider);
    final plan = ref.read(mealPlanControllerProvider).value;
    final result = await AsyncValue.guard(() async {
      await reminderService.setRemindersEnabled(value, plan: plan);
      return (ref.mounted ? state.value : null) ?? current;
    });
    if (ref.mounted) state = result;
  }

  Future<void> _setSetting(VanaSetting setting, bool value) async {
    final userId = _userId;
    final current = state.value;
    if (userId == null || current == null) return;

    state = AsyncData(switch (setting) {
      VanaSetting.batchCooking => current.copyWith(batchCooking: value),
      VanaSetting.showMacros => current.copyWith(showMacros: value),
    });
    final repo = _repo;
    final result = await AsyncValue.guard(() async {
      await repo.setSetting(userId, setting, value);
      unawaited(_pushSetting(userId, setting, value));
      return (ref.mounted ? state.value : null) ?? current;
    });
    if (ref.mounted) state = result;
  }

  /// Online: `set_setting` (server also updates the active plan's
  /// `batch_cooking`); offline: the dirty row is replayed by the next sync.
  Future<void> _pushSetting(
    String userId,
    VanaSetting setting,
    bool value,
  ) async {
    // Disposed after the local write: the dirty row is replayed by the next
    // sync, same as the offline path.
    if (!ref.mounted) return;
    final connectivity = ref.read(connectivityCheckerProvider);
    final actionClient = ref.read(vanaActionClientProvider);
    final mealPlanController = ref.read(mealPlanControllerProvider.notifier);
    final repo = _repo;
    final report = _report;
    if (!await connectivity.isOnline()) return;
    try {
      final result = await actionClient.run(
        SetSettingAction(key: setting, value: value),
      );
      for (final part in result.parts) {
        if (part is VanaMemorySavedPart) {
          await repo.applyServerMemory(part.memory, userId: userId);
        }
      }
      final plan = result.plan;
      if (plan != null) {
        await mealPlanController.applyServerPlan(plan);
      }
    } on VanaException catch (e) {
      report.degraded(
        e,
        area: 'meal_planning',
        message: 'set_setting action failed; local row stays dirty',
      );
      final upload = await repo.uploadDirtyRecords(userId);
      if (!upload.success) {
        report.degraded(
          LoggedFault('user_memories upload failed', context: _context),
          area: 'meal_planning',
          extra: {'error': upload.error},
        );
      }
    }
  }

  /// Forget a memory (local-first tombstone; replayed as `is_deleted`).
  Future<void> deleteMemory(String id) async {
    final userId = _userId;
    final current = state.value;
    if (userId == null || current == null) return;
    state = AsyncData(
      current.copyWith(
        memories: current.memories.where((m) => m.id != id).toList(),
      ),
    );
    final repo = _repo;
    final report = _report;
    final result = await AsyncValue.guard(() async {
      await repo.deleteMemory(id);
      unawaited(() async {
        final upload = await repo.uploadDirtyRecords(userId);
        if (!upload.success) {
          report.degraded(
            LoggedFault(
              'user_memories upload after delete failed',
              context: _context,
            ),
            area: 'meal_planning',
            extra: {'error': upload.error},
          );
        }
      }());
      return (ref.mounted ? state.value : null) ?? current;
    });
    if (ref.mounted) state = result;
  }
}

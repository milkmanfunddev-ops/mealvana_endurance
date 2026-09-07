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
import 'meal_plan_controller.dart';
import 'plan_reminder_service.dart';

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
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  static const _context = 'VANA_SETTINGS_CONTROLLER';

  String? _userId;
  StreamSubscription<Map<VanaSetting, bool?>>? _settingsSub;
  StreamSubscription<List<UserMemory>>? _memoriesSub;

  @override
  FutureOr<VanaSettingsState> build() async {
    final userId = await ref.watch(userIdProvider.future);
    _userId = userId;
    ref.onDispose(() {
      _settingsSub?.cancel();
      _memoriesSub?.cancel();
    });
    unawaited(_ensureSynced(userId));

    final settings = await _repo.watchSettings(userId).first;
    final memories = await _repo.watchMemories(userId).first;
    final initial = _fold(
      VanaSettingsState(
        remindersEnabled: ref.read(planReminderServiceProvider).remindersEnabled,
      ),
      settings,
      memories,
    );

    _settingsSub = _repo.watchSettings(userId).listen((s) {
      final current = state.value;
      if (current == null || !ref.mounted) return;
      state = AsyncData(_fold(current, s, current.memories));
    });
    _memoriesSub = _repo.watchMemories(userId).listen((m) {
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

  Future<void> _setSetting(VanaSetting setting, bool value) async {
    final userId = _userId;
    final current = state.value;
    if (userId == null || current == null) return;

    state = AsyncData(switch (setting) {
      VanaSetting.batchCooking => current.copyWith(batchCooking: value),
      VanaSetting.showMacros => current.copyWith(showMacros: value),
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
    bool value,
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

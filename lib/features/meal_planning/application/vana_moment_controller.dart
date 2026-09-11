import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../activities/presentation/providers/activities_controller.dart';
import '../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../data/vana_moment_store.dart';
import '../domain/vana_moment.dart';
import '../domain/week_start.dart';
import 'vana_ambient_conversation_controller.dart';

part 'vana_moment_controller.g.dart';

/// How often the moment is resolved again with nothing else changing, while
/// the clock alone can raise or retire one: a window opening or closing, or a
/// workout starting, is noticed within this.
const vanaMomentResolveInterval = Duration(minutes: 1);

/// Whether the platform asks for reduced motion. Overridden in tests.
@riverpod
bool vanaReducedMotion(Ref ref) => WidgetsBinding
    .instance
    .platformDispatcher
    .accessibilityFeatures
    .disableAnimations;

/// The launcher's moment right now, and how it is showing.
class VanaMomentState {
  const VanaMomentState({
    this.moment,
    this.phase = VanaMomentPhase.waiting,
    this.exchangeStart,
  });

  /// Null when Vana has nothing to say.
  final VanaMoment? moment;

  /// How the launcher shows [moment]. Meaningless without one.
  final VanaMomentPhase phase;

  /// Where the moment's opening turn sits in the day's ambient conversation,
  /// once it has been written there (VM-1); null before.
  final int? exchangeStart;

  /// The pill is out: the tab bar steps aside for it.
  bool get pillShows => moment != null && phase == VanaMomentPhase.pill;
}

/// The moment on the launcher (vana-moment spec). Global and per day, like
/// the launcher: it stays as the athlete moves between screens until it
/// retires.
///
/// Resolves [resolveVanaMoment] from today's activities and meal logs when
/// either changes, when the app comes back to the foreground, and every
/// [vanaMomentResolveInterval] while the clock matters: a workout today has
/// yet to start, or a finished one's recovery window has yet to close (with
/// neither, nothing changes until a row does). A raised moment
/// waits until the launcher's host calls [ring] with a launcher on screen, so
/// it never spends its one ring where nobody can see it. What rang, what was
/// answered and where each opening sits persist per user per day, so a
/// restart neither rings again nor loses the thread.
@Riverpod(keepAlive: true)
class VanaMomentController extends _$VanaMomentController {
  String _userId = '';
  String _day = '';
  VanaMomentDay _record = const VanaMomentDay();
  VanaMomentPhase _phase = VanaMomentPhase.waiting;
  String? _phaseKey;
  Timer? _tick;
  Timer? _phaseTimer;
  AppLifecycleListener? _lifecycle;

  @override
  Future<VanaMomentState> build() async {
    // Riverpod reuses the notifier across a rebuild: start clean.
    _cancelTimers();
    _phase = VanaMomentPhase.waiting;
    _phaseKey = null;
    ref.onDispose(_cancelTimers);

    _userId = await ref.watch(userIdProvider.future);
    _day = todayIso(_now());
    _record = ref
        .read(vanaMomentStoreProvider)
        .read(userId: _userId, day: _day);

    ref.listen(activitiesControllerProvider, (_, _) => _resolveInPlace());
    ref.listen(mealLogsForDateProvider(_day), (_, _) => _resolveInPlace());
    await ref.read(activitiesControllerProvider.future);
    await ref.read(mealLogsForDateProvider(_day).future);
    _lifecycle = AppLifecycleListener(onResume: _resolveInPlace);
    return _resolve();
  }

  /// Rings a waiting moment: once, and never again for the same workout and
  /// window. Under reduced motion there is no ring; the pill still shows.
  void ring() {
    final moment = state.value?.moment;
    if (moment == null || _phaseKey != moment.key) return;
    if (_phase != VanaMomentPhase.waiting) return;
    _save(_record.copyWith(rung: {..._record.rung, moment.key}));
    if (ref.read(vanaReducedMotionProvider)) {
      _enter(VanaMomentPhase.pill);
    } else {
      _enter(VanaMomentPhase.ring);
    }
  }

  /// The moment's opening turn was written into the day's conversation at
  /// [start] (VM-1). A second sheet opens on it rather than writing another.
  void opened(int start) {
    final moment = state.value?.moment;
    if (moment == null) return;
    _save(_record.copyWith(starts: {..._record.starts, moment.key: start}));
    _publish();
  }

  /// The athlete acted on the moment [key] (VM-3): it retires.
  void answer(String key) {
    if (_record.answered.contains(key)) return;
    _save(_record.copyWith(answered: {..._record.answered, key}));
    _resolveInPlace();
  }

  /// Where the moment [key]'s opening turn sits in the day's conversation,
  /// once written there.
  int? startOf(String key) => _record.starts[key];

  DateTime _now() => ref.read(vanaClockProvider)();

  void _enter(VanaMomentPhase phase) {
    _phaseTimer?.cancel();
    _phase = phase;
    _publish();
    final next = switch (phase) {
      VanaMomentPhase.ring => (vanaMomentRingDuration, VanaMomentPhase.pill),
      VanaMomentPhase.pill => (vanaMomentPillDuration, VanaMomentPhase.tinted),
      _ => null,
    };
    if (next == null) return;
    final key = _phaseKey;
    _phaseTimer = Timer(next.$1, () {
      if (_phaseKey == key) _enter(next.$2);
    });
  }

  void _resolveInPlace() {
    if (!ref.mounted || state.isLoading && !state.hasValue) return;
    if (todayIso(_now()) != _day) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncData(_resolve());
  }

  VanaMomentState _resolve() {
    final now = _now();
    final activities = ref.read(activitiesControllerProvider).value ?? const [];
    final logs = ref.read(mealLogsForDateProvider(_day)).value ?? const [];
    final moment = resolveVanaMoment(
      now: now,
      activities: activities,
      mealLogs: logs,
      rung: _record.rung,
      answered: _record.answered,
    );
    if (!vanaMomentClockMatters(now: now, activities: activities)) {
      _tick?.cancel();
      _tick = null;
    } else {
      _tick ??= Timer.periodic(
        vanaMomentResolveInterval,
        (_) => _resolveInPlace(),
      );
    }
    if (moment?.key != _phaseKey) {
      _phaseTimer?.cancel();
      _phaseKey = moment?.key;
      _phase = moment == null || moment.rings
          ? VanaMomentPhase.waiting
          : VanaMomentPhase.tinted;
    }
    return _state(moment);
  }

  VanaMomentState _state(VanaMoment? moment) => VanaMomentState(
    moment: moment,
    phase: _phase,
    exchangeStart: moment == null ? null : _record.starts[moment.key],
  );

  void _publish() {
    if (!ref.mounted) return;
    state = AsyncData(_state(state.value?.moment));
  }

  /// Holds [record] now and writes it behind. A failed write costs at most
  /// one more ring after a restart; it is logged, not surfaced.
  void _save(VanaMomentDay record) {
    _record = record;
    unawaited(
      ref
          .read(vanaMomentStoreProvider)
          .write(userId: _userId, day: _day, record: record)
          .catchError((Object e) {
            if (!ref.mounted) return;
            ref
                .read(appExternalDepsProvider)
                .logger
                .warning(
                  'moment record not saved',
                  context: 'VANA_MOMENT',
                  error: e,
                );
          }),
    );
  }

  void _cancelTimers() {
    _tick?.cancel();
    _tick = null;
    _phaseTimer?.cancel();
    _phaseTimer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}

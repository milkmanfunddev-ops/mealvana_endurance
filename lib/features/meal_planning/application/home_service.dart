import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/connectivity_checker.dart';
import '../../../shared/services/logging_service.dart';
import '../data/vana_action_client.dart';
import '../domain/home_payload.dart';
import '../domain/ui_action.dart';
import '../domain/week_start.dart';
import 'meal_plan_controller.dart';

part 'home_service.g.dart';

@riverpod
HomeService homeService(Ref ref) => HomeService(
  actions: ref.watch(vanaActionClientProvider),
  logger: ref.watch(appExternalDepsProvider).logger,
);

/// `get_home{date}` → [HomePayload]: everything the Plan tab needs in one
/// call, no model involved. The payload's `batch` is folded into
/// [MealPlanController] by the caller so the local plan matches.
class HomeService {
  HomeService({required VanaActionClient actions, required AppLogger logger})
    : _actions = actions,
      _logger = logger;

  final VanaActionClient _actions;
  final AppLogger _logger;

  Future<HomePayload> fetch({String? date}) async {
    final result = await _actions.run(GetHomeAction(date: date));
    final home = result.home;
    if (home == null) {
      _logger.error('get_home returned no home payload', context: 'HOME');
      throw StateError('get_home returned no home payload');
    }
    return home;
  }
}

/// The Plan tab's header data for [date] (`YYYY-MM-DD`; today by default).
///
/// Online only — offline the value is `null` and the tab renders from the
/// local plan alone. When the day note is `stale` (the server is
/// regenerating notes after an edit) the controller re-polls once after
/// [stalePollDelay], up to [maxStalePolls] times; it never generates a note
/// client-side.
///
/// A refresh cannot start a second generation (ai-cost ticket 13, mp-478).
/// Every `get_home` on a stale note asks the server to regenerate, so two
/// things are bounded here: one `get_home` is in flight at a time — a refresh
/// that lands while the server is still writing joins the load already
/// running — and the [maxStalePolls] budget is spent once and only refilled
/// when fresh notes come back, so pulling to refresh does not buy more polls.
@riverpod
class HomeController extends _$HomeController {
  static const stalePollDelay = Duration(seconds: 7);
  static const maxStalePolls = 3;

  Timer? _stalePoll;
  int _stalePolls = 0;
  Future<HomePayload>? _inflight;

  @override
  FutureOr<HomePayload?> build([String? date]) async {
    ref.onDispose(() => _stalePoll?.cancel());
    if (!await ref.read(connectivityCheckerProvider).isOnline()) return null;
    final home = await _load(date ?? todayIso());
    return home;
  }

  /// One `get_home` at a time. Nothing between entering here and storing
  /// [_inflight] awaits, so two callers in the same turn cannot both start one.
  Future<HomePayload> _load(String date) async {
    final inflight = _inflight;
    if (inflight != null) return inflight;
    final future = _loadOnce(date);
    _inflight = future;
    try {
      return await future;
    } finally {
      _inflight = null;
    }
  }

  Future<HomePayload> _loadOnce(String date) async {
    final home = await ref.read(homeServiceProvider).fetch(date: date);
    final batch = home.batch;
    if (batch != null) {
      await ref
          .read(mealPlanControllerProvider.notifier)
          .applyServerPlan(batch.plan);
    }
    _scheduleStalePoll(home, date);
    return home;
  }

  void _scheduleStalePoll(HomePayload home, String date) {
    _stalePoll?.cancel();
    // Fresh notes: the next edit gets a full budget of polls.
    if (!home.vana.stale) {
      _stalePolls = 0;
      return;
    }
    // Still stale after the budget: stop asking. The budget stays spent, so a
    // refresh re-reads the payload without asking for another generation.
    if (_stalePolls >= maxStalePolls) return;
    _stalePolls++;
    _stalePoll = Timer(stalePollDelay, () async {
      if (!ref.mounted) return;
      final next = await AsyncValue.guard(() => _load(date));
      if (!ref.mounted) return;
      // A failed re-poll keeps the stale-but-valid payload on screen.
      if (next.hasValue) state = next;
    });
  }

  Future<void> refresh() async {
    final previous = state.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (!await ref.read(connectivityCheckerProvider).isOnline()) {
        return previous;
      }
      return _load(date ?? todayIso());
    });
  }

  /// The plan changed under the note (a confirm, a pick, a serving edit that
  /// has landed): read the payload again so the note speaks about the plan
  /// on the tab, not the one it replaced (Finding 88-023). The note on
  /// screen stays until the new one lands. A plan write is a new edit, so
  /// the stale-poll budget is refilled: the server is rewriting the notes
  /// and the tab may follow them in. Offline, nothing is read.
  Future<void> planChanged() async {
    if (!await ref.read(connectivityCheckerProvider).isOnline()) return;
    _stalePolls = 0;
    final next = await AsyncValue.guard(() => _load(date ?? todayIso()));
    if (!ref.mounted) return;
    if (next.hasValue) state = next;
  }
}

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
@riverpod
class HomeController extends _$HomeController {
  static const stalePollDelay = Duration(seconds: 7);
  static const maxStalePolls = 3;

  Timer? _stalePoll;
  int _stalePolls = 0;

  @override
  FutureOr<HomePayload?> build([String? date]) async {
    ref.onDispose(() => _stalePoll?.cancel());
    if (!await ref.read(connectivityCheckerProvider).isOnline()) return null;
    final home = await _load(date ?? todayIso());
    return home;
  }

  Future<HomePayload> _load(String date) async {
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
    if (!home.vana.stale || _stalePolls >= maxStalePolls) {
      _stalePolls = 0;
      return;
    }
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
    _stalePolls = 0;
    final previous = state.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (!await ref.read(connectivityCheckerProvider).isOnline()) {
        return previous;
      }
      return _load(date ?? todayIso());
    });
  }
}

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/connectivity_checker.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import '../data/meal_plan_repository.dart';
import '../data/vana_action_client.dart';
import '../data/vana_exceptions.dart';
import '../domain/cooking_session.dart';
import '../domain/day_plan.dart';
import '../domain/meal_plan.dart';
import '../domain/meal_source.dart';
import '../domain/meal_type.dart';
import '../domain/plan_meal.dart';
import '../domain/ui_action.dart';
import '../domain/vana_part.dart';
import '../domain/week_start.dart';

part 'meal_plan_controller.g.dart';

/// The active plan for the current week — what the Plan tab, the Shopping
/// tab, the chat's plan bar and the day planner all read.
///
/// - Watches Drift (`MealPlanRepository.watchActivePlan`) so every local or
///   server-applied change re-emits, and kicks `ensureSynced('meal_plans')`
///   in the background on first build (never blocks on the network).
/// - **Local-first** edits (05 §3): [setServings], [removeMeal],
///   [setSession], [addComment], [toggleShopping], [setDaySlot],
///   [clearDaySlot] write Drift and schedule a best-effort upload.
/// - **Remote-ack** edits: [pickMeals], [swapMeal], [confirmPlan],
///   [newPlan], [logFromPlan], [planDay] call `vana-action`, fold the
///   returned `batch` into Drift with [applyServerPlan], and throw
///   [NeedsConnectionException] when offline before sending anything.
///
/// Session-scoped (`keepAlive`) so the chat can fold `batch` parts into it
/// even while no screen is watching.
@Riverpod(keepAlive: true)
class MealPlanController extends _$MealPlanController {
  MealPlanRepository get _repo => ref.read(mealPlanRepositoryProvider);
  VanaActionClient get _actions => ref.read(vanaActionClientProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  static const _context = 'MEAL_PLAN_CONTROLLER';

  StreamSubscription<MealPlan?>? _subscription;
  String? _userId;
  String? _weekStart;

  /// The week this controller is bound to (`YYYY-MM-DD`, Sunday).
  String get weekStart => _weekStart ?? weekStartFor();

  @override
  FutureOr<MealPlan?> build() async {
    final userId = await ref.watch(userIdProvider.future);
    _userId = userId;
    _weekStart = weekStartFor();

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    // Repository-level on-demand sync — fire and forget so an offline
    // athlete still sees the cached plan immediately.
    unawaited(_ensureSynced(userId));

    final completer = Completer<MealPlan?>();
    _subscription?.cancel();
    _subscription = _repo
        .watchActivePlan(userId, _weekStart!)
        .listen(
          (plan) {
            if (!completer.isCompleted) {
              completer.complete(plan);
              return;
            }
            if (ref.mounted) state = AsyncData(plan);
          },
          onError: (Object e, StackTrace st) {
            if (!completer.isCompleted) {
              completer.completeError(e, st);
            } else if (ref.mounted) {
              state = AsyncError<MealPlan?>(e, st);
            }
          },
        );
    return completer.future;
  }

  Future<void> _ensureSynced(String userId) async {
    try {
      await ref
          .read(syncCoordinatorProvider.notifier)
          .ensureSynced('meal_plans', userId, repository: _repo);
    } catch (e) {
      _logger.warning(
        'meal_plans ensureSynced failed (non-fatal)',
        context: _context,
        error: e,
      );
    }
  }

  /// Pull-to-refresh: force a sync regardless of staleness.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await ref
        .read(syncCoordinatorProvider.notifier)
        .forceSyncRepository('meal_plans', userId, repository: _repo);
  }

  // ── Server payloads (chat `batch` parts, `get_home`) ──────────────────────

  /// Fold a server-authored plan into Drift as truth. The watch stream then
  /// re-emits. Used by the chat controller for every `batch` part and by
  /// the home service.
  Future<void> applyServerPlan(MealPlan plan) async {
    final userId = await _resolveUserId();
    await _repo.applyServerPlan(plan, userId: userId);
  }

  Future<String> _resolveUserId() async {
    final cached = _userId;
    if (cached != null) return cached;
    final id = await ref.read(userIdProvider.future);
    _userId = id;
    return id;
  }

  // ── Local-first edits ─────────────────────────────────────────────────────

  Future<void> setServings(String planMealId, int servings) =>
      _localFirst(() => _repo.setServings(planMealId, servings));

  Future<void> removeMeal(String planMealId) =>
      _localFirst(() => _repo.removeMeal(planMealId));

  Future<void> setSession(String planMealId, CookingSession? session) =>
      _localFirst(() => _repo.setSession(planMealId, session));

  Future<void> addComment(String planMealId, String text) =>
      _localFirst(() => _repo.addComment(planMealId, text));

  /// Flip a shopping item's `checked` / `have` flag on the active plan.
  Future<void> toggleShopping(
    String name,
    ShoppingField field,
    bool value,
  ) async {
    final planId = state.value?.id;
    if (planId == null) return;
    await _localFirst(() => _repo.toggleShopping(planId, name, field, value));
  }

  /// Write a day-planner slot on the active plan. Requires a local plan —
  /// with none, use [planDay] / the server (which creates one).
  Future<void> setDaySlot(String date, MealType slot, DaySlotRef ref) async {
    final planId = state.value?.id;
    if (planId == null) throw const NeedsConnectionException('set_day_slot');
    await _localFirst(() => _repo.setDaySlot(planId, date, slot, ref));
  }

  Future<void> clearDaySlot(String date, MealType slot) async {
    final planId = state.value?.id;
    if (planId == null) return;
    await _localFirst(() => _repo.setDaySlot(planId, date, slot, null));
  }

  Future<void> _localFirst(Future<void> Function() write) async {
    await write();
    _scheduleUpload();
  }

  /// Best-effort replay of dirty rows, then a server re-read so derived
  /// fields the RPCs do not rebuild (`shopping`, coverage) land locally.
  /// Rows stay dirty on failure and the next `ensureSynced` retries.
  void _scheduleUpload() {
    final userId = _userId;
    if (userId == null) return;
    unawaited(() async {
      final result = await _repo.uploadDirtyRecords(userId);
      if (!result.success) {
        _logger.warning(
          'Deferred meal-plan upload failed; rows stay dirty',
          context: _context,
          data: {'error': result.error},
        );
        return;
      }
      if (result.count == 0) return;
      await _refreshFromServer(userId);
    }());
  }

  Future<void> _refreshFromServer(String userId) async {
    final planId = state.value?.id;
    if (planId == null) return;
    try {
      final result = await _actions.run(GetPlanAction(id: planId));
      final plan = result.plan;
      if (plan != null) await _repo.applyServerPlan(plan, userId: userId);
    } on VanaException catch (e) {
      _logger.debug(
        'Plan re-read after upload skipped',
        context: _context,
        error: e,
      );
    }
  }

  // ── Remote-ack edits ──────────────────────────────────────────────────────

  /// Add meals to the plan (`pick_meals`). [conversationId] scopes the write
  /// to that conversation's draft; otherwise the week-level active plan.
  Future<MealPlan?> pickMeals(
    List<MealPick> meals, {
    int? servings,
    CookingSession? session,
    bool sendSession = false,
    String? conversationId,
    String? planId,
  }) => _remoteAck(
    PickMealsAction(
      meals: meals,
      servings: servings,
      session: session,
      sendSession: sendSession,
      conversationId: conversationId,
      planId: planId,
    ),
    (r) => r.plan,
  );

  /// Replace [planMealId] with the meal `{source, id}` (`swap_meal`).
  Future<MealPlan?> swapMeal(
    String planMealId, {
    required MealSource source,
    required String id,
  }) => _remoteAck(
    SwapMealAction(planMealId: planMealId, source: source, id: id),
    (r) => r.plan,
  );

  /// Confirm the draft (`confirm_plan`) — the server builds the shopping
  /// list and archives the week's other plans. Returns the confirmed plan.
  Future<MealPlan?> confirmPlan({
    String? date,
    String? conversationId,
    String? planId,
  }) => _remoteAck(
    ConfirmPlanAction(
      date: date,
      conversationId: conversationId,
      planId: planId,
    ),
    (r) => r.plan,
  );

  /// Archive the current plan and start an empty draft (`new_plan`).
  Future<MealPlan?> newPlan({String? conversationId}) =>
      _remoteAck(NewPlanAction(conversationId: conversationId), (r) => r.plan);

  /// Log one serving of a plan meal (`log_from_plan` → meal_logs row +
  /// servings_left decrement). Returns the `logged` part.
  Future<VanaLoggedPart?> logFromPlan(
    String planMealId, {
    MealType? mealType,
  }) => _remoteAck(
    LogFromPlanAction(planMealId: planMealId, mealType: mealType),
    (r) => r.parts.whereType<VanaLoggedPart>().firstOrNull,
  );

  /// Fill a day's empty slots (`plan_day`). Returns the `day` part; the
  /// plan's `days` are re-read afterwards so the local copy matches.
  Future<VanaDayPart?> planDay({String? date}) async {
    final part = await _remoteAck(
      PlanDayAction(date: date),
      (r) => r.parts.whereType<VanaDayPart>().firstOrNull,
    );
    final userId = _userId;
    if (userId != null) await _refreshFromServer(userId);
    return part;
  }

  /// Shared remote-ack path: refuse offline, push pending local edits so the
  /// server acts on the latest state, run the action, fold its `batch`
  /// into Drift. The error (if any) is both stored in [state] and rethrown
  /// so the caller can gate navigation on the ack.
  Future<T> _remoteAck<T>(
    UiAction action,
    T Function(VanaActionResult result) map,
  ) async {
    final online = await ref.read(connectivityCheckerProvider).isOnline();
    if (!online) throw NeedsConnectionException(action.type);

    final userId = await _resolveUserId();

    final pending = await _repo.uploadDirtyRecords(userId);
    if (!pending.success) {
      _logger.warning(
        'Could not flush local edits before ${action.type}; proceeding',
        context: _context,
        data: {'error': pending.error},
      );
    }

    // The Drift watch owns the data state, so the in-flight action does not
    // replace it with a value-less loading/error state (the Plan tab would
    // blank). guard() captures the outcome; a failure restores the previous
    // plan and rethrows so the caller can gate navigation on the ack.
    final previous = state;

    final outcome = await AsyncValue.guard(() async {
      final result = await _actions.run(action);
      final plan = result.plan;
      if (plan != null) await _repo.applyServerPlan(plan, userId: userId);
      return result;
    });

    if (!ref.mounted) throw StateError('MealPlanController disposed');

    if (outcome.hasError) {
      state = previous;
      Error.throwWithStackTrace(
        outcome.error!,
        outcome.stackTrace ?? StackTrace.current,
      );
    }

    final result = outcome.requireValue;
    // The Drift watch re-emits the applied plan; restore a data state now so
    // the UI never sits in "loading" when the payload changed nothing.
    final applied = result.plan;
    final showsThisWeek =
        applied != null &&
        applied.weekStart == weekStart &&
        !applied.status.wire.contains('archived');
    state = AsyncData(showsThisWeek ? applied : previous.value);
    return map(result);
  }

  /// The meal with [planMealId] in the current plan, if any.
  PlanMeal? mealById(String planMealId) {
    final plan = state.value;
    if (plan == null) return null;
    for (final meal in plan.meals) {
      if (meal.id == planMealId) return meal;
    }
    return null;
  }
}

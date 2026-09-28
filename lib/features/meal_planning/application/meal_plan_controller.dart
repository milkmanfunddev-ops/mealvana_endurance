import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/providers/fresh_sign_in_provider.dart';
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
import '../domain/meal_plan_status.dart';
import '../domain/meal_source.dart';
import '../domain/meal_type.dart';
import '../domain/plan_meal.dart';
import '../domain/plan_rule.dart';
import '../domain/ui_action.dart';
import '../domain/vana_part.dart';
import '../domain/week_start.dart';
import 'home_service.dart';
import 'plan_reminder_service.dart';
import 'youre_set_controller.dart';

part 'meal_plan_controller.g.dart';

/// The athlete's plan period (mp-269) from the `week_start` / `period_days`
/// settings rows in Drift. Re-emits only when either changes, so
/// [MealPlanController] rebinds to the new week exactly then.
@Riverpod(keepAlive: true)
Stream<PlanPeriod> planPeriod(Ref ref) async* {
  final userId = await ref.watch(userIdProvider.future);
  yield* ref.watch(mealPlanRepositoryProvider).watchPlanPeriod(userId);
}

/// The plan a Vana conversation owns, read from Drift, so a screen opened
/// from the chat ("Browse meals") knows which meals are already in it —
/// at once and offline. Every remote-ack write folds the returned plan
/// into Drift, so a pick re-emits here.
///
/// On first build the server's copy is folded in too (fire-and-forget,
/// like `ensureSynced`): the chat reads its draft through `get_plan`
/// without writing it locally, so a conversation reopened on a fresh
/// install may have no local row yet (testing-wave 18-003). `get_plan`
/// with a conversation and no plan creates nothing.
@riverpod
Stream<MealPlan?> conversationDraft(Ref ref, String conversationId) async* {
  final userId = await ref.watch(userIdProvider.future);
  final repo = ref.watch(mealPlanRepositoryProvider);
  final actions = ref.read(vanaActionClientProvider);
  final logger = ref.read(appExternalDepsProvider).logger;
  unawaited(() async {
    try {
      final result = await actions.run(
        GetPlanAction(conversationId: conversationId),
      );
      final plan = result.plan;
      if (plan != null) await repo.applyServerPlan(plan, userId: userId);
    } catch (e) {
      logger.debug(
        'conversation plan not refreshed from the server (non-fatal)',
        context: MealPlanController._context,
        error: e,
      );
    }
  }());
  yield* repo.watchConversationPlan(userId, conversationId);
}

/// The active plan for the current week — what the Plan tab, the Shopping
/// tab, the chat's plan bar and the day planner all read.
///
/// - Watches Drift (`MealPlanRepository.watchActivePlan`) so every local or
///   server-applied change re-emits, and kicks `ensureSynced('meal_plans')`
///   on first build. A local plan answers at once with the sync behind it;
///   with nothing local and the network up, the first read waits for the
///   sync (bounded by [firstReadBound]) so the Plan tab shows loading, never
///   "No plan yet", over a plan confirmed elsewhere (testing-wave 19-004).
/// - **Local-first** edits (05 §3): [setServings], [removeMeal],
///   [setSession], [addComment], [toggleShopping], [setDaySlot],
///   [clearDaySlot] write Drift and schedule a best-effort upload.
/// - **Remote-ack** edits: [pickMeals], [swapMeal], [confirmPlan],
///   [newPlan], [logFromPlan], [planDay], [planWeek], [usePlanAgain] call
///   `vana-action`, fold the returned `batch` into Drift with
///   [applyServerPlan], and throw [NeedsConnectionException] when offline
///   before sending anything.
///
/// Session-scoped (`keepAlive`) so the chat can fold `batch` parts into it
/// even while no screen is watching.
@Riverpod(keepAlive: true)
class MealPlanController extends _$MealPlanController {
  MealPlanRepository get _repo => ref.read(mealPlanRepositoryProvider);
  VanaActionClient get _actions => ref.read(vanaActionClientProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  static const _context = 'MEAL_PLAN_CONTROLLER';

  /// How long the first read waits for the `meal_plans` sync when there is
  /// no local plan. Past it the empty local table answers and the sync
  /// lands behind through the Drift watch.
  static const firstReadBound = Duration(seconds: 15);

  StreamSubscription<MealPlan?>? _subscription;
  String? _userId;
  String? _weekStart;

  /// "Ate it" writes on the wire, by plan-meal id: a second tap on the same
  /// row joins the first instead of logging a second serving.
  /// Kept across `invalidate` on purpose: a write still on the wire after a
  /// refresh must still be joined, and each write removes only its own entry.
  final Map<String, Future<VanaLoggedPart?>> _logsInFlight = {};

  /// The `requestId` of each dedupable write that has not succeeded yet, by
  /// the action it stands for (testing-wave 134, #82): a retry after "needs
  /// a connection" or a server error sends the same id, so a write the
  /// server finished after we hung up is answered from its stored result
  /// and never done twice. Removed on success, so the next tap on the same
  /// row is a new action with a new id. Kept across `invalidate` like
  /// [_logsInFlight]: a refresh must not turn a retry into a new write.
  ///
  /// An id is a retry's only for [_requestIdLifetime] after it was minted:
  /// a tap long after a failed one is a new action (another serving of the
  /// same batch row, the same meal picked again next week), and replaying
  /// the old id there would answer it from the stored result and write
  /// nothing (wave 43 review).
  final Map<String, ({String id, DateTime minted})> _pendingRequestIds = {};

  static const _requestIdLifetime = Duration(minutes: 2);

  String _requestIdFor(String actionKey) {
    final now = DateTime.now();
    final pending = _pendingRequestIds[actionKey];
    if (pending != null &&
        now.difference(pending.minted) < _requestIdLifetime) {
      return pending.id;
    }
    final id = const Uuid().v4();
    _pendingRequestIds[actionKey] = (id: id, minted: now);
    return id;
  }

  /// After a write landed: the next call for [actionKey] is a new action.
  /// After a failure the id stays for the retry. Runs twice at once only if
  /// two calls share a key, which the callers prevent ([logFromPlan] joins,
  /// the Browse screen holds a card's Add while one is on the wire).
  Future<T> _withRequestId<T>(
    String actionKey,
    Future<T> Function(String requestId) send,
  ) async {
    final result = await send(_requestIdFor(actionKey));
    _pendingRequestIds.remove(actionKey);
    return result;
  }

  /// The week this controller is bound to (`YYYY-MM-DD`, on the athlete's
  /// week-start day — Sunday by default).
  String get weekStart => _weekStart ?? weekStartFor();

  @override
  FutureOr<MealPlan?> build() async {
    final userId = await ref.watch(userIdProvider.future);
    _userId = userId;
    // The week follows the athlete's start-day setting; a change rebuilds
    // this controller onto the new week (mp-269).
    final period = await ref.watch(planPeriodProvider.future);
    _weekStart = period.startFor();

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    // Repository-level on-demand sync. Not awaited up front, so a cached
    // plan (or an offline athlete) never waits on the network; only a first
    // read with nothing local waits for it, below.
    final synced = _ensureSynced(userId);

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
    final local = await completer.future;
    // The first read after a sign-in in this process waits for the pull even
    // over a local plan: the rows this account left on the phone may be
    // stale (a draft dev has since archived, 120-001), and the tab must not
    // show them for a second before the pull replaces them. A normal launch
    // (restored session) stays local-first.
    final freshSignIn = ref.read(freshSignInProvider);
    if (local != null && !freshSignIn) return local;

    // Nothing local, or a fresh sign-in. Offline, what is local is the
    // answer. Online, the server may hold the week's plan (a fresh install,
    // a plan confirmed on another device): wait for the sync so the screen
    // shows loading meanwhile, then read what it wrote. The sync dedupes
    // with itself, so this is the same round trip, not a second one; a fresh
    // stamp makes it a no-op.
    final online = await ref.read(connectivityCheckerProvider).isOnline();
    if (!online) return local;
    await synced.timeout(firstReadBound, onTimeout: () {});
    if (freshSignIn) ref.read(freshSignInProvider.notifier).clear();
    return _repo.getActivePlan(userId, _weekStart!);
  }

  Future<void> _ensureSynced(String userId) async {
    try {
      await ref
          .read(syncCoordinatorProvider.notifier)
          .ensureSynced('meal_plans', userId, repository: _repo);
      // The coordinator replays edits made offline; their lists are owed a
      // rebuild just like a replay this controller scheduled (88-003). Not
      // awaited: the first read must not wait on a rebuild round trip.
      unawaited(_rebuildReplayedLists(userId));
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

  Future<void> setServings(String planMealId, int servings) async {
    await _localFirst(() => _repo.setServings(planMealId, servings));
  }

  Future<void> removeMeal(String planMealId) async {
    await _localFirst(() => _repo.removeMeal(planMealId));
  }

  Future<void> setSession(String planMealId, CookingSession? session) async {
    await _localFirst(() => _repo.setSession(planMealId, session));
  }

  Future<void> addComment(String planMealId, String text) async {
    await _localFirst(() => _repo.addComment(planMealId, text));
  }

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
          'Deferred meal-plan upload failed; rows stay dirty, '
          'shopping list not rebuilt',
          context: _context,
          data: {'error': result.error},
        );
        return;
      }
      await _rebuildReplayedLists(userId);
      if (result.count == 0) return;
      await _refreshFromServer(userId);
      _notifyHome();
    }());
  }

  /// mp-244: "the list is rebuilt after every plan edit". The replayed
  /// servings / remove RPCs touch `plan_meals` only, so each plan they
  /// touched gets `rebuild_shopping_list` once the replay has landed
  /// (testing-wave 88-003). A rebuild that fails stays owed and goes with
  /// the next successful upload.
  Future<void> _rebuildReplayedLists(String userId) async {
    for (final planId in _repo.takeReplayedPlanIds()) {
      try {
        final result = await _actions.run(
          RebuildShoppingListAction(planId: planId),
        );
        final plan = result.plan;
        if (plan != null) await _repo.applyServerPlan(plan, userId: userId);
      } catch (e) {
        _repo.owePlanRebuild(planId);
        _logger.warning(
          'Shopping list not rebuilt after a plan edit; retried next upload',
          context: _context,
          error: e,
          data: {'planId': planId},
        );
      }
    }
  }

  /// The Plan tab's day note reads `get_home` once and keeps it; after a
  /// plan write it must read again or it names the old plan's meal until a
  /// relaunch (Finding 88-023). Only while the tab is showing it: a note
  /// nobody is looking at costs a `get_home` for nothing.
  void _notifyHome() {
    if (!ref.exists(homeControllerProvider())) return;
    unawaited(ref.read(homeControllerProvider().notifier).planChanged());
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
  /// to that conversation's draft; otherwise the week-level active plan
  /// (the Plan tab's, or a new draft for the week). Carries a `requestId`
  /// keyed by the meals and the scope, so a retry of the same pick is the
  /// same request to the server.
  Future<MealPlan?> pickMeals(
    List<MealPick> meals, {
    int? servings,
    CookingSession? session,
    bool sendSession = false,
    String? conversationId,
    String? planId,
  }) async {
    // A conversation whose draft another confirm archived is read-only
    // (mp-675, mp-683; ticket 162, 88-005): refused here before anything is
    // sent, as the server refuses it, so Browse and the picker's cards
    // never write into the archived plan. Drift holds the conversation's
    // plan once the chat has read it; with nothing local the server's
    // refusal stands.
    if (conversationId != null && planId == null) {
      final local = await _repo
          .watchConversationPlan(await _resolveUserId(), conversationId)
          .first;
      if (local?.status == MealPlanStatus.archived) {
        throw ReplacedDraftException(conversationId);
      }
    }
    final ids = meals.map((m) => '${m.source.wire}/${m.id}').toList()..sort();
    final key = 'pick_meals:${planId ?? ''}:${conversationId ?? ''}:$ids';
    return _withRequestId(
      key,
      (requestId) => _remoteAck(
        PickMealsAction(
          meals: meals,
          servings: servings,
          session: session,
          sendSession: sendSession,
          conversationId: conversationId,
          planId: planId,
          requestId: requestId,
        ),
        (r) => r.plan,
      ),
    );
  }

  /// Take a meal out by its source reference (`unpick_meal`): the second tap
  /// on a ticked Browse card (testing-wave 134, 118-004). Same scope rule as
  /// [pickMeals]. Idempotent by nature, so no `requestId`.
  Future<MealPlan?> unpickMeal(
    MealSource source,
    String id, {
    String? conversationId,
    String? planId,
  }) async {
    return _remoteAck(
      UnpickMealAction(
        source: source,
        id: id,
        conversationId: conversationId,
        planId: planId,
      ),
      (r) => r.plan,
    );
  }

  /// Replace [planMealId] with the meal `{source, id}` (`swap_meal`).
  Future<MealPlan?> swapMeal(
    String planMealId, {
    required MealSource source,
    required String id,
  }) async {
    return _remoteAck(
      SwapMealAction(planMealId: planMealId, source: source, id: id),
      (r) => r.plan,
    );
  }

  /// Confirm the draft (`confirm_plan`) — the server builds the shopping
  /// list and archives the week's other plans. Returns the confirmed plan.
  Future<MealPlan?> confirmPlan({
    String? date,
    String? conversationId,
    String? planId,
  }) async {
    final plan = await _remoteAck(
      ConfirmPlanAction(
        date: date,
        conversationId: conversationId,
        planId: planId,
      ),
      (r) => r.plan,
    );
    if (plan != null) _confirmed(plan);
    return plan;
  }

  /// What every confirm does once the server has answered, whichever
  /// action confirmed the plan ([confirmPlan], [usePlanAgain]).
  void _confirmed(MealPlan plan) {
    // mp-235: every confirm lands on Food > Shopping, and the "you're
    // set" card waits there for this plan.
    ref.read(youreSetControllerProvider.notifier).confirmed(plan.id);
    // Phase 3.5: with the device toggle on, a confirmed plan gets its
    // check-in + debrief local notifications. Fire-and-forget — a
    // scheduling failure never fails the confirm.
    unawaited(_scheduleReminders(plan));
  }

  /// Rebuild the plan's shopping list from its meals
  /// (`rebuild_shopping_list`, ticket 96): the Plan tab's way back after the
  /// athlete deleted the list. The server updates the plan's one list in
  /// place (or makes it again) and refills the plan's `shopping` mirror,
  /// which the returned `batch` folds into Drift. Remote-ack like
  /// [confirmPlan]: refused offline, rethrown on failure.
  Future<MealPlan?> rebuildShoppingList({String? planId}) => _remoteAck(
    RebuildShoppingListAction(planId: planId ?? state.value?.id),
    (r) => r.plan,
  );

  Future<void> _scheduleReminders(MealPlan plan) async {
    try {
      final reminders = ref.read(planReminderServiceProvider);
      if (!reminders.remindersEnabled) return;
      await reminders.scheduleForPlan(plan);
    } catch (e) {
      _logger.warning(
        'plan reminders not scheduled (non-fatal)',
        context: _context,
        error: e,
      );
    }
  }

  /// Swap one ingredient inside a plan meal (`swap_ingredient`, plan Phase
  /// 6.3): the server creates the saved variant, swaps it into the plan and
  /// recomputes the shopping list; the returned `batch` is folded in.
  ///
  Future<MealPlan?> swapIngredient(
    String planMealId, {
    required String from,
    required String to,
    String? effect,
  }) async {
    return _remoteAck(
      SwapIngredientAction(planMealId: planMealId, from: from, to: to),
      (r) => r.plan,
    );
  }

  /// Accept a rule Vana proposed (`accept_rule`) — the rule is sent back
  /// with `accepted: true` and the server stores it on the plan. Replaces
  /// the 4c stopgap where the chat screen sent "Accept the rule: …" as a
  /// plain message (another model turn, no ack, no plan fold).
  Future<MealPlan?> acceptRule(PlanRule rule, {String? conversationId}) async {
    return _remoteAck(
      AcceptRuleAction(
        rule: rule.copyWith(accepted: true),
        conversationId: conversationId,
      ),
      (r) => r.plan,
    );
  }

  /// Archive the current plan and start an empty draft (`new_plan`).
  Future<MealPlan?> newPlan({String? conversationId}) async {
    return _remoteAck(
      NewPlanAction(conversationId: conversationId),
      (r) => r.plan,
    );
  }

  /// Copy plan [id] into this week and confirm it at once (`use_plan_again`,
  /// mp-675; Lee 2026-09-28, ticket 162): Previous plans' "Use this plan
  /// again" and the replaced draft's "Use this plan instead" (mp-676). The
  /// server archives the plan the week had as on any confirm, so the copy
  /// is folded into Drift with its siblings archived, the way
  /// [confirmPlan]'s answer is, and it becomes the plan on the tab. Then
  /// what every confirm does ([_confirmed]). Remote-ack: refuses offline
  /// before sending, and a failure rethrows. One `requestId` per tap, kept
  /// for its retry, so a double tap or a retry after the transport's
  /// timeout confirms one copy (the server dedupes it).
  Future<MealPlan?> usePlanAgain(String id) async {
    final plan = await _withRequestId(
      'use_plan_again:$id',
      (requestId) => _remoteAck(
        // The local day picks the week: the server's today() is UTC, a
        // day ahead on a Saturday evening west of it (ticket 162).
        UsePlanAgainAction(id: id, date: todayIso(), requestId: requestId),
        (r) => r.plan,
      ),
    );
    if (plan != null) _confirmed(plan);
    return plan;
  }

  /// Delete a plan outright (`delete_plan`), [id] naming it and the active
  /// plan standing in when it is omitted. Lee's 09-16 demo: the tab offered
  /// no way to get rid of a plan by hand.
  ///
  /// The result carries no `batch` — the plan is gone — so [_remoteAck]
  /// applies nothing; [refresh] is what drops it locally, because
  /// `syncFromRemote` deletes a non-archived plan the server no longer has.
  /// The returned receipt is what the caller offers Undo from.
  Future<VanaReceiptPart?> deletePlan({String? id}) async {
    final receipt = await _remoteAck(
      DeletePlanAction(id: id),
      (r) => r.parts.whereType<VanaReceiptPart>().firstOrNull,
    );
    await refresh();
    return receipt;
  }

  /// Put back the plan [receipt] deleted, sending its undo params verbatim.
  /// The server restores the rows; [refresh] pulls them back into Drift.
  Future<void> undoDeletePlan(VanaReceiptPart receipt) async {
    final undo = receipt.undo;
    if (undo == null) return;
    await _remoteAck(UndoReceiptAction(params: undo.params), (r) => r);
    await refresh();
  }

  /// "Ate it" (mp-239 detail 4): log one serving of a plan meal
  /// (`log_from_plan` → a meal_logs row with source plan and the plan meal's
  /// id, and servings_left one lower). Remote-ack: nothing moves until the
  /// server answers, and a failure leaves the row as it was and rethrows.
  /// A call for a row already being logged joins that call, so a double tap
  /// logs one serving. A tap after a failure retries with the same
  /// `requestId`, so a write that landed after the timeout is not logged
  /// twice (#82). Returns the `logged` part.
  Future<VanaLoggedPart?> logFromPlan(String planMealId, {MealType? mealType}) {
    final inFlight = _logsInFlight[planMealId];
    if (inFlight != null) return inFlight;
    final logs = _logsInFlight;
    final log = _withRequestId(
      'log_from_plan:$planMealId',
      (requestId) => _remoteAck(
        LogFromPlanAction(
          planMealId: planMealId,
          mealType: mealType,
          requestId: requestId,
        ),
        (r) => r.parts.whereType<VanaLoggedPart>().firstOrNull,
      ),
    ).whenComplete(() {
      // A block body: returning the removed Future would make whenComplete
      // wait on itself.
      logs.remove(planMealId);
    });
    logs[planMealId] = log;
    return log;
  }

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

  /// "Lay it across the week" (`plan_week`, mp-235 detail 3): the server
  /// lays the confirmed collection over the period's days and answers the
  /// `week` part. The plan's `days` are re-read afterwards so the local copy
  /// matches, as after [planDay].
  Future<VanaWeekPart?> planWeek() async {
    final part = await _remoteAck(
      const PlanWeekAction(),
      (r) => r.parts.whereType<VanaWeekPart>().firstOrNull,
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
      if (plan != null) {
        await _repo.applyServerPlan(
          plan,
          userId: userId,
          // Only a confirm's ack archives the week's other plans locally,
          // as the server just did; a pulled plan never does (120-002).
          // Use again confirms its copy on the server (ticket 162).
          archiveSiblings:
              action is ConfirmPlanAction || action is UsePlanAgainAction,
        );
      }
      return result;
    });

    if (!ref.mounted) throw StateError('MealPlanController disposed');

    if (outcome.hasError) {
      state = previous;
      // A timed-out request may still have landed on the server (the edge
      // function runs on after we hang up). Pull the plan before reporting,
      // so a write that did land shows and is not repeated by a second tap.
      final error = outcome.error;
      if (error is VanaOfflineException && error.cause is TimeoutException) {
        try {
          await refresh();
        } on Exception catch (e) {
          _logger.warning(
            'Refresh after a timed-out ${action.type} failed',
            context: _context,
            data: {'error': '$e'},
          );
        }
      }
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
    _notifyHome();
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

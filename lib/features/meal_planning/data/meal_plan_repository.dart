import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/data/syncable_repository.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../domain/cooking_session.dart';
import '../domain/day_plan.dart';
import '../domain/meal_icon.dart';
import '../domain/meal_plan.dart';
import '../domain/meal_plan_status.dart';
import '../domain/meal_source.dart';
import '../domain/meal_type.dart';
import '../domain/plan_coverage.dart';
import '../domain/plan_meal.dart';
import '../domain/plan_rule.dart';
import '../domain/shopping_item.dart';
import '../domain/ui_action.dart';
import '../domain/wire_record.dart';
import 'meal_plan_remote.dart';

part 'meal_plan_repository.g.dart';

@riverpod
MealPlanRepository mealPlanRepository(Ref ref) {
  final deps = ref.watch(appExternalDepsProvider);
  return MealPlanRepository(
    database: ref.watch(appDatabaseProvider),
    logger: deps.logger,
    remote: SupabaseMealPlanRemote(deps.supabaseClient),
  );
}

/// Repository for the week's meal plan (`meal_plans` + `plan_meals`).
///
/// Storage strategy (05 §3, write-consistency policy):
/// - **Plans are created server-side.** `pick_meals` / `swap_meal` /
///   `confirm_plan` / `new_plan` / `log_from_plan` / `plan_day` are
///   remote-ack `vana-action` calls; their `batch` result is written here by
///   [applyServerPlan], which treats the server payload as truth.
/// - **Local-first edits** — [setServings], [removeMeal], [setSession],
///   [addComment], [toggleShopping], [setDaySlot] — write Drift immediately
///   with `needs_upload = true` and are replayed by [uploadDirtyRecords]:
///   removals through `plan_remove_meal`, servings through
///   `plan_set_servings`, the fields with no RPC (`session`, `comments`,
///   `swaps_applied`) and the plan's `shopping` / `days` as targeted row
///   updates (RLS-scoped). Never an upsert on `(user_id, week_start)` — that
///   is a partial unique index.
/// - **Tombstones** on `plan_meals` are local-only (the server hard-deletes);
///   the local row is dropped once the removal has been replayed.
/// - [syncFromRemote] pulls the user's non-archived plans + meals with the
///   dirty-preserve rule and drops local rows the server no longer has.
class MealPlanRepository with SyncableRepository {
  MealPlanRepository({
    required AppDatabase database,
    required AppLogger logger,
    required MealPlanRemote remote,
  }) : _database = database,
       _logger = logger,
       _remote = remote;

  final AppDatabase _database;
  final AppLogger _logger;
  final MealPlanRemote _remote;

  static const _context = 'MEAL_PLAN_REPOSITORY';

  Future<SyncResult>? _inflightSync;

  // ========================================================================
  // SyncableRepository
  // ========================================================================

  @override
  String get repositoryKey => 'meal_plans';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    final inflight = _inflightSync;
    if (inflight != null) return inflight;
    final future = _syncFromRemoteImpl(userId);
    _inflightSync = future;
    try {
      return await future;
    } finally {
      _inflightSync = null;
    }
  }

  Future<SyncResult> _syncFromRemoteImpl(String userId) async {
    try {
      _logger.info(
        'Syncing meal plans from Supabase',
        context: _context,
        data: {'userId': userId},
      );

      final planRows = await _remote.fetchPlans(userId);
      final planIds = [
        for (final row in planRows)
          if (row['id'] case final String id) id,
      ];
      final mealRows = await _remote.fetchPlanMeals(userId, planIds);

      final count = await _database.transaction(() async {
        final dirtyPlanIds = await _dirtyIds(_database.mealPlansTable, userId);
        final dirtyMealIds = await _dirtyIds(_database.planMealsTable, userId);

        var upserted = 0;
        final remotePlanIds = <String>{};
        for (final row in planRows) {
          final companion = _planCompanionFromRow(row);
          if (companion == null) continue;
          remotePlanIds.add(companion.id.value);
          if (dirtyPlanIds.contains(companion.id.value)) continue;
          await _database
              .into(_database.mealPlansTable)
              .insert(companion, mode: InsertMode.insertOrReplace);
          upserted++;
        }

        final remoteMealIds = <String>{};
        for (final row in mealRows) {
          final companion = _mealCompanionFromRow(row);
          if (companion == null) continue;
          remoteMealIds.add(companion.id.value);
          if (dirtyMealIds.contains(companion.id.value)) continue;
          await _database
              .into(_database.planMealsTable)
              .insert(companion, mode: InsertMode.insertOrReplace);
          upserted++;
        }

        // Server truth: a non-archived plan missing remotely was archived or
        // deleted elsewhere; a meal missing remotely was removed. Drop the
        // clean local copies (dirty rows wait for their upload).
        await (_database.delete(_database.mealPlansTable)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.status.equals(MealPlanStatus.archived.wire).not() &
                  t.id.isIn(remotePlanIds).not() &
                  t.needsUpload.equals(true).not(),
            ))
            .go();
        if (remotePlanIds.isNotEmpty) {
          await (_database.delete(_database.planMealsTable)..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.planId.isIn(remotePlanIds) &
                    t.id.isIn(remoteMealIds).not() &
                    t.needsUpload.equals(true).not(),
              ))
              .go();
        }
        return upserted;
      });

      await setLastSyncTime(DateTime.now());
      _logger.info(
        'Synced meal plans from Supabase',
        context: _context,
        data: {'userId': userId, 'rows': count, 'plans': planIds.length},
      );
      return SyncResult.successful(count);
    } catch (e, st) {
      _logger.error(
        'Failed to sync meal plans from Supabase',
        context: _context,
        error: e,
        stackTrace: st,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      final dirtyMeals =
          await (_database.select(_database.planMealsTable)..where(
                (t) => t.userId.equals(userId) & t.needsUpload.equals(true),
              ))
              .get();
      final dirtyPlans =
          await (_database.select(_database.mealPlansTable)..where(
                (t) => t.userId.equals(userId) & t.needsUpload.equals(true),
              ))
              .get();
      if (dirtyMeals.isEmpty && dirtyPlans.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      _logger.info(
        'Uploading dirty meal-plan edits',
        context: _context,
        data: {'meals': dirtyMeals.length, 'plans': dirtyPlans.length},
      );

      var count = 0;
      for (final meal in dirtyMeals) {
        if (meal.isDeleted) {
          await _remote.removeMeal(meal.id);
          await (_database.delete(
            _database.planMealsTable,
          )..where((t) => t.id.equals(meal.id))).go();
        } else {
          await _remote.setServings(meal.id, meal.servings);
          await _remote.updatePlanMeal(meal.id, {
            'session': meal.session,
            'comments': _decodeList(meal.comments),
            'swaps_applied': _decodeList(meal.swapsApplied),
            'updated_at': meal.updatedAt.toUtc().toIso8601String(),
          });
          await (_database.update(_database.planMealsTable)
                ..where((t) => t.id.equals(meal.id)))
              .write(const PlanMealsTableCompanion(needsUpload: Value(false)));
        }
        count++;
      }

      for (final plan in dirtyPlans) {
        await _remote.updatePlan(plan.id, {
          'shopping': _decodeList(plan.shopping),
          'days': _decodeMap(plan.days),
          'day_notes_stale': plan.dayNotesStale,
          'updated_at': plan.updatedAt.toUtc().toIso8601String(),
        });
        await (_database.update(_database.mealPlansTable)
              ..where((t) => t.id.equals(plan.id)))
            .write(const MealPlansTableCompanion(needsUpload: Value(false)));
        count++;
      }

      return UploadResult.successful(count);
    } catch (e, st) {
      _logger.error(
        'Failed to upload dirty meal-plan edits',
        context: _context,
        error: e,
        stackTrace: st,
        data: {'userId': userId},
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ========================================================================
  // Queries
  // ========================================================================

  /// The active plan for [weekStart] (`YYYY-MM-DD`, Sunday): a confirmed
  /// plan wins over drafts; otherwise the most recently updated draft.
  /// Re-emits on any `meal_plans` / `plan_meals` change. `null` when the
  /// week has no plan yet.
  Stream<MealPlan?> watchActivePlan(String userId, String weekStart) {
    final plans = _database.mealPlansTable;
    final meals = _database.planMealsTable;
    final query =
        _database.select(plans).join([
          leftOuterJoin(
            meals,
            meals.planId.equalsExp(plans.id) & meals.isDeleted.equals(false),
          ),
        ])..where(
          plans.userId.equals(userId) &
              plans.weekStart.equals(weekStart) &
              plans.isDeleted.equals(false) &
              plans.status.equals(MealPlanStatus.archived.wire).not(),
        );
    return query.watch().map((rows) {
      final byPlan = <String, MealPlanEntry>{};
      final mealsByPlan = <String, List<PlanMealEntry>>{};
      for (final row in rows) {
        final plan = row.readTable(plans);
        byPlan[plan.id] = plan;
        final meal = row.readTableOrNull(meals);
        if (meal != null) mealsByPlan.putIfAbsent(plan.id, () => []).add(meal);
      }
      final active = _pickActive(byPlan.values);
      if (active == null) return null;
      return _assemble(active, mealsByPlan[active.id] ?? const []);
    });
  }

  /// One plan by id (with its live meals), or null. Re-emits on change.
  Stream<MealPlan?> watchPlan(String planId) {
    final plans = _database.mealPlansTable;
    final meals = _database.planMealsTable;
    final query = _database.select(plans).join([
      leftOuterJoin(
        meals,
        meals.planId.equalsExp(plans.id) & meals.isDeleted.equals(false),
      ),
    ])..where(plans.id.equals(planId));
    return query.watch().map((rows) {
      if (rows.isEmpty) return null;
      final plan = rows.first.readTable(plans);
      final planMeals = [
        for (final row in rows)
          if (row.readTableOrNull(meals) case final m?) m,
      ];
      return _assemble(plan, planMeals);
    });
  }

  Future<MealPlan?> getActivePlan(String userId, String weekStart) =>
      watchActivePlan(userId, weekStart).first;

  Future<MealPlan?> getPlanById(String planId) => watchPlan(planId).first;

  /// Every live (non-deleted) plan meal for [userId] across plans, newest
  /// first — the local half of the Recents rail.
  Future<List<PlanMeal>> getRecentPlanMeals(
    String userId, {
    int limit = 60,
  }) async {
    final rows =
        await (_database.select(_database.planMealsTable)
              ..where(
                (t) => t.userId.equals(userId) & t.isDeleted.equals(false),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(limit))
            .get();
    return rows.map(_planMealFromEntry).toList(growable: false);
  }

  /// `createdAt` of the newest plan meal per id — recency for Recents.
  Future<Map<String, DateTime>> planMealCreatedAt(String userId) async {
    final rows = await (_database.select(
      _database.planMealsTable,
    )..where((t) => t.userId.equals(userId))).get();
    return {for (final r in rows) r.id: r.createdAt};
  }

  // ========================================================================
  // Local-first edits
  // ========================================================================

  /// Set a meal's servings. `<= 0` removes it (tombstone). `servings_left`
  /// keeps what was already eaten, floored at 0 — the `plan_set_servings`
  /// rule — so the count survives the replay unchanged.
  Future<void> setServings(String planMealId, int servings) async {
    if (servings <= 0) return removeMeal(planMealId);
    final row = await _liveMeal(planMealId);
    if (row == null) return;
    final eaten = row.servings - row.servingsLeft;
    final left = servings - eaten;
    final now = DateTime.now();
    await _database.transaction(() async {
      await (_database.update(
        _database.planMealsTable,
      )..where((t) => t.id.equals(planMealId))).write(
        PlanMealsTableCompanion(
          servings: Value(servings),
          servingsLeft: Value(left < 0 ? 0 : left),
          updatedAt: Value(now),
          needsUpload: const Value(true),
          localUpdatedAt: Value(now),
        ),
      );
      await _markDayNotesStale(row.planId, now);
    });
    _logger.info(
      'Set servings',
      context: _context,
      data: {'planMealId': planMealId, 'servings': servings},
    );
  }

  /// Tombstone a meal locally; the row is hard-deleted after
  /// `plan_remove_meal` has been replayed.
  Future<void> removeMeal(String planMealId) async {
    final row = await _liveMeal(planMealId);
    if (row == null) return;
    final now = DateTime.now();
    await _database.transaction(() async {
      await (_database.update(
        _database.planMealsTable,
      )..where((t) => t.id.equals(planMealId))).write(
        PlanMealsTableCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
          needsUpload: const Value(true),
          localUpdatedAt: Value(now),
        ),
      );
      await _markDayNotesStale(row.planId, now);
    });
    _logger.info(
      'Removed plan meal',
      context: _context,
      data: {'planMealId': planMealId},
    );
  }

  /// Move a meal to a batch-cooking [session] (`null` clears it).
  Future<void> setSession(String planMealId, CookingSession? session) async {
    final row = await _liveMeal(planMealId);
    if (row == null) return;
    final now = DateTime.now();
    await (_database.update(
      _database.planMealsTable,
    )..where((t) => t.id.equals(planMealId))).write(
      PlanMealsTableCompanion(
        session: Value(session?.wire),
        updatedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );
  }

  /// Append a comment (`{role, text, at}`) to a meal.
  Future<void> addComment(
    String planMealId,
    String text, {
    PlanCommentRole role = PlanCommentRole.user,
  }) async {
    final row = await _liveMeal(planMealId);
    if (row == null) return;
    final now = DateTime.now();
    final comments = [
      ..._decodeList(row.comments),
      PlanComment(
        role: role,
        text: text,
        at: now.toUtc().toIso8601String(),
      ).toJson(),
    ];
    await (_database.update(
      _database.planMealsTable,
    )..where((t) => t.id.equals(planMealId))).write(
      PlanMealsTableCompanion(
        comments: Value(jsonEncode(comments)),
        updatedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );
  }

  /// Flip one shopping item's `checked` / `have` flag, matched by name
  /// (case-insensitive — the server's `plan_toggle_shopping` rule).
  Future<void> toggleShopping(
    String planId,
    String name,
    ShoppingField field,
    bool value,
  ) async {
    final plan = await _livePlan(planId);
    if (plan == null) return;
    final target = name.trim().toLowerCase();
    final items = _decodeList(plan.shopping).map((raw) {
      final item = ShoppingItem.fromJson(raw);
      if (item.name.trim().toLowerCase() != target) return raw;
      return switch (field) {
        ShoppingField.checked => item.copyWith(checked: value),
        ShoppingField.have => item.copyWith(have: value),
      }.toJson();
    }).toList();
    final now = DateTime.now();
    await (_database.update(
      _database.mealPlansTable,
    )..where((t) => t.id.equals(planId))).write(
      MealPlansTableCompanion(
        shopping: Value(jsonEncode(items)),
        updatedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );
  }

  /// Write (or clear, with `ref == null`) one day-planner slot.
  Future<void> setDaySlot(
    String planId,
    String date,
    MealType slot,
    DaySlotRef? ref,
  ) async {
    final plan = await _livePlan(planId);
    if (plan == null) return;
    final days = _decodeMap(plan.days);
    final day = Map<String, dynamic>.from(
      asJsonMap(days[date]) ?? const <String, dynamic>{},
    );
    if (ref == null) {
      day.remove(slot.wire);
    } else {
      day[slot.wire] = ref.toJson();
    }
    days[date] = day;
    final now = DateTime.now();
    await (_database.update(
      _database.mealPlansTable,
    )..where((t) => t.id.equals(planId))).write(
      MealPlansTableCompanion(
        days: Value(jsonEncode(days)),
        updatedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );
  }

  // ========================================================================
  // Server acks
  // ========================================================================

  /// Write a server `batch` payload into Drift as truth: the plan row, every
  /// meal it lists (clean), and drop local meals the server no longer has.
  /// A confirmed plan also archives the week's other local plans, mirroring
  /// `confirm_meal_plan`.
  Future<void> applyServerPlan(MealPlan plan, {required String userId}) async {
    final now = DateTime.now();
    await _database.transaction(() async {
      final existing = await _livePlan(plan.id);
      await _database
          .into(_database.mealPlansTable)
          .insert(
            _planCompanionFromWire(
              plan,
              userId: userId,
              createdAt: existing?.createdAt ?? now,
              now: now,
            ),
            mode: InsertMode.insertOrReplace,
          );

      final keep = <String>{};
      for (final meal in plan.meals) {
        keep.add(meal.id);
        final current = await (_database.select(
          _database.planMealsTable,
        )..where((t) => t.id.equals(meal.id))).getSingleOrNull();
        await _database
            .into(_database.planMealsTable)
            .insert(
              _mealCompanionFromWire(
                meal,
                userId: userId,
                createdAt: current?.createdAt ?? now,
                now: now,
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      await (_database.delete(
        _database.planMealsTable,
      )..where((t) => t.planId.equals(plan.id) & t.id.isIn(keep).not())).go();

      if (plan.isConfirmed) {
        await (_database.update(_database.mealPlansTable)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.weekStart.equals(plan.weekStart) &
                  t.id.equals(plan.id).not() &
                  t.status.equals(MealPlanStatus.archived.wire).not(),
            ))
            .write(
              MealPlansTableCompanion(
                status: Value(MealPlanStatus.archived.wire),
                updatedAt: Value(now),
              ),
            );
      }
    });
    _logger.info(
      'Applied server plan',
      context: _context,
      data: {
        'planId': plan.id,
        'status': plan.status.wire,
        'meals': plan.meals.length,
      },
    );
  }

  // ========================================================================
  // Mapping
  // ========================================================================

  MealPlanEntry? _pickActive(Iterable<MealPlanEntry> plans) {
    MealPlanEntry? best;
    for (final p in plans) {
      if (best == null) {
        best = p;
        continue;
      }
      final pConfirmed = p.status == MealPlanStatus.confirmed.wire;
      final bConfirmed = best.status == MealPlanStatus.confirmed.wire;
      if (pConfirmed != bConfirmed) {
        if (pConfirmed) best = p;
        continue;
      }
      if (p.updatedAt.isAfter(best.updatedAt)) best = p;
    }
    return best;
  }

  MealPlan _assemble(MealPlanEntry plan, List<PlanMealEntry> meals) {
    final sorted = [...meals]
      ..sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        return byPosition != 0
            ? byPosition
            : a.createdAt.compareTo(b.createdAt);
      });
    final daysJson = _decodeMap(plan.days);
    final days = <String, DayPlan>{
      for (final entry in daysJson.entries)
        if (asJsonMap(entry.value) case final map?)
          entry.key: DayPlan.fromJson(map),
    };
    final planMeals = sorted.map(_planMealFromEntry).toList(growable: false);
    return MealPlan(
      id: plan.id,
      weekStart: plan.weekStart,
      status: MealPlanStatus.fromWire(plan.status) ?? MealPlanStatus.draft,
      batchCooking: plan.batchCooking,
      days: Map.unmodifiable(days),
      conversationId: plan.conversationId,
      brief: plan.brief,
      rules: readRecordList(
        {'r': _decodeList(plan.rules)},
        'r',
        PlanRule.fromJson,
      ),
      meals: planMeals,
      shopping: readRecordList(
        {'s': _decodeList(plan.shopping)},
        's',
        ShoppingItem.fromJson,
      ),
      dayNotes: readStringMap({'d': _decodeMap(plan.dayNotes)}, 'd'),
      dayNotesStale: plan.dayNotesStale,
      coverage: PlanCoverageService.compute(planMeals),
    );
  }

  static PlanMeal _planMealFromEntry(PlanMealEntry e) => PlanMeal(
    id: e.id,
    planId: e.planId,
    source: MealSource.fromWire(e.source) ?? MealSource.library,
    libraryMealId: e.libraryMealId,
    savedMealId: e.savedMealId,
    name: e.name,
    mealType: MealType.fromWire(e.mealType) ?? MealType.dinner,
    session: CookingSession.fromWire(e.session),
    servings: e.servings,
    servingsLeft: e.servingsLeft,
    kcal: e.kcal,
    carbsG: e.carbsG,
    proteinG: e.proteinG,
    fatG: e.fatG,
    swapsApplied: readRecordList(
      {'s': _decodeList(e.swapsApplied)},
      's',
      SwapApplied.fromJson,
    ),
    comments: readRecordList(
      {'c': _decodeList(e.comments)},
      'c',
      PlanComment.fromJson,
    ),
    position: e.position,
    icon: MealIcon.fromWire(e.icon),
  );

  static MealPlansTableCompanion _planCompanionFromWire(
    MealPlan plan, {
    required String userId,
    required DateTime createdAt,
    required DateTime now,
  }) => MealPlansTableCompanion.insert(
    id: Value(plan.id),
    userId: userId,
    weekStart: plan.weekStart,
    status: Value(plan.status.wire),
    batchCooking: Value(plan.batchCooking),
    rules: Value(jsonEncode(plan.rules.map((r) => r.toJson()).toList())),
    shopping: Value(jsonEncode(plan.shopping.map((s) => s.toJson()).toList())),
    brief: Value(plan.brief),
    conversationId: Value(plan.conversationId),
    days: Value(
      jsonEncode({for (final e in plan.days.entries) e.key: e.value.toJson()}),
    ),
    dayNotes: Value(jsonEncode(plan.dayNotes)),
    dayNotesStale: Value(plan.dayNotesStale),
    createdAt: createdAt,
    updatedAt: now,
    isDeleted: const Value(false),
    needsUpload: const Value(false),
    localUpdatedAt: Value(now),
  );

  static PlanMealsTableCompanion _mealCompanionFromWire(
    PlanMeal meal, {
    required String userId,
    required DateTime createdAt,
    required DateTime now,
  }) => PlanMealsTableCompanion.insert(
    id: Value(meal.id),
    planId: meal.planId,
    userId: userId,
    source: meal.source.wire,
    libraryMealId: Value(meal.libraryMealId),
    savedMealId: Value(meal.savedMealId),
    name: meal.name,
    mealType: meal.mealType.wire,
    session: Value(meal.session?.wire),
    servings: Value(meal.servings),
    servingsLeft: Value(meal.servingsLeft),
    kcal: Value(meal.kcal),
    carbsG: Value(meal.carbsG),
    proteinG: Value(meal.proteinG),
    fatG: Value(meal.fatG),
    swapsApplied: Value(
      jsonEncode(meal.swapsApplied.map((s) => s.toJson()).toList()),
    ),
    comments: Value(jsonEncode(meal.comments.map((c) => c.toJson()).toList())),
    position: Value(meal.position),
    icon: Value(meal.icon?.wire),
    createdAt: createdAt,
    updatedAt: now,
    isDeleted: const Value(false),
    needsUpload: const Value(false),
    localUpdatedAt: Value(now),
  );

  /// Supabase `meal_plans` row (snake_case) → companion; null without an id.
  static MealPlansTableCompanion? _planCompanionFromRow(
    Map<String, dynamic> row,
  ) {
    final id = row['id']?.toString();
    final userId = row['user_id']?.toString();
    final weekStart = row['week_start']?.toString();
    if (id == null || userId == null || weekStart == null) return null;
    final now = DateTime.now();
    return MealPlansTableCompanion.insert(
      id: Value(id),
      userId: userId,
      weekStart: weekStart.length > 10 ? weekStart.substring(0, 10) : weekStart,
      status: Value(row['status']?.toString() ?? 'draft'),
      batchCooking: Value(row['batch_cooking'] != false),
      rules: Value(jsonEncode(row['rules'] ?? const [])),
      shopping: Value(jsonEncode(row['shopping'] ?? const [])),
      brief: Value(row['brief'] as String?),
      conversationId: Value(row['conversation_id'] as String?),
      days: Value(jsonEncode(row['days'] ?? const {})),
      dayNotes: Value(jsonEncode(row['day_notes'] ?? const {})),
      dayNotesStale: Value(row['day_notes_stale'] != false),
      dayNotesAt: Value(_parseTs(row['day_notes_at'])),
      createdAt: _parseTs(row['created_at']) ?? now,
      updatedAt: _parseTs(row['updated_at']) ?? now,
      isDeleted: Value(row['is_deleted'] == true),
      needsUpload: const Value(false),
      localUpdatedAt: Value(now),
    );
  }

  /// Supabase `plan_meals` row → companion; null without id/plan/name.
  static PlanMealsTableCompanion? _mealCompanionFromRow(
    Map<String, dynamic> row,
  ) {
    final id = row['id']?.toString();
    final planId = row['plan_id']?.toString();
    final userId = row['user_id']?.toString();
    final name = row['name'] as String?;
    if (id == null || planId == null || userId == null || name == null) {
      return null;
    }
    final now = DateTime.now();
    return PlanMealsTableCompanion.insert(
      id: Value(id),
      planId: planId,
      userId: userId,
      source: row['source']?.toString() ?? 'library',
      libraryMealId: Value(row['library_meal_id'] as String?),
      savedMealId: Value(row['saved_meal_id'] as String?),
      name: name,
      mealType: row['meal_type']?.toString() ?? 'dinner',
      session: Value(row['session'] as String?),
      servings: Value((row['servings'] as num?)?.toInt() ?? 1),
      servingsLeft: Value((row['servings_left'] as num?)?.toInt() ?? 1),
      kcal: Value((row['kcal'] as num?)?.toInt()),
      carbsG: Value((row['carbs_g'] as num?)?.toDouble()),
      proteinG: Value((row['protein_g'] as num?)?.toDouble()),
      fatG: Value((row['fat_g'] as num?)?.toDouble()),
      swapsApplied: Value(jsonEncode(row['swaps_applied'] ?? const [])),
      comments: Value(jsonEncode(row['comments'] ?? const [])),
      position: Value((row['position'] as num?)?.toInt() ?? 0),
      icon: Value(row['icon'] as String?),
      createdAt: _parseTs(row['created_at']) ?? now,
      updatedAt: _parseTs(row['updated_at']) ?? now,
      isDeleted: const Value(false),
      needsUpload: const Value(false),
      localUpdatedAt: Value(now),
    );
  }

  // ========================================================================
  // Helpers
  // ========================================================================

  Future<PlanMealEntry?> _liveMeal(String id) =>
      (_database.select(_database.planMealsTable)
            ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
          .getSingleOrNull();

  Future<MealPlanEntry?> _livePlan(String id) =>
      (_database.select(_database.mealPlansTable)
            ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
          .getSingleOrNull();

  Future<void> _markDayNotesStale(String planId, DateTime now) =>
      (_database.update(
        _database.mealPlansTable,
      )..where((t) => t.id.equals(planId))).write(
        MealPlansTableCompanion(
          dayNotesStale: const Value(true),
          localUpdatedAt: Value(now),
        ),
      );

  Future<Set<String>> _dirtyIds<T extends Table, D>(
    TableInfo<T, D> table,
    String userId,
  ) async {
    final rows = await _database
        .customSelect(
          'SELECT id FROM ${table.actualTableName} WHERE user_id = ? AND needs_upload = 1',
          variables: [Variable.withString(userId)],
          readsFrom: {table},
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  static List<Map<String, dynamic>> _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return [
          for (final item in decoded)
            if (asJsonMap(item) case final map?) map,
        ];
      }
    } catch (_) {
      // Malformed local JSON — treat as empty.
    }
    return const [];
  }

  static Map<String, dynamic> _decodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Malformed local JSON — treat as empty.
    }
    return <String, dynamic>{};
  }

  static DateTime? _parseTs(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

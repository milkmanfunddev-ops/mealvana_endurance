/// MealPlanRepository against an in-memory Drift DB and a recording remote.
///
/// Covers the write-consistency contract (05 §3): a local-first edit sets
/// needs_upload, the upload replays through the right RPC / row update,
/// syncFromRemote merges with dirty-preserve and prunes server-deleted rows,
/// and applyServerPlan writes a contract fixture as truth.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/cooking_session.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/day_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_status.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fixture_helpers.dart';
import '../helpers/fakes.dart';

const _user = 'user-1';
const _week = '2026-08-30';
final _now = DateTime.utc(2026, 9, 1, 12);

Map<String, dynamic> _planRow({
  String id = 'plan-1',
  String status = 'draft',
  List<Map<String, dynamic>> shopping = const [],
  Map<String, dynamic> days = const {},
}) => {
  'id': id,
  'user_id': _user,
  'week_start': _week,
  'status': status,
  'batch_cooking': true,
  'rules': const [],
  'shopping': shopping,
  'brief': null,
  'conversation_id': null,
  'days': days,
  'day_notes': const {},
  'day_notes_stale': false,
  'created_at': _now.toIso8601String(),
  'updated_at': _now.toIso8601String(),
  'is_deleted': false,
};

Map<String, dynamic> _mealRow({
  required String id,
  String planId = 'plan-1',
  int servings = 4,
  int servingsLeft = 4,
  String mealType = 'dinner',
  int position = 0,
}) => {
  'id': id,
  'plan_id': planId,
  'user_id': _user,
  'source': 'library',
  'library_meal_id': 'D-048',
  'saved_meal_id': null,
  'name': 'Meal $id',
  'meal_type': mealType,
  'session': 'cook-sun',
  'servings': servings,
  'servings_left': servingsLeft,
  'kcal': 500,
  'carbs_g': 60,
  'protein_g': 30,
  'fat_g': 15,
  'swaps_applied': const [],
  'comments': const [],
  'position': position,
  'icon': 'chicken',
  'created_at': _now.toIso8601String(),
  'updated_at': _now.toIso8601String(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingMealPlanRemote remote;
  late MealPlanRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    remote = RecordingMealPlanRemote();
    repo = MealPlanRepository(
      database: db,
      logger: FakeLogger(),
      remote: remote,
    );
  });

  tearDown(() => db.close());

  /// Seed one plan + two meals through the sync path (clean rows).
  Future<void> seed({String status = 'draft'}) async {
    remote.plans = [_planRow(status: status)];
    remote.meals = [
      _mealRow(id: 'pm-1', servings: 4, servingsLeft: 3),
      _mealRow(id: 'pm-2', mealType: 'lunch', position: 1),
    ];
    final result = await repo.syncFromRemote(_user);
    expect(result.success, isTrue, reason: result.error);
    remote.calls.clear();
  }

  Future<PlanMealEntry> mealRow(String id) =>
      (db.select(db.planMealsTable)..where((t) => t.id.equals(id))).getSingle();

  group('syncFromRemote', () {
    test('pulls plans + meals and assembles the active plan', () async {
      await seed();

      final plan = await repo.getActivePlan(_user, _week);
      expect(plan, isNotNull);
      expect(plan!.id, 'plan-1');
      expect(plan.status, MealPlanStatus.draft);
      expect(plan.meals.map((m) => m.id), ['pm-1', 'pm-2']);
      expect(plan.meals.first.session, CookingSession.cookSun);
      expect(plan.meals.first.servingsLeft, 3);
      // Coverage is computed locally (lunch 4 + dinner 4 servings).
      expect(plan.coverage.covered, 8);
      expect((await mealRow('pm-1')).needsUpload, isFalse);
    });

    test('preserves dirty local rows and prunes server-deleted ones', () async {
      await seed();
      await repo.setServings('pm-1', 2); // dirty

      // Server: pm-1 now has 6 servings (should NOT overwrite the dirty
      // local edit), pm-2 was removed server-side (should be pruned).
      remote.meals = [_mealRow(id: 'pm-1', servings: 6, servingsLeft: 6)];
      final result = await repo.syncFromRemote(_user);
      expect(result.success, isTrue);

      final pm1 = await mealRow('pm-1');
      expect(pm1.servings, 2);
      expect(pm1.needsUpload, isTrue);
      final rows = await db.select(db.planMealsTable).get();
      expect(rows.map((r) => r.id), ['pm-1']);
    });

    test(
      'drops a local plan the server no longer lists (archived elsewhere)',
      () async {
        await seed();
        remote.plans = [];
        remote.meals = [];
        await repo.syncFromRemote(_user);
        expect(await repo.getActivePlan(_user, _week), isNull);
      },
    );

    test('returns failed (never throws) when the remote errors', () async {
      remote.failWith = StateError('boom');
      final result = await repo.syncFromRemote(_user);
      expect(result.success, isFalse);
      expect(result.error, contains('boom'));
    });
  });

  group('local-first edits → needs_upload → replay', () {
    test(
      'setServings keeps what was eaten and replays plan_set_servings',
      () async {
        await seed(); // pm-1: 4 servings, 3 left (1 eaten)

        await repo.setServings('pm-1', 2);

        final row = await mealRow('pm-1');
        expect(row.servings, 2);
        expect(row.servingsLeft, 1, reason: '2 - 1 eaten');
        expect(row.needsUpload, isTrue);
        final planRow = await db.select(db.mealPlansTable).getSingle();
        expect(planRow.dayNotesStale, isTrue);

        final upload = await repo.uploadDirtyRecords(_user);
        expect(upload.success, isTrue, reason: upload.error);
        expect(upload.count, 1);
        expect(remote.calls, contains('plan_set_servings:pm-1:2'));
        expect(remote.calls, contains('update_plan_meal:pm-1'));
        expect(remote.updates.single.$2['session'], 'cook-sun');
        expect((await mealRow('pm-1')).needsUpload, isFalse);
      },
    );

    test(
      'removeMeal tombstones locally, replays plan_remove_meal, then drops the row',
      () async {
        await seed();

        await repo.removeMeal('pm-2');

        final row = await mealRow('pm-2');
        expect(row.isDeleted, isTrue);
        expect(row.needsUpload, isTrue);
        // Hidden from the assembled plan immediately.
        final plan = await repo.getActivePlan(_user, _week);
        expect(plan!.meals.map((m) => m.id), ['pm-1']);

        final upload = await repo.uploadDirtyRecords(_user);
        expect(upload.success, isTrue);
        expect(remote.calls, ['plan_remove_meal:pm-2']);
        final rows = await db.select(db.planMealsTable).get();
        expect(rows.map((r) => r.id), ['pm-1']);
      },
    );

    test('setServings(0) is a removal', () async {
      await seed();
      await repo.setServings('pm-1', 0);
      expect((await mealRow('pm-1')).isDeleted, isTrue);
    });

    test('setSession + addComment ride the row update', () async {
      await seed();
      await repo.setSession('pm-1', CookingSession.freshFri);
      await repo.addComment('pm-1', 'less salt');

      final plan = await repo.getActivePlan(_user, _week);
      final meal = plan!.meals.first;
      expect(meal.session, CookingSession.freshFri);
      expect(meal.comments.single.text, 'less salt');

      await repo.uploadDirtyRecords(_user);
      final fields = remote.updates.single.$2;
      expect(fields['session'], 'fresh-fri');
      expect((fields['comments'] as List).single['text'], 'less salt');
    });

    test(
      'toggleShopping flips one item by name and replays a plan update',
      () async {
        remote.plans = [
          _planRow(
            shopping: [
              {
                'aisle': 'Produce',
                'name': 'Spinach',
                'qty': '200 g',
                'checked': false,
                'have': false,
                'fromMealIds': [],
              },
              {
                'aisle': 'Pantry',
                'name': 'Rice',
                'qty': '1 kg',
                'checked': false,
                'have': false,
                'fromMealIds': [],
              },
            ],
          ),
        ];
        await repo.syncFromRemote(_user);
        remote.calls.clear();

        await repo.toggleShopping(
          'plan-1',
          'spinach',
          ShoppingField.have,
          true,
        );

        final plan = await repo.getActivePlan(_user, _week);
        expect(
          plan!.shopping.firstWhere((i) => i.name == 'Spinach').have,
          isTrue,
        );
        expect(plan.shopping.firstWhere((i) => i.name == 'Rice').have, isFalse);

        final upload = await repo.uploadDirtyRecords(_user);
        expect(upload.success, isTrue);
        expect(remote.calls, ['update_plan:plan-1']);
        final shopping = remote.updates.single.$2['shopping'] as List;
        expect(shopping.first['have'], isTrue);
      },
    );

    test('setDaySlot writes and clears a slot in days', () async {
      await seed();
      await repo.setDaySlot(
        'plan-1',
        '2026-09-01',
        MealType.lunch,
        const DaySlotRef(
          source: DaySlotSource.plan,
          id: 'pm-2',
          name: 'Meal pm-2',
        ),
      );
      var plan = await repo.getActivePlan(_user, _week);
      expect(plan!.dayFor('2026-09-01').slotFor(MealType.lunch)?.id, 'pm-2');

      await repo.setDaySlot('plan-1', '2026-09-01', MealType.lunch, null);
      plan = await repo.getActivePlan(_user, _week);
      expect(plan!.dayFor('2026-09-01').slotFor(MealType.lunch), isNull);

      await repo.uploadDirtyRecords(_user);
      expect(remote.calls, ['update_plan:plan-1']);
      expect(remote.updates.single.$2['days'], {'2026-09-01': {}});
    });

    test('upload failure leaves rows dirty and reports failed()', () async {
      await seed();
      await repo.setServings('pm-1', 2);
      remote.failWith = StateError('offline');

      final upload = await repo.uploadDirtyRecords(_user);
      expect(upload.success, isFalse);
      expect((await mealRow('pm-1')).needsUpload, isTrue);
    });

    test('nothing dirty → nothingToUpload', () async {
      await seed();
      final upload = await repo.uploadDirtyRecords(_user);
      expect(upload.success, isTrue);
      expect(upload.count, 0);
      expect(remote.calls, isEmpty);
    });
  });

  group('applyServerPlan', () {
    test(
      'writes the batch fixture as clean rows and re-reads it identically',
      () async {
        final fixture = loadFixture('batch');
        final part =
            VanaPart.fromJson(
                  (fixture['parts'] as List).first as Map<String, dynamic>,
                )!
                as VanaBatchPart;

        await repo.applyServerPlan(part.plan, userId: _user);

        final plan = await repo.getPlanById(part.plan.id);
        expect(plan, isNotNull);
        expect(plan!.meals.length, part.plan.meals.length);
        expect(plan.meals.map((m) => m.id), part.plan.meals.map((m) => m.id));
        expect(plan.conversationId, part.plan.conversationId);
        expect(plan.batchCooking, part.plan.batchCooking);
        // Coverage recomputed locally matches what the server sent.
        expect(plan.coverage, part.plan.coverage);
        // Meals mirror the wire (round-trip through Drift loses nothing).
        for (var i = 0; i < plan.meals.length; i++) {
          expect(plan.meals[i], part.plan.meals[i]);
        }
        final rows = await db.select(db.planMealsTable).get();
        expect(rows.every((r) => r.needsUpload == false), isTrue);
      },
    );

    test(
      'drops meals the server no longer lists and archives siblings on confirm',
      () async {
        await seed();
        // A second draft for the same week (another conversation).
        await db
            .into(db.mealPlansTable)
            .insert(
              MealPlansTableCompanion.insert(
                id: const Value('plan-2'),
                userId: _user,
                weekStart: _week,
                createdAt: _now,
                updatedAt: _now,
              ),
            );

        final fixture = loadFixture('confirm_plan');
        final part =
            VanaPart.fromJson(
                  (fixture['parts'] as List).first as Map<String, dynamic>,
                )!
                as VanaBatchPart;
        // Retarget the fixture onto our seeded plan id so pruning applies.
        final confirmed = part.plan.copyWith(
          id: 'plan-1',
          weekStart: _week,
          meals: [
            for (final m in part.plan.meals.take(1))
              m.copyWith(planId: 'plan-1'),
          ],
          recomputeCoverage: true,
        );

        await repo.applyServerPlan(confirmed, userId: _user);

        final active = await repo.getActivePlan(_user, _week);
        expect(active!.id, 'plan-1');
        expect(active.status, MealPlanStatus.confirmed);
        expect(active.meals.length, 1);
        expect(active.meals.single.id, confirmed.meals.single.id);
        // Seeded pm-1 / pm-2 are gone (not in the server payload).
        final rows = await db.select(db.planMealsTable).get();
        expect(rows.map((r) => r.id), [confirmed.meals.single.id]);
        // The sibling draft was archived.
        final sibling = await (db.select(
          db.mealPlansTable,
        )..where((t) => t.id.equals('plan-2'))).getSingle();
        expect(sibling.status, 'archived');
      },
    );
  });

  group('watchActivePlan', () {
    test('a confirmed plan wins over a newer draft', () async {
      remote.plans = [
        _planRow(id: 'draft', status: 'draft'),
        _planRow(id: 'conf', status: 'confirmed'),
      ];
      remote.meals = [];
      await repo.syncFromRemote(_user);
      final plan = await repo.getActivePlan(_user, _week);
      expect(plan!.id, 'conf');
    });

    test('re-emits after a local edit', () async {
      await seed();
      final emissions = <int>[];
      final sub = repo.watchActivePlan(_user, _week).listen((p) {
        emissions.add(p?.meals.length ?? -1);
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await repo.removeMeal('pm-2');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions.first, 2);
      expect(emissions.last, 1);
    });
  });
}

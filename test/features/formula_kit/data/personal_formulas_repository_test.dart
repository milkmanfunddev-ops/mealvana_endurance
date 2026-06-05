import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/data/personal_formulas_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// PR 5a verification — lock in the offline-first guarantees for personal
// formulas (the "Make this mine" save), mirroring the formula_pins suite:
//
//   - save(): local-first write flagged needs_upload=true; getForUser reads it.
//   - save() with an existing id updates in place (re-save after edit).
//   - deleteFormula(): soft delete (is_deleted=true + dirty), never a DELETE.
//   - dirty-preserve: a remote sync must not clobber a row the user just edited.
//   - phase filtering + user scoping on reads.
//   - forward-compat: a row with an unknown phase decodes to null and is skipped.
//
// Full syncFromRemote / uploadDirtyRecords tests are omitted for the same
// reason as the rest of test/new_sync/ — mocking the SupabaseQueryBuilder chain
// isn't worth the brittleness. The merge path is exposed via @visibleForTesting
// on upsertRemotePreservingDirty so we drive it directly.

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late MockSupabaseClient mockSupabase;
  late MockAppLogger mockLogger;
  late MockSentryReporter mockSentry;
  late PersonalFormulasRepository repository;

  const testUserId = 'user-abc';
  const otherUserId = 'user-xyz';

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockSupabase = MockSupabaseClient();
    mockLogger = MockAppLogger();
    mockSentry = MockSentryReporter();

    when(() => mockLogger.info(
          any(),
          context: any(named: 'context'),
          data: any(named: 'data'),
        )).thenReturn(null);
    when(() => mockLogger.debug(
          any(),
          context: any(named: 'context'),
          data: any(named: 'data'),
        )).thenReturn(null);
    when(() => mockLogger.warning(
          any(),
          context: any(named: 'context'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          data: any(named: 'data'),
        )).thenReturn(null);
    when(() => mockLogger.error(
          any(),
          context: any(named: 'context'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          data: any(named: 'data'),
        )).thenReturn(null);

    // save()/deleteFormula() fire-and-forget the upload. The mock client throws
    // on any unstubbed call → rejected future inside the unawaited lambda,
    // caught by the repo. Stub the sentry callback so that path doesn't blow up.
    when(() => mockSentry.reportNetworkError(
          any(),
          url: any(named: 'url'),
          method: any(named: 'method'),
          stackTrace: any(named: 'stackTrace'),
        )).thenAnswer((_) async {});

    repository = PersonalFormulasRepository(
      supabase: mockSupabase,
      database: database,
      logger: mockLogger,
      sentry: mockSentry,
    );
  });

  tearDown(() async {
    // Drain the fire-and-forget upload futures so they don't leak into the
    // next test's setUp (where `database` has been replaced).
    await Future<void>.delayed(Duration.zero);
    await database.close();
  });

  PersonalFormula formula({
    String id = 'pf-1',
    String userId = testUserId,
    FormulaPhase phase = FormulaPhase.before,
    String name = 'My Snack',
    double carbs = 36,
  }) {
    final now = DateTime.utc(2026, 6, 1, 12);
    return PersonalFormula(
      id: id,
      userId: userId,
      name: name,
      phase: phase,
      sourceTemplateId: 'tpl-1',
      components: const [
        PersonalFormulaComponent(
          foodKey: 'medjool_dates',
          quantity: 2,
          carbsPerServing: 18,
          proteinPerServing: 0.4,
          fatPerServing: 0.1,
          sodiumMgPerServing: 0,
          fluidMlPerServing: 0,
        ),
      ],
      totalCarbsG: carbs,
      totalProteinG: 0.8,
      totalFatG: 0.2,
      totalSodiumMg: 0,
      totalFluidMl: 0,
      totalCalories: 149,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> remotePayload({
    required String id,
    String userId = testUserId,
    String phase = 'before',
    bool isDeleted = false,
    DateTime? updatedAt,
    double carbs = 50,
  }) {
    final now = DateTime.now();
    return {
      'id': id,
      'user_id': userId,
      'name': 'Remote Formula',
      'phase': phase,
      'source_template_id': 'tpl-remote',
      'sub_phase': 'snack',
      'digestion_speed': 'fast',
      'template_type': 'food',
      'activity_types': null,
      'duration_brackets': null,
      'gut_training_levels': null,
      'components': const [],
      'total_carbs_g': carbs,
      'total_protein_g': 0,
      'total_fat_g': 0,
      'total_sodium_mg': 0,
      'total_fluid_ml': 0,
      'total_calories': 200,
      'created_at': now.toUtc().toIso8601String(),
      'updated_at': (updatedAt ?? now).toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  group('save()', () {
    test('persists locally with needs_upload=true and is readable via getForUser',
        () async {
      final saved = await repository.save(formula());

      final rows = await (database.select(database.personalFormulasTable)).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'pf-1');
      expect(rows.single.needsUpload, isTrue,
          reason: 'fresh local write must be dirty until the upload pass runs');
      expect(rows.single.isDeleted, isFalse);

      final read = await repository.getForUser(testUserId);
      expect(read, hasLength(1));
      expect(read.single.id, saved.id);
      expect(read.single.name, 'My Snack');
      // Component JSON survives the Drift round-trip.
      expect(read.single.components.single.foodKey, 'medjool_dates');
      expect(read.single.components.single.quantity, 2);
      expect(read.single.totalCalories, 149);
    });

    test('re-saving the same id updates in place (no duplicate row)', () async {
      await repository.save(formula(name: 'Original', carbs: 36));
      await repository.save(formula(name: 'Edited', carbs: 48));

      final rows = await (database.select(database.personalFormulasTable)).get();
      expect(rows, hasLength(1), reason: 'same id must upsert, not duplicate');

      final read = await repository.getForUser(testUserId);
      expect(read.single.name, 'Edited');
      expect(read.single.totalCarbsG, 48);
    });
  });

  group('deleteFormula()', () {
    test('soft-deletes (is_deleted=true + dirty) and hides from getForUser',
        () async {
      await repository.save(formula());

      await repository.deleteFormula(userId: testUserId, id: 'pf-1');

      final rows = await (database.select(database.personalFormulasTable)).get();
      expect(rows, hasLength(1),
          reason: 'soft delete must keep the physical row for sync');
      expect(rows.single.isDeleted, isTrue);
      expect(rows.single.needsUpload, isTrue,
          reason: 'tombstone must upload so other devices learn of the delete');

      final read = await repository.getForUser(testUserId);
      expect(read, isEmpty);
    });

    test('no-op when no active row exists for the id', () async {
      await repository.deleteFormula(userId: testUserId, id: 'missing');
      final rows = await (database.select(database.personalFormulasTable)).get();
      expect(rows, isEmpty);
    });
  });

  group('getForUser()', () {
    test('scopes to the user and filters by phase', () async {
      await repository.save(formula(id: 'mine-before'));
      await repository.save(
          formula(id: 'mine-during', phase: FormulaPhase.during));
      await repository.save(formula(id: 'theirs', userId: otherUserId));

      final mine = await repository.getForUser(testUserId);
      expect(mine.map((f) => f.id), containsAll(['mine-before', 'mine-during']));
      expect(mine, hasLength(2), reason: 'other users must not leak in');

      final mineBefore =
          await repository.getForUser(testUserId, phase: FormulaPhase.before);
      expect(mineBefore.map((f) => f.id), ['mine-before']);
    });

    test('skips rows with an unrecognized phase (forward-compat)', () async {
      // A newer client could write a phase value this binary doesn't know.
      // It must be skipped, not crash the whole read.
      await database.into(database.personalFormulasTable).insert(
            PersonalFormulasTableCompanion.insert(
              id: const Value('pf-future'),
              userId: testUserId,
              name: 'From the future',
              phase: 'galaxy', // unknown
              createdAt: DateTime.utc(2026, 6, 1),
              updatedAt: DateTime.utc(2026, 6, 1),
            ),
          );
      await repository.save(formula(id: 'pf-known'));

      final read = await repository.getForUser(testUserId);
      expect(read.map((f) => f.id), ['pf-known']);
    });
  });

  group('upsertRemotePreservingDirty — dirty-preserve', () {
    test('skips remote overwrite when local row has needs_upload=true',
        () async {
      // User edited & saved locally while offline (dirty).
      await repository.save(formula(name: 'Local Edit', carbs: 99));

      // Server pushes a conflicting/stale version of the same id.
      final upserted = await repository.upsertRemotePreservingDirty([
        remotePayload(id: 'pf-1', carbs: 12, updatedAt: DateTime.utc(2026, 5)),
      ]);

      expect(upserted, 0, reason: 'dirty row must not be overwritten');

      final read = await repository.getForUser(testUserId);
      expect(read.single.name, 'Local Edit');
      expect(read.single.totalCarbsG, 99);
      final rows = await (database.select(database.personalFormulasTable)).get();
      expect(rows.single.needsUpload, isTrue);
    });

    test('applies remote rows that are not locally dirty', () async {
      final upserted = await repository.upsertRemotePreservingDirty([
        remotePayload(id: 'pf-remote', carbs: 77),
      ]);
      expect(upserted, 1);

      final read = await repository.getForUser(testUserId);
      expect(read.single.id, 'pf-remote');
      expect(read.single.totalCarbsG, 77);
      final rows = await (database.select(database.personalFormulasTable)).get();
      expect(rows.single.needsUpload, isFalse,
          reason: 'row came from remote — already in sync');
    });

    test('remote tombstone hides a clean local row from reads', () async {
      await repository.upsertRemotePreservingDirty([
        remotePayload(id: 'pf-shared'),
      ]);
      expect(await repository.getForUser(testUserId), hasLength(1));

      // Delete flows down from another device.
      await repository.upsertRemotePreservingDirty([
        remotePayload(
          id: 'pf-shared',
          isDeleted: true,
          updatedAt: DateTime.now().add(const Duration(minutes: 1)),
        ),
      ]);

      final rows = await (database.select(database.personalFormulasTable)).get();
      expect(rows, hasLength(1), reason: 'physical row stays for sync');
      expect(rows.single.isDeleted, isTrue);
      expect(await repository.getForUser(testUserId), isEmpty);
    });
  });
}

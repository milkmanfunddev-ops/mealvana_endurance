import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/data/personal_formulas_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_pin.dart'
    show TemplateKind;
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Data-foundation tests for personal_formulas. Mirrors the structure of
// formula_pins_repository_test: locks the offline-first invariants that fall
// out of the repository before any edit UI (PR 4) starts writing rows.
//
//   - domain round-trip: Supabase JSON ↔ PersonalFormula ↔ Drift companion,
//     including forked vs from-scratch + JSON list/components handling.
//   - dirty-preserve: an active sync must not clobber a locally-dirty row.
//   - soft-delete: delete() flips is_deleted (no physical DELETE) and hides
//     the row from active reads.
//   - forward-compat: rows with unknown provenance/phase are skipped, not
//     crashed on.
//
// Full syncFromRemote / upload network paths are omitted (same reasoning as
// the pins test) — the merge path is driven directly via the
// @visibleForTesting upsertRemoteFormulasPreservingDirty.

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

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(SentryLevel.warning);
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockSupabase = MockSupabaseClient();
    mockLogger = MockAppLogger();
    mockSentry = MockSentryReporter();

    when(
      () => mockLogger.info(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogger.debug(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogger.warning(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => mockLogger.error(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => mockSentry.reportNetworkError(
        any(),
        url: any(named: 'url'),
        method: any(named: 'method'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSentry.captureMessage(
        any(),
        level: any(named: 'level'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((_) async {});

    repository = PersonalFormulasRepository(
      supabase: mockSupabase,
      database: database,
      logger: mockLogger,
      sentry: mockSentry,
    );
  });

  tearDown(() async {
    // Drain fire-and-forget upload futures before the next setUp swaps the db.
    await Future<void>.delayed(Duration.zero);
    await database.close();
  });

  Map<String, dynamic> remotePayload({
    required String id,
    String userId = testUserId,
    String provenance = 'from_scratch_formula',
    String phase = 'before',
    String? sourceTemplateId,
    String? sourceTemplateKind,
    List<String>? activities,
    List<Map<String, dynamic>> components = const [],
    DateTime? updatedAt,
    bool isDeleted = false,
  }) {
    final now = DateTime.now();
    return {
      'id': id,
      'user_id': userId,
      'name': 'Test Formula $id',
      'provenance': provenance,
      'phase': phase,
      'source_template_id': sourceTemplateId,
      'source_template_kind': sourceTemplateKind,
      'sub_phase': null,
      'digest_speed': null,
      'activities': activities,
      'durations': null,
      'gut_training': null,
      'travel_friendliness': null,
      'components': components,
      'notes': null,
      'total_carbs_g': 60,
      'total_protein_g': null,
      'total_fat_g': null,
      'total_sodium_mg': null,
      'total_fluids_ml': null,
      'total_calories': null,
      'created_at': now.toUtc().toIso8601String(),
      'updated_at': (updatedAt ?? now).toUtc().toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  group('domain round-trip', () {
    test('Supabase JSON → domain → Drift companion → domain preserves a '
        'forked formula with components + activities', () async {
      final json = remotePayload(
        id: 'f1',
        provenance: 'forked_formula',
        phase: 'during',
        sourceTemplateId: 'tpl-xyz',
        sourceTemplateKind: 'during_system',
        activities: ['cycling', 'running'],
        components: [
          {'food_name': 'gel', 'quantity': 2, 'unit': 'packet'},
          {'food_name': 'water', 'quantity': 500, 'unit': 'ml'},
        ],
      );

      final decoded = PersonalFormula.fromSupabaseJson(json)!;
      expect(decoded.provenance, FormulaProvenance.forkedFormula);
      expect(decoded.phase, FormulaPhase.during);
      expect(decoded.sourceTemplateKind, TemplateKind.duringSystem);
      expect(decoded.activities, ['cycling', 'running']);
      expect(decoded.components.length, 2);
      expect(decoded.components.first['food_name'], 'gel');

      // Round-trip through Drift.
      await database
          .into(database.personalFormulasTable)
          .insert(decoded.toDriftCompanion());
      final fromDb = await repository.getById('f1');
      expect(fromDb, isNotNull);
      expect(fromDb!.activities, ['cycling', 'running']);
      expect(fromDb.components.length, 2);
      expect(fromDb.sourceTemplateId, 'tpl-xyz');
      expect(fromDb.phase, FormulaPhase.during);
    });

    test('unknown provenance/phase decodes to null (forward-compat)', () {
      expect(
        PersonalFormula.fromSupabaseJson(
          remotePayload(id: 'x', provenance: 'future_kind'),
        ),
        isNull,
      );
      expect(
        PersonalFormula.fromSupabaseJson(
          remotePayload(id: 'x', phase: 'mid_run'),
        ),
        isNull,
      );
    });
  });

  group('upsertRemoteFormulasPreservingDirty', () {
    test(
      'dirty-preserve: skips remote overwrite for needs_upload=true rows',
      () async {
        // Seed a locally-dirty row (user edited offline).
        await database
            .into(database.personalFormulasTable)
            .insert(
              PersonalFormulasTableCompanion.insert(
                id: const Value('f1'),
                userId: testUserId,
                name: 'Local Edit',
                provenance: 'from_scratch_formula',
                phase: 'before',
                createdAt: DateTime.utc(2026, 5, 21, 10),
                updatedAt: DateTime.utc(2026, 5, 21, 10),
                needsUpload: const Value(true),
              ),
            );

        final applied = await repository.upsertRemoteFormulasPreservingDirty([
          remotePayload(id: 'f1'),
        ]);

        expect(applied, 0, reason: 'dirty row should be skipped');
        final row = await repository.getById('f1');
        expect(row!.name, 'Local Edit', reason: 'local edit preserved');
      },
    );

    test('applies clean remote rows and skips unparseable ones', () async {
      final applied = await repository.upsertRemoteFormulasPreservingDirty([
        remotePayload(id: 'good'),
        remotePayload(id: 'bad', provenance: 'future_kind'),
      ]);

      expect(applied, 1);
      expect(await repository.getById('good'), isNotNull);
      expect(await repository.getById('bad'), isNull);
    });

    test(
      'tombstone propagation: is_deleted row hides from active reads',
      () async {
        await repository.upsertRemoteFormulasPreservingDirty([
          remotePayload(id: 'gone', isDeleted: true),
        ]);
        expect(await repository.getById('gone'), isNull);
        expect(await repository.getFormulasForUser(testUserId), isEmpty);
      },
    );
  });

  group('mutations', () {
    test('create persists active + dirty and getActiveCount sees it', () async {
      final now = DateTime.now();
      await repository.create(
        PersonalFormula(
          id: '',
          userId: testUserId,
          name: 'From Scratch',
          provenance: FormulaProvenance.fromScratchFormula,
          phase: FormulaPhase.before,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(await repository.getActiveCount(testUserId), 1);
      expect(
        await repository.getActiveCount(testUserId, phase: FormulaPhase.during),
        0,
      );
    });

    test(
      'delete soft-deletes: row hidden from reads but tombstone remains',
      () async {
        final now = DateTime.now();
        final created = await repository.create(
          PersonalFormula(
            id: '',
            userId: testUserId,
            name: 'Doomed',
            provenance: FormulaProvenance.fromScratchFormula,
            phase: FormulaPhase.after,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repository.delete(id: created.id, userId: testUserId);

        expect(await repository.getById(created.id), isNull);
        expect(await repository.getActiveCount(testUserId), 0);

        // Physical row still present (tombstone for sync).
        final raw = await (database.select(
          database.personalFormulasTable,
        )..where((t) => t.id.equals(created.id))).getSingleOrNull();
        expect(raw, isNotNull);
        expect(raw!.isDeleted, isTrue);
        expect(raw.needsUpload, isTrue);
      },
    );
  });
}

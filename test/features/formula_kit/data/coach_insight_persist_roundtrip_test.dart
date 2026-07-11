import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/data/personal_formulas_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Regression test for bug 382e3fdb: "Formula Kit 'Coach AI insight' does not
// persist, erased on return."
//
// Root cause (commit bad0d49a): the coach insight lived only in an
// auto-disposing Riverpod provider. Navigating away and back to the formula
// editor rebuilt the provider from scratch with no source of truth to
// rehydrate from, so the insight vanished. The fix added
// `coachInsightText`/`coachInsightMarker` columns to the Drift table (with a
// schemaVersion bump) plus `PersonalFormulasRepository.persistInsight()`, and
// made `CoachInsightController.build()` hydrate from `repo.getById()`.
//
// This test drives the exact round trip `CoachInsightController` performs:
// persist an insight via the repository (what `generate()` does), then read
// the formula back via a *fresh* `getById()` call (what `build()` does on
// provider rebuild/navigation-return) and assert the insight survived.
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late PersonalFormulasRepository repository;

  const testUserId = 'user-abc';

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(SentryLevel.warning);
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final mockSupabase = MockSupabaseClient();
    final mockLogger = MockAppLogger();
    final mockSentry = MockSentryReporter();

    when(() => mockLogger.info(
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
    when(() => mockSentry.reportNetworkError(
          any(),
          url: any(named: 'url'),
          method: any(named: 'method'),
          stackTrace: any(named: 'stackTrace'),
        )).thenAnswer((_) async {});
    when(() => mockSentry.captureMessage(
          any(),
          level: any(named: 'level'),
          tags: any(named: 'tags'),
        )).thenAnswer((_) async {});

    repository = PersonalFormulasRepository(
      supabase: mockSupabase,
      database: database,
      logger: mockLogger,
      sentry: mockSentry,
    );
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    await database.close();
  });

  test(
      'insight persisted via persistInsight() survives a fresh getById() '
      'read (simulated navigate-away-and-back)', () async {
    final now = DateTime.now();
    final formula = await repository.create(
      PersonalFormula(
        id: '',
        userId: testUserId,
        name: 'Pre-Run Oats',
        provenance: FormulaProvenance.fromScratchFormula,
        phase: FormulaPhase.before,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Simulate what CoachInsightController.generate() does after a
    // successful AI fetch.
    await repository.persistInsight(
      formulaId: formula.id,
      insightText: 'Add more sodium for hot-weather runs.',
      marker: 'marker-abc123',
    );

    // Simulate provider rebuild on navigating back to the editor: a brand
    // new read from the DB, exactly what CoachInsightController.build()
    // does via repo.getById(formulaId).
    final rehydrated = await repository.getById(formula.id);

    expect(rehydrated, isNotNull);
    expect(rehydrated!.coachInsightText, 'Add more sodium for hot-weather runs.');
    expect(rehydrated.coachInsightMarker, 'marker-abc123');
  });

  test('formula with no insight yet still hydrates as null (no crash)',
      () async {
    final now = DateTime.now();
    final formula = await repository.create(
      PersonalFormula(
        id: '',
        userId: testUserId,
        name: 'No Insight Yet',
        provenance: FormulaProvenance.fromScratchFormula,
        phase: FormulaPhase.before,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final rehydrated = await repository.getById(formula.id);
    expect(rehydrated, isNotNull);
    expect(rehydrated!.coachInsightText, isNull);
    expect(rehydrated.coachInsightMarker, isNull);
  });
}

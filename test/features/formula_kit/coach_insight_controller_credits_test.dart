// CoachInsightController.generate refreshes the credit balance after a model
// answer or a 402, and not after a free rules answer (round develop-2026-10,
// ticket 23: 02-001).
//
// The write path runs for real: CoachInsightController, AiCoachClient (real
// Functions client over an HTTP seam answering with ai-coach's bodies) and
// PersonalFormulasRepository on an in-memory Drift database. Only the credits
// controller is a counting fake, standing in for the pill's source.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';
import 'package:mealvana_endurance/features/formula_kit/application/coach_insight_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/data/ai_coach_client.dart';
import 'package:mealvana_endurance/features/formula_kit/data/personal_formulas_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/coach_insight.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';

class _MockUser extends Mock implements User {}

class _CountingCredits extends CreditsController {
  int refreshes = 0;

  @override
  FutureOr<CreditWallet> build() => const CreditWallet(balance: 1);

  @override
  Future<void> refresh() async => refreshes++;
}

const _userId = '4a74be96-fce8-4894-a82c-2a77199d601d';

Map<String, dynamic> _answer(String source) => {
  'insight': source == 'model'
      ? 'Solid carb base for a long run; add a pinch of salt for the heat.'
      : 'You are short on carbs for this run; add a banana or a gel.',
  'stale_marker': 'ignored-client-keeps-its-own',
  'usage': source == 'model'
      ? {
          'input_tokens': 640,
          'output_tokens': 41,
          'model': 'anthropic/claude-haiku-4.5',
          'cost_usd': 0.000845,
          'source': 'model',
        }
      : {
          'input_tokens': 0,
          'output_tokens': 0,
          'model': 'rules/pre-workout-v1',
          'cost_usd': 0,
          'source': 'rules',
        },
};

const _producer402 = {
  'error': 'insufficient_credits',
  'message': 'You are out of AI credits. Purchase more to continue.',
  'balance': 0,
  'cost': 1,
};

const _context = CoachInsightContext(
  phase: FormulaPhase.before,
  components: [
    {'food_name': 'Banana', 'quantity': 1, 'carbs_per_serving': 27},
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late PersonalFormulasRepository repo;
  late _CountingCredits credits;
  late int status;
  late Object body;
  late String formulaId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    final report = RecordingReport();
    repo = PersonalFormulasRepository(
      supabase: fakeSupabaseClient(),
      database: db,
      report: report,
    );
    final now = DateTime.now();
    formulaId = (await repo.create(
      PersonalFormula(
        id: '',
        userId: _userId,
        name: 'Pre-Run Oats',
        provenance: FormulaProvenance.fromScratchFormula,
        phase: FormulaPhase.before,
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
    credits = _CountingCredits();
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    await db.close();
  });

  ProviderContainer container() {
    final real = SupabaseClient(
      'http://fake-supabase.local',
      'anon-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(real.dispose);
    final goTrue = fakeGoTrueClient();
    final user = _MockUser();
    when(() => user.id).thenReturn(_userId);
    when(() => goTrue.currentUser).thenReturn(user);
    final client = fakeSupabaseClient(auth: goTrue) as MockSupabaseClient;
    when(() => client.functions).thenReturn(real.functions);

    final c = ProviderContainer(
      overrides: [
        mockAppExternalDeps(),
        reportProvider.overrideWithValue(RecordingReport()),
        aiCoachClientProvider.overrideWithValue(
          AiCoachClient(supabase: client, report: RecordingReport()),
        ),
        personalFormulasRepositoryProvider.overrideWithValue(repo),
        creditsControllerProvider.overrideWith(() => credits),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<AsyncValue<CoachInsight?>> generate(ProviderContainer c) async {
    final provider = coachInsightControllerProvider(formulaId);
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await c.read(provider.future);
    await c.read(provider.notifier).generate(_context);
    return c.read(provider);
  }

  test('a model answer persists the insight and refreshes credits', () async {
    status = 200;
    body = _answer('model');
    final c = container();

    final state = await generate(c);

    expect(state.value?.generationSource, 'model');
    final saved = await repo.getById(formulaId);
    expect(saved?.coachInsightText, startsWith('Solid carb base'));
    expect(credits.refreshes, 1);
  });

  test('a rules answer costs nothing and refreshes nothing', () async {
    status = 200;
    body = _answer('rules');
    final c = container();

    final state = await generate(c);

    expect(state.value?.generationSource, 'rules');
    expect(credits.refreshes, 0);
  });

  test(
    'a 402 leaves AsyncError(InsufficientCreditsException) and refreshes',
    () async {
      status = 402;
      body = _producer402;
      final c = container();

      final state = await generate(c);

      expect(state.error, isA<InsufficientCreditsException>());
      expect(credits.refreshes, 1);
    },
  );
}

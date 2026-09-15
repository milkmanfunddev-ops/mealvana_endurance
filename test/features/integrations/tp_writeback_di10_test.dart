/// DI-10 — TP write-back invariants (TP-5 / Q-INT16 as AMENDED 2026-09-11).
///
///  * No TP push without a ledger row: when the ledger custodian is
///    unavailable the push is REFUSED — the TP API is never called.
///  * Sharing defaults ON for everyone (opt-out): the pref default is the
///    ratified intent, made explicit in storage without ever overwriting a
///    stored choice.
///  * Notice-once semantics: the opt-out notice flag fires exactly once.
///  * The ruled macro register: Pre + During only (no Post), During carries
///    carbs g/h, water ml/h, sodium mg/h; the fuel-block strip can never
///    swallow the feedback block (delimiter lookahead).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/tp_writeback_formatter.dart';
import 'package:mealvana_endurance/features/integrations/application/tp_writeback_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/fuel_log_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    hide Activity;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTpApiClient extends Mock implements TrainingPeaksApiClient {}

class MockTpOAuthService extends Mock implements TrainingPeaksOAuthService {}

void main() {
  group('ledger-gated push (TP-5: no push without a ledger row)', () {
    test('with no ledger custodian the TP API is never called', () async {
      final api = MockTpApiClient();
      final oauth = MockTpOAuthService();
      when(
        () => oauth.getValidAccessToken(any()),
      ).thenAnswer((_) async => 'tok');
      SharedPreferences.setMockInitialValues({});
      final prefs = PreferencesService(await SharedPreferences.getInstance());
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final service = TpWritebackService(
        apiClient: api,
        oauthService: oauth,
        preferencesService: prefs,
        database: db,
        supabase: null, // the ledger custodian is unavailable
      );

      final activity = Activity(
        id: 'a1',
        userId: 'u1',
        activityType: ActivityType.running,
        title: 'TP run',
        scheduledDateTime: DateTime(2026, 9, 12, 7),
        syncedFromProvider: 'training_peaks',
        providerWorkoutId: '12345',
        durationMinutes: 60,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      final plan = NutritionPlan(
        id: 'p1',
        name: 'Plan',
        sections: [
          PlanSection(
            id: 'before',
            title: 'Before',
            foodItems: const [],
            carbsTarget: 60,
            fluidsTarget: 500,
          ),
        ],
      );

      await service.pushPlanToWorkout(
        userId: 'u1',
        activity: activity,
        plan: plan,
      );

      // The push was REFUSED before any TP traffic.
      verifyNever(
        () => api.getWorkoutById(
          any(),
          any(),
          includeDescription: any(named: 'includeDescription'),
        ),
      );
      verifyNever(
        () => api.updatePlannedWorkout(
          any(),
          workoutId: any(named: 'workoutId'),
          workoutData: any(named: 'workoutData'),
        ),
      );
    });
  });

  group('opt-out default (Q-INT16 AMENDED 2026-09-11)', () {
    test('sharing defaults ON and the explicit default never overwrites a '
        'stored choice', () async {
      SharedPreferences.setMockInitialValues({});
      var prefs = PreferencesService(await SharedPreferences.getInstance());

      // Default ON — the ratified intent, not an accident.
      expect(prefs.tpWritebackEnabled, isTrue);

      // Making it explicit stores true...
      await prefs.ensureTpWritebackDefaultExplicit();
      expect(prefs.tpWritebackEnabled, isTrue);

      // ...but a stored OFF choice survives the ensure call.
      await prefs.setTpWritebackEnabled(false);
      await prefs.ensureTpWritebackDefaultExplicit();
      expect(prefs.tpWritebackEnabled, isFalse);

      // And a fresh install with a pre-stored choice is never flipped.
      SharedPreferences.setMockInitialValues({'tp_writeback_enabled': false});
      prefs = PreferencesService(await SharedPreferences.getInstance());
      await prefs.ensureTpWritebackDefaultExplicit();
      expect(prefs.tpWritebackEnabled, isFalse);
    });

    test('notice-once: the flag latches after the first show', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PreferencesService(await SharedPreferences.getInstance());
      expect(prefs.tpWritebackNoticeShown, isFalse);
      await prefs.setTpWritebackNoticeShown(true);
      expect(prefs.tpWritebackNoticeShown, isTrue);
    });
  });

  group('the ruled macro register + delimiter robustness', () {
    NutritionPlan plan() => NutritionPlan(
      id: 'p1',
      name: 'Plan',
      sections: [
        PlanSection(
          id: 'before',
          title: 'Before',
          foodItems: const [],
          carbsTarget: 60,
          fluidsTarget: 473, // ~16 oz
          timing: '2-3h before',
        ),
        PlanSection(
          id: 'during',
          title: 'During',
          foodItems: const [],
          carbsTarget: 120,
          fluidsTarget: 1000,
          sodiumTarget: 800,
        ),
        PlanSection(
          id: 'after',
          title: 'After',
          foodItems: const [],
          carbsTarget: 40,
          proteinTarget: 25,
        ),
      ],
    );

    test('Pre + During ONLY; During carries g/h, ml/h, mg/h', () {
      final block = TpWritebackFormatter.formatPlanBlock(
        plan(),
        durationMinutes: 120,
      );
      expect(block, contains('Pre: 60g carb, 16oz water (2-3h before)'));
      expect(
        block,
        contains('During: 60g/h carb, 500ml/h water, 400mg/h sodium'),
      );
      expect(
        block,
        isNot(contains('Post:')),
        reason: 'the Post line was struck by the ruled register',
      );
    });

    test('stripping the fuel block can never swallow the feedback block', () {
      const feedback =
          '---\n[Mealvana Feedback]\nRating: 4/5\n'
          'Notes: athlete notes that must survive\n[/Mealvana Feedback]';
      // A truncated fuel block (its own terminator lost) sitting before the
      // feedback block — the ruled lookahead keeps the strip from running
      // through the feedback terminator.
      const desc =
          'Coach notes.\n\n---\n[Mealvana Fuel Plan]\n'
          'Pre: 60g carb\n\n$feedback';
      final stripped = TpWritebackFormatter.stripBlockFromDescription(desc);
      expect(stripped, contains('athlete notes that must survive'));
      expect(stripped, contains('[Mealvana Feedback]'));
    });
  });

  group(
    'logged fuel block — planned · consumed (RULED Xuan 2026-09-10 opt A)',
    () {
      NutritionPlan plan() => NutritionPlan(
        id: 'p1',
        name: 'Plan',
        sections: [
          PlanSection(
            id: 'before',
            title: 'Before',
            foodItems: const [],
            carbsTarget: 60,
            fluidsTarget: 473, // ~16 oz
            timing: '2-3h before',
          ),
          PlanSection(
            id: 'during',
            title: 'During',
            foodItems: const [],
            carbsTarget: 120,
            fluidsTarget: 1000,
            sodiumTarget: 800,
          ),
        ],
      );

      // Consumed side: one logged item per phase, quantities 1:1 with their
      // captured nutrition so actualNutritionalInfo == nutritionalInfo. Before
      // consumed = 45g carb / 355ml (→12oz); During consumed totals over the
      // 2h window = 90g carb (45g/h), 820ml (410ml/h), 676mg sodium (338mg/h).
      FuelLogData fuelLog() => FuelLogData(
        items: [
          FuelLogItem(
            foodId: 'b1',
            sectionId: 'before_run',
            plannedQuantity: 1,
            actualQuantity: 1,
            name: 'Toast',
            nutritionalInfo: const NutritionalInfo(carbs: 45, fluids: 355),
          ),
          FuelLogItem(
            foodId: 'd1',
            sectionId: 'during_run',
            plannedQuantity: 1,
            actualQuantity: 1,
            name: 'Gel + drink',
            nutritionalInfo: const NutritionalInfo(
              carbs: 90,
              sodium: 676,
              fluids: 820,
            ),
          ),
        ],
      );

      test('Pre + During each render planned · consumed per field', () {
        final block = TpWritebackFormatter.formatLoggedPlanBlock(
          plan(),
          fuelLog(),
          durationMinutes: 120,
        );
        expect(
          block,
          contains(
            'Pre: 60g carb planned · 45g consumed, '
            '16oz water planned · 12oz consumed (2-3h before)',
          ),
        );
        expect(
          block,
          contains(
            'During: 60g/h carb planned · 45g/h consumed, '
            '500ml/h water planned · 410ml/h consumed, '
            '400mg/h sodium planned · 338mg/h consumed',
          ),
        );
      });

      test(
        'logged block keeps the single-block delimiters (no second block)',
        () {
          final block = TpWritebackFormatter.formatLoggedPlanBlock(
            plan(),
            fuelLog(),
            durationMinutes: 120,
          );
          expect(block, startsWith('---\n[Mealvana Fuel Plan]'));
          expect(block, endsWith('[/Mealvana]'));
          expect(block, isNot(contains('[Mealvana Feedback]')));
          expect(block, isNot(contains('Post:')));
        },
      );

      test('a different logged block hashes differently from the plan block '
          '(so the re-push clears the unchanged-plan guard)', () {
        final planned = TpWritebackFormatter.formatPlanBlock(
          plan(),
          durationMinutes: 120,
        );
        final logged = TpWritebackFormatter.formatLoggedPlanBlock(
          plan(),
          fuelLog(),
          durationMinutes: 120,
        );
        expect(
          TpWritebackFormatter.computeHash(planned),
          isNot(equals(TpWritebackFormatter.computeHash(logged))),
        );
      });
    },
  );
}

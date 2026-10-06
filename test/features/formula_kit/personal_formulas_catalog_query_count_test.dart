// Ticket 24 (Sentry MEALVANA-ENDURANCE-DEV-89, "N+1 Query" on
// `settings-formula-library`).
//
// The event: one load of the formula library ran
//   SELECT * FROM template_foods WHERE is_active = ? ORDER BY name
// 41 times, right after one `personal_formulas` read: the Your Formulas list
// refreshed each formula's conflict metadata from the catalog separately.
//
// Seam: the real PersonalFormulasController notifier and the real
// TemplateFoodsRepository over an in-memory Drift database whose executor
// counts statements. The formulas come from a stubbed repository (their read
// is not under test); the catalog rows are Drift inserts, the sync's shape.
import 'package:drift/drift.dart' show ApplyInterceptor, Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/formula_kit/application/personal_formulas_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/data/personal_formulas_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_macros.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/template_foods_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes/recording_report.dart';
import '../../helpers/query_counter.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockUserProfile extends Mock implements UserProfile {}

class _MockPersonalFormulasRepository extends Mock
    implements PersonalFormulasRepository {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  test(
    'loading N personal formulas reads the template_foods catalog once',
    () async {
      final counter = QueryCounter();
      final database = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(counter),
      );
      addTearDown(database.close);

      await database
          .into(database.templateFoodsTable)
          .insert(
            TemplateFoodsTableCompanion.insert(
              id: 'tf-cottage-cheese',
              name: 'cottage_cheese',
              displayName: 'Cottage Cheese',
              servingSize: '1/2 cup',
              allergens: const Value('["dairy"]'),
              excludedDiets: const Value('["vegan"]'),
            ),
          );

      final now = DateTime(2026, 9, 16);
      const n = 41;
      final formulas = [
        for (var i = 0; i < n; i++)
          PersonalFormula(
            id: 'pf-$i',
            userId: 'u-1',
            name: 'Formula $i',
            provenance: FormulaProvenance.forkedFormula,
            phase: FormulaPhase.before,
            components: [
              {
                FormulaMacros.kFoodId: 'tf-cottage-cheese',
                FormulaMacros.kFoodName: 'Cottage Cheese',
                FormulaMacros.kQuantity: 1.0,
              },
            ],
            createdAt: now,
            updatedAt: now,
          ),
      ];
      final personalRepo = _MockPersonalFormulasRepository();
      when(personalRepo.isStale).thenAnswer((_) async => false);
      when(
        () => personalRepo.getFormulasForUser('u-1'),
      ).thenAnswer((_) async => formulas);

      final user = _MockUserProfile();
      when(() => user.id).thenReturn('u-1');
      final userRepo = _MockUserRepository();
      when(userRepo.getCurrentUser).thenAnswer((_) async => user);

      final report = RecordingReport();
      final container = ProviderContainer(
        overrides: [
          reportProvider.overrideWithValue(report),
          userRepositoryProvider.overrideWith((ref) async => userRepo),
          personalFormulasRepositoryProvider.overrideWithValue(personalRepo),
          templateFoodsRepositoryProvider.overrideWithValue(
            TemplateFoodsRepository(
              _MockSupabaseClient(),
              database,
              report: report,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      counter.reset();
      final loaded = await container.read(
        personalFormulasControllerProvider.future,
      );

      expect(
        counter.selectsOn('template_foods'),
        1,
        reason: 'one catalog read for $n formulas (was $n)',
      );
      expect(loaded, hasLength(n));
      for (final f in loaded) {
        expect(f.components.single[FormulaMacros.kAllergens], ['dairy']);
        expect(f.components.single[FormulaMacros.kExcludedDiets], ['vegan']);
      }
    },
  );
}

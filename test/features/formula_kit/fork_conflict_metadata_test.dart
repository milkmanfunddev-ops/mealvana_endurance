/// FP-8 regression — forked/persisted personal-formula components must carry
/// conflict metadata, or the RULED save-time disclosure can never fire.
///
/// Xuan on-device 2026-09-03: "Make this mine" on Cottage Cheese + Applesauce
/// with a dairy allergy produced a personal formula whose editor showed NO
/// conflict disclosure. Cause: `componentsForFork` built component maps
/// without kAllergens/kExcludedDiets (only the +Add Food path stamped them),
/// so `firstComponentConflict` saw nothing. Fix: the fork stamps the metadata
/// AND the editor backfills it on load for formulas persisted without it.
/// This test pins the editor-backfill half (which also rescues old forks).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_editor_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/data/personal_formulas_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_macros.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_profile_conflict.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/template_foods_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSentryReporter extends Mock implements SentryReporter {}

class _MockAppLogger extends Mock implements AppLogger {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockPersonalFormulasRepository extends Mock
    implements PersonalFormulasRepository {}

class _MockTemplateFoodsRepository extends Mock
    implements TemplateFoodsRepository {}

class _MockTemplateFoodEntry extends Mock implements TemplateFoodEntry {}

void main() {
  test(
    'editor backfills kAllergens/kExcludedDiets from template_foods for '
    'components persisted without them, and the conflict then fires',
    () async {
      // A pre-fix forked formula: cottage cheese component, NO metadata keys.
      final now = DateTime(2026, 9, 3);
      final persisted = PersonalFormula(
        id: 'pf-1',
        userId: 'u-1',
        name: 'Cottage Cheese + Applesauce',
        provenance: FormulaProvenance.forkedFormula,
        phase: FormulaPhase.before,
        components: [
          {
            FormulaMacros.kFoodId: 'tf-cottage-cheese',
            FormulaMacros.kFoodName: 'Cottage Cheese',
            FormulaMacros.kQuantity: 1.0,
          },
          {
            FormulaMacros.kFoodId: 'tf-applesauce',
            FormulaMacros.kFoodName: 'Applesauce',
            FormulaMacros.kQuantity: 1.0,
          },
          // Pre-fix Add Food snapshot: keys PRESENT but stale-empty — the
          // catalog must still win (an empty snapshot is not trustworthy).
          {
            FormulaMacros.kFoodId: 'tf-cottage-cheese',
            FormulaMacros.kFoodName: 'Cottage Cheese (stale)',
            FormulaMacros.kQuantity: 0.5,
            FormulaMacros.kAllergens: const <String>[],
            FormulaMacros.kExcludedDiets: const <String>[],
          },
        ],
        createdAt: now,
        updatedAt: now,
      );

      final personalRepo = _MockPersonalFormulasRepository();
      when(
        () => personalRepo.getById('pf-1'),
      ).thenAnswer((_) async => persisted);

      final cottage = _MockTemplateFoodEntry();
      when(() => cottage.id).thenReturn('tf-cottage-cheese');
      when(() => cottage.allergens).thenReturn('["dairy"]');
      when(() => cottage.excludedDiets).thenReturn('["vegan"]');
      final applesauce = _MockTemplateFoodEntry();
      when(() => applesauce.id).thenReturn('tf-applesauce');
      when(() => applesauce.allergens).thenReturn('[]');
      when(() => applesauce.excludedDiets).thenReturn('[]');
      final templateRepo = _MockTemplateFoodsRepository();
      when(
        () => templateRepo.getAllTemplateFoods(),
      ).thenAnswer((_) async => [cottage, applesauce]);

      final userRepo = _MockUserRepository();
      when(() => userRepo.getCurrentUser()).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          userRepositoryProvider.overrideWith((ref) async => userRepo),
          personalFormulasRepositoryProvider.overrideWithValue(personalRepo),
          templateFoodsRepositoryProvider.overrideWithValue(templateRepo),
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              analytics: RecordingAnalyticsTracker(),
              supabaseClient: _MockSupabaseClient(),
              sentry: _MockSentryReporter(),
              logger: _MockAppLogger(),
              sharedPreferences: _MockSharedPreferences(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final draft = await container.read(
        formulaEditorControllerProvider('pf-1', FormulaPhase.before).future,
      );

      expect(
        draft.components.first[FormulaMacros.kAllergens],
        ['dairy'],
        reason: 'the editor must hydrate conflict metadata from the catalog',
      );
      expect(draft.components.first[FormulaMacros.kExcludedDiets], ['vegan']);
      expect(
        draft.components[2][FormulaMacros.kAllergens],
        ['dairy'],
        reason: 'a stale empty snapshot must be refreshed from the catalog',
      );

      // …and with the metadata present, the FP-8 disclosure's detection
      // fires for a dairy-allergic athlete.
      final hit = firstComponentConflict(
        draft.components,
        const AthleteConflictProfile(allergyDbValues: ['dairy']),
      );
      expect(
        hit,
        isNotNull,
        reason: 'a dairy fork must disclose for a dairy allergy',
      );
      expect(hit!.foodName, 'Cottage Cheese');
      expect(hit.conflict.allergenDbValue, 'dairy');
    },
  );
}

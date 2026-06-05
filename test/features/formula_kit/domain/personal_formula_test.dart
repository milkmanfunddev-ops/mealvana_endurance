import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/before_sub_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_view.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';

BeforeComponent _component({
  String foodKey = 'medjool_dates',
  double quantity = 2,
  double carbs = 18,
  double protein = 0.4,
  double fat = 0.1,
  double sodium = 0,
  double fluid = 0,
}) {
  return BeforeComponent(
    foodKey: foodKey,
    displayName: 'Medjool Dates',
    displayNamePlural: 'Medjool Dates',
    servingUnit: null,
    quantity: quantity,
    carbsPerServing: carbs,
    proteinPerServing: protein,
    fatPerServing: fat,
    sodiumMgPerServing: sodium,
    fluidMlPerServing: fluid,
  );
}

PersonalFormula _formula({
  FormulaPhase phase = FormulaPhase.before,
  BeforeSubPhase? subPhase = BeforeSubPhase.snack,
  List<PersonalFormulaComponent>? components,
  List<String>? activityTypes,
}) {
  final now = DateTime.utc(2026, 6, 1, 12);
  return PersonalFormula(
    id: 'pf-1',
    userId: 'user-abc',
    name: 'My Dates Snack',
    phase: phase,
    sourceTemplateId: 'tpl-1',
    subPhase: subPhase,
    digestionSpeed: 'fast',
    templateType: 'food',
    activityTypes: activityTypes,
    durationBrackets: null,
    gutTrainingLevels: null,
    components: components ??
        [PersonalFormulaComponent.fromBeforeComponent(_component())],
    totalCarbsG: 36,
    totalProteinG: 0.8,
    totalFatG: 0.2,
    totalSodiumMg: 0,
    totalFluidMl: 0,
    totalCalories: 149,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('PersonalFormulaComponent', () {
    test('fromBeforeComponent copies identity + per-serving macros + quantity',
        () {
      final c = PersonalFormulaComponent.fromBeforeComponent(
        _component(quantity: 3, carbs: 20),
      );
      expect(c.foodKey, 'medjool_dates');
      expect(c.displayName, 'Medjool Dates');
      expect(c.quantity, 3);
      expect(c.carbsPerServing, 20);
      expect(c.userFoodId, isNull,
          reason: 'swap-to-user-food lands in PR 5b — null until then');
    });

    test('toJson/fromJson is a lossless round-trip', () {
      final original = PersonalFormulaComponent.fromBeforeComponent(
        _component(quantity: 1.5, carbs: 18.5, protein: 0.4, sodium: 12),
      );
      final restored = PersonalFormulaComponent.fromJson(original.toJson());

      expect(restored.foodKey, original.foodKey);
      expect(restored.quantity, original.quantity);
      expect(restored.carbsPerServing, original.carbsPerServing);
      expect(restored.proteinPerServing, original.proteinPerServing);
      expect(restored.sodiumMgPerServing, original.sodiumMgPerServing);
      expect(restored.displayName, original.displayName);
    });

    test('fromJson coerces int macros to double and tolerates missing keys',
        () {
      final c = PersonalFormulaComponent.fromJson({
        'food_key': 'banana',
        'quantity': 1, // int from JSON
        'carbs_per_serving': 27, // int
        // protein/fat/sodium/fluid omitted entirely
      });
      expect(c.foodKey, 'banana');
      expect(c.quantity, 1.0);
      expect(c.carbsPerServing, 27.0);
      expect(c.proteinPerServing, 0.0);
      expect(c.fluidMlPerServing, 0.0);
    });
  });

  group('PersonalFormula.toSupabaseJson', () {
    test('emits snake_case keys, components as a list, and excludes Drift-only '
        'sync columns', () {
      final json = _formula().toSupabaseJson();

      expect(json['id'], 'pf-1');
      expect(json['user_id'], 'user-abc');
      expect(json['phase'], 'before');
      expect(json['source_template_id'], 'tpl-1');
      expect(json['sub_phase'], 'snack');
      expect(json['total_calories'], 149);
      expect(json['is_deleted'], false);

      // components serialized as a List (Supabase JSONB), not a JSON string.
      expect(json['components'], isA<List<dynamic>>());
      expect((json['components'] as List).single,
          containsPair('food_key', 'medjool_dates'));

      // Drift-only columns must not leak to Supabase.
      expect(json.containsKey('needs_upload'), isFalse);
      expect(json.containsKey('local_updated_at'), isFalse);
    });

    test('sub_phase uses BeforeSubPhase.storageValue (top_up, not topUp)', () {
      final json =
          _formula(subPhase: BeforeSubPhase.topUp).toSupabaseJson();
      expect(json['sub_phase'], 'top_up');
    });

    test('during-phase arrays pass through as List<String> for Postgres text[]',
        () {
      final json = _formula(
        phase: FormulaPhase.during,
        subPhase: null,
        activityTypes: const ['running', 'cycling'],
      ).toSupabaseJson();
      expect(json['phase'], 'during');
      expect(json['activity_types'], ['running', 'cycling']);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/coach_insight.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_macros.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';

/// Tests for the coach-insight draft context + result.
///
/// The [CoachInsightContext.staleMarker] is the load-bearing piece: it drives
/// whether the panel shows a fresh or "outdated" insight, and the client
/// caches `(staleMarker → insight)`. These tests lock in that it (a) is stable
/// for an unchanged draft, (b) changes when any insight-relevant field changes,
/// and (c) ignores fields the model never sees.
void main() {
  Map<String, dynamic> comp({
    String name = 'Oatmeal',
    double quantity = 1,
    double carbs = 27,
  }) {
    return {
      FormulaMacros.kFoodName: name,
      FormulaMacros.kQuantity: quantity,
      FormulaMacros.kCarbsPerServing: carbs,
      FormulaMacros.kProteinPerServing: 5.0,
      FormulaMacros.kFatPerServing: 3.0,
      FormulaMacros.kSodiumMg: 2.0,
      FormulaMacros.kFluidMlPerServing: 0.0,
      FormulaMacros.kCaloriesPerServing: 150.0,
    };
  }

  CoachInsightContext ctx({
    FormulaPhase phase = FormulaPhase.before,
    String? subPhase = 'snack',
    List<String>? durations,
    List<String>? activities,
    String? name = 'Pre-run',
    List<Map<String, dynamic>>? components,
  }) {
    return CoachInsightContext(
      phase: phase,
      subPhase: subPhase,
      durations: durations,
      activities: activities,
      name: name,
      components: components ?? [comp()],
    );
  }

  group('staleMarker', () {
    test('is stable for an identical draft', () {
      expect(ctx().staleMarker, ctx().staleMarker);
    });

    test('changes when a component quantity changes', () {
      final a = ctx(components: [comp(quantity: 1)]);
      final b = ctx(components: [comp(quantity: 2)]);
      expect(a.staleMarker, isNot(b.staleMarker));
    });

    test('changes when a component is added', () {
      final a = ctx(components: [comp()]);
      final b = ctx(components: [comp(), comp(name: 'Banana', carbs: 27)]);
      expect(a.staleMarker, isNot(b.staleMarker));
    });

    test('changes when the sub-phase changes', () {
      expect(ctx(subPhase: 'snack').staleMarker,
          isNot(ctx(subPhase: 'meal').staleMarker));
    });

    test('changes when the phase changes', () {
      expect(ctx(phase: FormulaPhase.before).staleMarker,
          isNot(ctx(phase: FormulaPhase.during, subPhase: null).staleMarker));
    });

    test('changes when the name changes', () {
      expect(ctx(name: 'A').staleMarker, isNot(ctx(name: 'B').staleMarker));
    });
  });

  group('toJson', () {
    test('emits phase wire value, name, and component macros', () {
      final json = ctx().toJson();
      expect(json['phase'], 'before');
      expect(json['sub_phase'], 'snack');
      expect(json['name'], 'Pre-run');
      final components = json['components'] as List;
      expect(components, hasLength(1));
      final c = components.first as Map<String, dynamic>;
      expect(c[FormulaMacros.kFoodName], 'Oatmeal');
      expect(c[FormulaMacros.kCarbsPerServing], 27);
    });

    test('omits null scope fields', () {
      final json = ctx(subPhase: null, durations: null, activities: null).toJson();
      expect(json.containsKey('sub_phase'), isFalse);
      expect(json.containsKey('durations'), isFalse);
      expect(json.containsKey('activities'), isFalse);
    });

    test('trims a blank name out of the payload', () {
      final json = ctx(name: '   ').toJson();
      expect(json.containsKey('name'), isFalse);
    });
  });

  group('CoachInsight.isCurrentFor', () {
    test('true when markers match', () {
      const insight = CoachInsight(insight: 'Looks good.', staleMarker: 'abc');
      expect(insight.isCurrentFor('abc'), isTrue);
    });

    test('false when markers differ', () {
      const insight = CoachInsight(insight: 'Looks good.', staleMarker: 'abc');
      expect(insight.isCurrentFor('xyz'), isFalse);
    });
  });
}

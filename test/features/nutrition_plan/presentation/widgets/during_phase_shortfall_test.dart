import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_shortfall.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/activity_detail/during_phase_section_widget.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/macro_shortfall_card.dart';

Widget _buildDuringSection(PlanSection section) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DuringPhaseSectionWidget(
            section: section,
            sectionColor: Colors.orange,
            sectionTitle: 'During Run',
            category: 'during_run',
            durationMinutes: 45,
            useImperial: false,
            onSwapFood: (_, __, ___) {},
            onDeleteFood: (_, __) {},
            onUpdateQuantity: (_, __, ___) {},
            onAddFood: (_) {},
            onInitializeByHour: (_, __) {},
            onMoveFoodToTimeSlot: (_, __, ___, ____) {},
            onPlaceFoodInSlot: (_, __, ___, ____, _____, ______) {},
            onRemoveFoodFromSlot: (_, __, ___) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('During section renders shortfall card when shortfalls present', (
    tester,
  ) async {
    const section = PlanSection(
      id: 'during_run',
      title: 'During Run',
      foodItems: [],
      shortfalls: [
        MacroShortfall(
          macro: ShortfallMacro.carbs,
          delivered: 45,
          target: 60,
          unit: 'g',
          reason: ShortfallReason.allDisliked,
        ),
      ],
    );

    await tester.pumpWidget(_buildDuringSection(section));

    expect(find.byType(MacroShortfallCard), findsOneWidget);
    // Same header format the Before-phase card renders.
    expect(find.text('Carbs gap: ~15g short'), findsOneWidget);
  });

  testWidgets('During section hides shortfall card when no shortfalls', (
    tester,
  ) async {
    const section = PlanSection(
      id: 'during_run',
      title: 'During Run',
      foodItems: [],
    );

    await tester.pumpWidget(_buildDuringSection(section));

    expect(find.byType(MacroShortfallCard), findsNothing);
  });

  group('recomputeShortfalls', () {
    test(
      'clears sodium shortfall when edited foods bring total above floor',
      () {
        const section = PlanSection(
          id: 'during_run',
          title: 'During Run',
          sodiumTarget: 2272,
          sodiumLowTarget: 1818,
          foodItems: [],
          shortfalls: [
            MacroShortfall(
              macro: ShortfallMacro.sodium,
              delivered: 1630,
              target: 2272,
              unit: 'mg',
              reason: ShortfallReason.templateConstraint,
            ),
          ],
        );

        final updatedFoods = [
          const FoodItemData(
            id: 'capsule-1',
            name: 'Electrolyte Capsules',
            quantity: '6',
            nutritionalInfo: NutritionalInfo(sodium: 2010),
          ),
        ];

        final result = ActivityDetailController.recomputeShortfalls(
          updatedFoods,
          section,
        );

        expect(result, isEmpty);
      },
    );

    test(
      'keeps sodium shortfall with updated delivered when still below floor',
      () {
        const section = PlanSection(
          id: 'during_run',
          title: 'During Run',
          sodiumTarget: 2272,
          sodiumLowTarget: 1818,
          foodItems: [],
          shortfalls: [
            MacroShortfall(
              macro: ShortfallMacro.sodium,
              delivered: 1630,
              target: 2272,
              unit: 'mg',
              reason: ShortfallReason.templateConstraint,
            ),
          ],
        );

        final updatedFoods = [
          const FoodItemData(
            id: 'capsule-1',
            name: 'Electrolyte Capsules',
            quantity: '4',
            nutritionalInfo: NutritionalInfo(sodium: 1700),
          ),
        ];

        final result = ActivityDetailController.recomputeShortfalls(
          updatedFoods,
          section,
        );

        expect(result, hasLength(1));
        expect(result.first.delivered, 1700);
        expect(result.first.target, 2272);
        expect(result.first.gap, 572);
      },
    );

    test('falls back to 90% of target when no range low is set', () {
      const section = PlanSection(
        id: 'during_run',
        title: 'During Run',
        sodiumTarget: 1000,
        foodItems: [],
        shortfalls: [
          MacroShortfall(
            macro: ShortfallMacro.sodium,
            delivered: 800,
            target: 1000,
            unit: 'mg',
            reason: ShortfallReason.templateConstraint,
          ),
        ],
      );

      final aboveFloor = [
        const FoodItemData(
          id: 'f1',
          name: 'Food',
          quantity: '1',
          nutritionalInfo: NutritionalInfo(sodium: 910),
        ),
      ];
      expect(
        ActivityDetailController.recomputeShortfalls(aboveFloor, section),
        isEmpty,
      );

      final belowFloor = [
        const FoodItemData(
          id: 'f1',
          name: 'Food',
          quantity: '1',
          nutritionalInfo: NutritionalInfo(sodium: 880),
        ),
      ];
      final result = ActivityDetailController.recomputeShortfalls(
        belowFloor,
        section,
      );
      expect(result, hasLength(1));
      expect(result.first.delivered, 880);
    });
  });
}

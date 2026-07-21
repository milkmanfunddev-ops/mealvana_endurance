import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_shortfall.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
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
  testWidgets('During section renders shortfall card when shortfalls present',
      (tester) async {
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

  testWidgets('During section hides shortfall card when no shortfalls',
      (tester) async {
    const section = PlanSection(
      id: 'during_run',
      title: 'During Run',
      foodItems: [],
    );

    await tester.pumpWidget(_buildDuringSection(section));

    expect(find.byType(MacroShortfallCard), findsNothing);
  });
}

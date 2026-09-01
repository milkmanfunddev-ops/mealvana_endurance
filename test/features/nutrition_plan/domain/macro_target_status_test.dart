import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_target_status.dart';

void main() {
  group('classifyMacroTarget', () {
    test('uses the same green and non-green ratio boundaries as the UI', () {
      expect(
        classifyMacroTarget(actual: 80, target: 100),
        MacroTargetStatus.green,
      );
      expect(
        classifyMacroTarget(actual: 79, target: 100),
        MacroTargetStatus.nonGreen,
      );
      expect(
        classifyMacroTarget(actual: 50, target: 100),
        MacroTargetStatus.severe,
      );
    });

    test('classifies values against an explicit recommended range', () {
      expect(
        classifyMacroTarget(actual: 90, target: 100, low: 90, high: 110),
        MacroTargetStatus.green,
      );
      expect(
        classifyMacroTarget(actual: 88, target: 100, low: 90, high: 110),
        MacroTargetStatus.nonGreen,
      );
      expect(
        classifyMacroTarget(actual: 80, target: 100, low: 90, high: 110),
        MacroTargetStatus.severe,
      );
    });
  });
}

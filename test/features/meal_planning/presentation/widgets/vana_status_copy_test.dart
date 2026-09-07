import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_status_copy.dart';

import '../helpers/test_content.dart';

/// Plan §5 Phase 1.5 — every tool the stream can name resolves to a status
/// key with real default copy; unknown tools fall back to the thinking line.
void main() {
  const finding = ['suggestMeals', 'searchMeals', 'diagnoseStaples'];
  const combo = ['checkCombination'];
  const building = ['confirmPlan', 'shoppingList'];
  const reading = [
    'getWorkouts',
    'getProfile',
    'getMacroTargets',
    'getWeather',
    'dayGuidance',
    'getBatch',
    'recallFacts',
    'recallConversations',
    'getLoggedMeals',
  ];

  test('tool → key groups', () {
    for (final t in finding) {
      expect(VanaStatusCopy.keyForTool(t), ContentKeys.mpStatusFindingMeals);
    }
    for (final t in combo) {
      expect(VanaStatusCopy.keyForTool(t), ContentKeys.mpStatusCheckingCombo);
    }
    for (final t in building) {
      expect(VanaStatusCopy.keyForTool(t), ContentKeys.mpStatusBuildingList);
    }
    for (final t in reading) {
      expect(VanaStatusCopy.keyForTool(t), ContentKeys.mpStatusReadingWeek);
    }
  });

  test('unknown tools fall back to the thinking line', () {
    expect(
      VanaStatusCopy.keyForTool('rememberFact'),
      ContentKeys.mpStatusThinking,
    );
    expect(VanaStatusCopy.keyForTool(''), ContentKeys.mpStatusThinking);
  });

  test('every status key has default copy', () {
    final content = loadDefaultContent();
    for (final t in [...finding, ...combo, ...building, ...reading, 'x']) {
      final key = VanaStatusCopy.keyForTool(t);
      expect(content[key], isNotNull, reason: 'no default for $key');
      expect(content[key], endsWith('…'), reason: '$key is a status line');
    }
  });
}

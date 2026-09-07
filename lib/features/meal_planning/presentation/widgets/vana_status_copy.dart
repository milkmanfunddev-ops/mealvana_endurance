import '../../../../features/content/domain/content_keys.dart';

/// Per-tool status copy (plan §5 Phase 1.5) — maps the `status` stream
/// line's tool name to the content key rendered beside the mini avatar.
/// A pure table so the mapping is unit-testable; anything unknown falls
/// back to the generic thinking line.
abstract final class VanaStatusCopy {
  static const Map<String, String> _byTool = {
    'suggestMeals': ContentKeys.mpStatusFindingMeals,
    'searchMeals': ContentKeys.mpStatusFindingMeals,
    'diagnoseStaples': ContentKeys.mpStatusFindingMeals,
    'checkCombination': ContentKeys.mpStatusCheckingCombo,
    'confirmPlan': ContentKeys.mpStatusBuildingList,
    'shoppingList': ContentKeys.mpStatusBuildingList,
    'getWorkouts': ContentKeys.mpStatusReadingWeek,
    'getProfile': ContentKeys.mpStatusReadingWeek,
    'getMacroTargets': ContentKeys.mpStatusReadingWeek,
    'getWeather': ContentKeys.mpStatusReadingWeek,
    'dayGuidance': ContentKeys.mpStatusReadingWeek,
    'getBatch': ContentKeys.mpStatusReadingWeek,
    'recallFacts': ContentKeys.mpStatusReadingWeek,
    'recallConversations': ContentKeys.mpStatusReadingWeek,
    'getLoggedMeals': ContentKeys.mpStatusReadingWeek,
    // Client-raised while the `pantry_photo` action runs (plan §5 Phase 7.3).
    'pantryPhoto': ContentKeys.mpStatusReadingPhoto,
  };

  /// The [ContentKeys] key for [tool]; [ContentKeys.mpStatusThinking] when
  /// the tool has no copy of its own.
  static String keyForTool(String tool) =>
      _byTool[tool] ?? ContentKeys.mpStatusThinking;
}

/// 5-level carb feedback scale for post-workout adjustment.
///
/// Each level adjusts the user's during-activity carb rate override
/// via [adjustmentFactor]. "Just Right" means no change.
enum CarbAdjustmentLevel {
  muchLess(
    emoji: '\u{1F623}', // 😣
    label: 'Way Too Much',
    description: "We'll reduce carbs by 20%",
    adjustmentFactor: 0.8,
  ),
  less(
    emoji: '\u{1F615}', // 😕
    label: 'A Bit Too Much',
    description: "We'll reduce carbs by 10%",
    adjustmentFactor: 0.9,
  ),
  justRight(
    emoji: '\u{1F60A}', // 😊
    label: 'Just Right',
    description: 'No changes needed',
    adjustmentFactor: 1.0,
  ),
  more(
    emoji: '\u{1F914}', // 🤔
    label: 'Needed More',
    description: "We'll increase carbs by 10%",
    adjustmentFactor: 1.1,
  ),
  muchMore(
    emoji: '\u{1F624}', // 😤
    label: 'Way Too Little',
    description: "We'll increase carbs by 20%",
    adjustmentFactor: 1.2,
  );

  const CarbAdjustmentLevel({
    required this.emoji,
    required this.label,
    required this.description,
    required this.adjustmentFactor,
  });

  final String emoji;
  final String label;
  final String description;

  /// Multiplier applied to the current carb rate (e.g., 0.9 = -10%).
  final double adjustmentFactor;

  /// Persisted 1-5 rating value (maps directly to `nutrition_rating`).
  int get ratingValue => switch (this) {
    CarbAdjustmentLevel.muchLess => 1,
    CarbAdjustmentLevel.less => 2,
    CarbAdjustmentLevel.justRight => 3,
    CarbAdjustmentLevel.more => 4,
    CarbAdjustmentLevel.muchMore => 5,
  };

  static CarbAdjustmentLevel? fromRatingValue(int? rating) {
    return switch (rating) {
      1 => CarbAdjustmentLevel.muchLess,
      2 => CarbAdjustmentLevel.less,
      3 => CarbAdjustmentLevel.justRight,
      4 => CarbAdjustmentLevel.more,
      5 => CarbAdjustmentLevel.muchMore,
      _ => null,
    };
  }
}

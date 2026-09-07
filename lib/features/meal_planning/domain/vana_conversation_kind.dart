/// `ConversationKind` in `contracts.ts`.
enum VanaConversationKind {
  mealPlanning('meal_planning'),
  general('general');

  const VanaConversationKind(this.wire);

  final String wire;

  static VanaConversationKind? fromWire(String? value) {
    if (value == null) return null;
    for (final v in VanaConversationKind.values) {
      if (v.wire == value) return v;
    }
    return null;
  }

  static VanaConversationKind requireWire(String? value) =>
      fromWire(value) ??
      (throw FormatException('Unknown VanaConversationKind "$value"'));
}

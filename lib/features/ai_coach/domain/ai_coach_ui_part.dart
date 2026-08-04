import '../../meal_logging/domain/meal_component.dart';
import '../../meal_logging/domain/meal_slot.dart';

/// A suggestion for a single meal, as sent by Jade.
///
/// Maps to the server-side `MealSuggestion` shape in `tools.ts`.
class JadeMealSuggestion {
  const JadeMealSuggestion({
    required this.name,
    required this.description,
    required this.kcal,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.slot,
    required this.components,
  });

  final String name;
  final String description;
  final int kcal;
  final double carbG;
  final double proteinG;
  final double fatG;

  /// The recommended meal slot. May be null when the slot value from the
  /// server is unrecognised (forward-compat tolerance).
  final MealSlot? slot;

  /// Individual food items that make up this meal.
  final List<MealComponent> components;

  factory JadeMealSuggestion.fromJson(Map<String, dynamic> json) {
    final rawComponents = json['components'];
    final components = <MealComponent>[];
    if (rawComponents is List) {
      for (final c in rawComponents) {
        if (c is Map<String, dynamic>) {
          components.add(MealComponent.fromJson(c));
        }
      }
    }

    return JadeMealSuggestion(
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      kcal: (json['kcal'] as num?)?.toInt() ?? 0,
      carbG: (json['carb_g'] as num?)?.toDouble() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
      slot: MealSlot.fromWireValue(json['slot'] as String?),
      components: components,
    );
  }
}

// ---------------------------------------------------------------------------
// Sealed UI part hierarchy
// ---------------------------------------------------------------------------

/// A UI-renderable component attached to an assistant message.
///
/// Sealed so the widget layer can exhaustively switch on kind without
/// falling through to an unknown case. Unknown kinds from the server are
/// silently discarded at the parse layer — new kinds added on the server
/// will just not render on older clients (graceful degradation).
sealed class JadeUiPart {
  const JadeUiPart();

  /// Deserialize a single part from its JSON map.
  ///
  /// Returns null when the `kind` is unrecognised or the JSON is malformed,
  /// so callers can safely filter with `whereType<JadeUiPart>()`.
  static JadeUiPart? fromJson(Map<String, dynamic> json) {
    try {
      final kind = json['kind'] as String?;
      switch (kind) {
        case 'meal_cards':
          return JadeMealCardsPart.fromJson(json);
        case 'choices':
          return JadeChoicesPart.fromJson(json);
        default:
          // Unknown kind — ignore for forward-compatibility.
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}

/// Meal suggestion cards — rendered as [JadeMealCard] widgets.
class JadeMealCardsPart extends JadeUiPart {
  const JadeMealCardsPart({required this.meals});

  final List<JadeMealSuggestion> meals;

  factory JadeMealCardsPart.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'];
    final meals = <JadeMealSuggestion>[];
    if (rawMeals is List) {
      for (final m in rawMeals) {
        if (m is Map<String, dynamic>) {
          meals.add(JadeMealSuggestion.fromJson(m));
        }
      }
    }
    return JadeMealCardsPart(meals: meals);
  }
}

/// Multiple-choice prompt — rendered as [JadeChoiceButtons].
class JadeChoicesPart extends JadeUiPart {
  const JadeChoicesPart({required this.question, required this.options});

  final String question;
  final List<String> options;

  factory JadeChoicesPart.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = <String>[];
    if (rawOptions is List) {
      for (final o in rawOptions) {
        if (o is String) options.add(o);
      }
    }
    return JadeChoicesPart(
      question: (json['question'] as String?) ?? '',
      options: options,
    );
  }
}

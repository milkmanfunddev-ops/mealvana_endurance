import 'meal_component.dart';

/// A pre-defined two-ingredient (or small combo) assembly for the Quick tab.
///
/// Macros are representative estimates for common endurance-athlete snacks.
/// All calorie values satisfy: calories ≈ carbG*4 + proteinG*4 + fatG*9.
class QuickAssembly {
  const QuickAssembly({
    required this.name,
    required this.emoji,
    required this.components,
  });

  /// Display name shown in the Quick tab row.
  final String name;

  /// Single emoji used as the leading icon.
  final String emoji;

  /// One or two [MealComponent] entries that make up this assembly.
  final List<MealComponent> components;

  /// Aggregate calories across all components.
  int get totalCalories =>
      components.fold(0, (sum, c) => sum + (c.calories ?? 0));

  /// Aggregate carbs (g).
  double get totalCarbsG =>
      components.fold(0.0, (sum, c) => sum + (c.carbG ?? 0.0));

  /// Aggregate protein (g).
  double get totalProteinG =>
      components.fold(0.0, (sum, c) => sum + (c.proteinG ?? 0.0));

  /// Aggregate fat (g).
  double get totalFatG =>
      components.fold(0.0, (sum, c) => sum + (c.fatG ?? 0.0));
}

// ---------------------------------------------------------------------------
// Static catalog — 10 endurance-sensible combos
// ---------------------------------------------------------------------------

/// Quick-log catalog, ordered from lightest to most substantial.
const List<QuickAssembly> kQuickAssemblies = [
  QuickAssembly(
    name: 'Banana + peanut butter',
    emoji: '🍌',
    components: [
      MealComponent(
        name: 'Banana',
        portion: '1 medium',
        calories: 105,
        carbG: 27,
        proteinG: 1.3,
        fatG: 0.4,
      ),
      MealComponent(
        name: 'Peanut butter',
        portion: '1 tbsp',
        calories: 94,
        carbG: 3.2,
        proteinG: 4.0,
        fatG: 8.0,
      ),
    ],
  ),
  QuickAssembly(
    name: 'Greek yogurt + honey',
    emoji: '🍯',
    components: [
      MealComponent(
        name: 'Greek yogurt',
        portion: '3/4 cup',
        calories: 100,
        carbG: 6.0,
        proteinG: 17.0,
        fatG: 0.7,
      ),
      MealComponent(
        name: 'Honey',
        portion: '1 tbsp',
        calories: 64,
        carbG: 17.0,
        proteinG: 0.1,
        fatG: 0.0,
      ),
    ],
  ),
  QuickAssembly(
    name: 'Rice cake + almond butter',
    emoji: '🌾',
    components: [
      MealComponent(
        name: 'Rice cake',
        portion: '2 cakes',
        calories: 70,
        carbG: 15.0,
        proteinG: 1.4,
        fatG: 0.6,
      ),
      MealComponent(
        name: 'Almond butter',
        portion: '1 tbsp',
        calories: 98,
        carbG: 3.0,
        proteinG: 3.4,
        fatG: 9.0,
      ),
    ],
  ),
  QuickAssembly(
    name: 'Oatmeal + raisins',
    emoji: '🥣',
    components: [
      MealComponent(
        name: 'Rolled oats',
        portion: '1/2 cup dry',
        calories: 150,
        carbG: 27.0,
        proteinG: 5.0,
        fatG: 2.5,
      ),
      MealComponent(
        name: 'Raisins',
        portion: '2 tbsp',
        calories: 54,
        carbG: 14.0,
        proteinG: 0.6,
        fatG: 0.1,
      ),
    ],
  ),
  QuickAssembly(
    name: 'Eggs + toast',
    emoji: '🍳',
    components: [
      MealComponent(
        name: 'Eggs',
        portion: '2 large',
        calories: 140,
        carbG: 1.2,
        proteinG: 12.0,
        fatG: 10.0,
      ),
      MealComponent(
        name: 'Whole-grain toast',
        portion: '2 slices',
        calories: 138,
        carbG: 26.0,
        proteinG: 6.0,
        fatG: 2.0,
      ),
    ],
  ),
  QuickAssembly(
    name: 'Cottage cheese + fruit',
    emoji: '🍓',
    components: [
      MealComponent(
        name: 'Cottage cheese',
        portion: '1/2 cup',
        calories: 110,
        carbG: 6.0,
        proteinG: 14.0,
        fatG: 2.5,
      ),
      MealComponent(
        name: 'Mixed berries',
        portion: '1/2 cup',
        calories: 40,
        carbG: 9.0,
        proteinG: 0.6,
        fatG: 0.3,
      ),
    ],
  ),
  QuickAssembly(
    name: 'Protein shake + banana',
    emoji: '💪',
    components: [
      MealComponent(
        name: 'Whey protein shake',
        portion: '1 scoop in water',
        calories: 130,
        carbG: 4.0,
        proteinG: 25.0,
        fatG: 2.0,
      ),
      MealComponent(
        name: 'Banana',
        portion: '1 medium',
        calories: 105,
        carbG: 27.0,
        proteinG: 1.3,
        fatG: 0.4,
      ),
    ],
  ),
  QuickAssembly(
    name: 'Chocolate milk',
    emoji: '🥛',
    components: [
      MealComponent(
        name: 'Low-fat chocolate milk',
        portion: '1 cup (240 ml)',
        calories: 158,
        carbG: 26.0,
        proteinG: 8.0,
        fatG: 2.5,
      ),
    ],
  ),
  QuickAssembly(
    name: 'Apple + cheese',
    emoji: '🍎',
    components: [
      MealComponent(
        name: 'Apple',
        portion: '1 medium',
        calories: 95,
        carbG: 25.0,
        proteinG: 0.5,
        fatG: 0.3,
      ),
      MealComponent(
        name: 'Cheddar cheese',
        portion: '1 oz (28 g)',
        calories: 113,
        carbG: 0.4,
        proteinG: 7.0,
        fatG: 9.0,
      ),
    ],
  ),
  QuickAssembly(
    name: 'Date energy balls',
    emoji: '⚡',
    components: [
      MealComponent(
        name: 'Medjool dates',
        portion: '3 dates',
        calories: 201,
        carbG: 54.0,
        proteinG: 1.8,
        fatG: 0.3,
      ),
    ],
  ),
];

/// Meal type for carb loading (breakfast, lunch, dinner, snacks)
/// Maps to meal_types database table
enum MealType {
  breakfast(1, 'breakfast', 'Breakfast'),
  lunch(2, 'lunch', 'Lunch'),
  dinner(3, 'dinner', 'Dinner'),
  snacks(4, 'snacks', 'Snacks'), // Deprecated - use specific snack types
  morningSnack(5, 'morning_snack', 'Morning Snack'),
  afternoonSnack(6, 'afternoon_snack', 'Afternoon Snack'),
  eveningSnack(7, 'evening_snack', 'Evening Snack');

  const MealType(this.id, this.name, this.displayName);

  final int id;
  final String name;
  final String displayName;

  /// Get MealType from database ID
  static MealType fromId(int id) {
    return MealType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => MealType.breakfast,
    );
  }

  /// Get MealType from name string
  static MealType fromName(String name) {
    return MealType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => MealType.breakfast,
    );
  }
}

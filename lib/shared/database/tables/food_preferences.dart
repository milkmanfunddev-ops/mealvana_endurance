import 'package:drift/drift.dart';

/// Food preferences table definition for Drift - matches Supabase food_preferences table schema
/// Stores user preferences for individual foods (like, dislike, willing_to_try)
@DataClassName('FoodPreferenceEntry')
class FoodPreferencesTable extends Table {
  /// UUID primary key (matches Supabase food_preferences.id)
  TextColumn get id => text().withLength(min: 36, max: 36)();

  /// User ID (foreign key reference to users.id UUID)
  TextColumn get userId => text().named('user_id')();

  /// Food name (should match foods.name) - matches Supabase food_preferences.food_name
  TextColumn get foodName => text().named('food_name')();

  /// Preference type: 'like', 'dislike', 'willing_to_try' (matches Supabase constraint)
  TextColumn get preference => text()();

  /// Slider intensity level (0-4) representing the UI selection strength
  IntColumn get preferenceLevel =>
      integer().named('preference_level').withDefault(const Constant(2))();

  /// When the preference was created (matches Supabase food_preferences.created_at)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the preference was last updated (matches Supabase food_preferences.updated_at)
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE(user_id, food_name)', // Ensure one preference per food per user
    'CHECK (preference IN (\'like\', \'dislike\', \'willing_to_try\'))', // Match Supabase constraint
    'CHECK (preference_level >= 0 AND preference_level <= 4)',
  ];
}
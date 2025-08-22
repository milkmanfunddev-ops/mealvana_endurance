import 'package:drift/drift.dart';

/// Food preferences table definition for Drift
/// Stores user preferences for individual foods
@DataClassName('FoodPreferenceEntry')
class FoodPreferencesTable extends Table {
  /// User ID (foreign key reference)
  TextColumn get userId => text()();
  
  /// Food ID or name
  TextColumn get foodId => text()();
  
  /// Preference type (like, dislike, neutral, willingToTry)
  TextColumn get preference => text()();
  
  /// When the preference was created
  DateTimeColumn get createdAt => dateTime()();
  
  /// When the preference was last updated
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId, foodId};
}
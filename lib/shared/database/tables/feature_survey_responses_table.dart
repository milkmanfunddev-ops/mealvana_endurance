import 'package:drift/drift.dart';

/// Feature survey responses table
/// Stores user votes for feature requests (one vote per user)
@DataClassName('FeatureSurveyResponseEntry')
class FeatureSurveyResponsesTable extends Table {
  @override
  String get tableName => 'feature_survey_responses';

  /// Primary key - BIGSERIAL
  IntColumn get id => integer().autoIncrement()();

  /// User ID (UUID) - references users.id
  TextColumn get userId => text().named('user_id')();

  /// JSON array of selected feature IDs (exactly 3)
  /// Example: ["shopping_list", "coach_sharing", "recipes"]
  TextColumn get selectedFeatures => text().named('selected_features')();

  /// Timestamp of when the vote was cast
  DateTimeColumn get votedAt => dateTime().named('voted_at')();

  // Note: Primary key is automatically set by autoIncrement()

  @override
  List<String> get customConstraints => [
    'UNIQUE(user_id)', // One vote per user
  ];
}

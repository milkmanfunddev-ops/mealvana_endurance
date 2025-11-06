import 'package:drift/drift.dart';

/// Feature survey responses table
/// Stores user votes for feature requests (one vote per device)
@DataClassName('FeatureSurveyResponseEntry')
class FeatureSurveyResponsesTable extends Table {
  @override
  String get tableName => 'feature_survey_responses';

  /// Primary key - UUID
  TextColumn get id => text()();

  /// Device ID of the user who voted
  TextColumn get deviceId => text().named('device_id')();

  /// JSON array of selected feature IDs (exactly 3)
  /// Example: ["shopping_list", "coach_sharing", "recipes"]
  TextColumn get selectedFeatures => text().named('selected_features')();

  /// Timestamp of when the vote was cast
  DateTimeColumn get votedAt => dateTime().named('voted_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE(device_id)', // One vote per device
  ];
}

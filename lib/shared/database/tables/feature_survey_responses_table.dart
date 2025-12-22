import 'dart:math';
import 'package:drift/drift.dart';

/// Feature survey responses table
/// Stores user votes for feature requests (one vote per device)
@DataClassName('FeatureSurveyResponseEntry')
class FeatureSurveyResponsesTable extends Table {
  @override
  String get tableName => 'feature_survey_responses';

  /// Primary key - random integer
  IntColumn get id => integer().clientDefault(() => Random().nextInt(2147483647))();

  /// Device ID - references users.id (unified with user_id)
  TextColumn get deviceId => text().named('device_id')();

  /// JSON array of selected feature IDs (exactly 3)
  /// Example: ["shopping_list", "coach_sharing", "recipes"]
  TextColumn get selectedFeatures => text().named('selected_features')();

  /// Timestamp of when the vote was cast
  DateTimeColumn get votedAt => dateTime().named('voted_at')();

  /// Sync tracking columns
  BoolColumn get needsUpload => boolean().withDefault(const Constant(false)).named('needs_upload')();
  DateTimeColumn get localUpdatedAt => dateTime().nullable().named('local_updated_at')();

  @override
  List<String> get customConstraints => [
    'UNIQUE(device_id)', // One vote per device
  ];
}

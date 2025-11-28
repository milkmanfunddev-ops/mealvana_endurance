import 'package:drift/drift.dart';

/// Feedback table definition for Drift
/// Stores user survey responses with notification preferences
@DataClassName('FeedbackEntry')
class FeedbackTable extends Table {
  /// Primary key - auto-generated UUID
  TextColumn get id => text()();
  
  /// Device ID to associate with user
  TextColumn get deviceId => text().nullable()();
  
  /// Original feedback fields (existing)
  IntColumn get satisfactionLevel => integer()();
  TextColumn get satisfactionEmoji => text()();
  TextColumn get satisfactionLabel => text()();
  TextColumn get appFeedback => text().nullable()();
  TextColumn get suggestions => text().nullable()();
  TextColumn get planName => text().nullable()();
  TextColumn get userName => text().nullable()();
  DateTimeColumn get timestamp => dateTime().nullable()();

  /// New survey fields
  IntColumn get confidenceLevel => integer().nullable()();
  TextColumn get confidenceLabel => text().nullable()();
  TextColumn get reuseIntent => text().nullable()();
  BoolColumn get reminderRequested => boolean().withDefault(const Constant(false))();
  
  /// Missed reasons stored as JSON array (for single selection + other text)
  TextColumn get missedReasons => text().nullable()(); // Will store JSON array
  TextColumn get missedOther => text().nullable()();
  
  /// Notification preferences
  IntColumn get reminderDayOfWeek => integer().nullable()(); // 1=Monday, 4=Thursday, 6=Saturday
  IntColumn get reminderHour => integer().withDefault(const Constant(17))(); // Default 5 PM
  IntColumn get reminderMinute => integer().withDefault(const Constant(0))();
  BoolColumn get reminderRecurring => boolean().withDefault(const Constant(false))();
  
  /// Audit fields
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Sync tracking columns
  BoolColumn get needsUpload => boolean().withDefault(const Constant(false)).named('needs_upload')();
  DateTimeColumn get localUpdatedAt => dateTime().nullable().named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};
  
  @override
  String get tableName => 'feedback';
}
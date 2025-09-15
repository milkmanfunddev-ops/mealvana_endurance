import 'package:drift/drift.dart';

/// Table for storing user workout notes
/// These are local-only notes and do not sync to Supabase
@DataClassName('WorkoutNoteEntry')
class WorkoutNotesTable extends Table {
  /// Primary key - UUID
  TextColumn get id => text()();
  
  /// User ID - references user_profiles.id
  TextColumn get userId => text()();
  
  /// Optional reference to nutrition plan ID
  TextColumn get planId => text().nullable()();
  
  /// Note content
  TextColumn get noteText => text()();
  
  /// Optional rating associated with the note (1-5 scale)
  IntColumn get rating => integer().nullable()();
  
  /// When the note was created
  DateTimeColumn get createdAt => dateTime()();
  
  /// When the note was last updated
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
  
  @override
  String get tableName => 'workout_notes';
}
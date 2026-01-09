import 'package:drift/drift.dart';

/// Coaches table - stores coach profile and application information
/// Matches Supabase coaches table schema
@DataClassName('CoachEntry')
class CoachesTable extends Table {
  /// UUID primary key
  TextColumn get id => text()();

  /// References users.id - the user who is a coach
  TextColumn get userId => text().named('user_id')();

  /// Coach's first name
  TextColumn get firstName => text().named('first_name')();

  /// Coach's last name
  TextColumn get lastName => text().named('last_name')();

  /// Coach's email address
  TextColumn get email => text()();

  /// Coach's bio/description (optional)
  TextColumn get bio => text().nullable()();

  /// Application status: pending, approved, rejected
  TextColumn get applicationStatus =>
      text().withDefault(const Constant('pending')).named('application_status')();

  /// Admin who reviewed the application
  TextColumn get reviewedBy => text().nullable().named('reviewed_by')();

  /// When the application was reviewed
  DateTimeColumn get reviewedAt => dateTime().nullable().named('reviewed_at')();

  /// Reason for rejection (if status = rejected)
  TextColumn get rejectionReason => text().nullable().named('rejection_reason')();

  /// When the record was created
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the record was last updated
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'coaches';

  @override
  List<String> get customConstraints => [
        'UNIQUE(user_id)',
        "CHECK (application_status IN ('pending', 'approved', 'rejected'))",
        // Use length() for SQLite (char_length() is PostgreSQL only)
        'CHECK (length(trim(first_name)) >= 1)',
        'CHECK (length(trim(last_name)) >= 1)',
      ];
}

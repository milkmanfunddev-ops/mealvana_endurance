import 'package:drift/drift.dart';

/// Coaches table - stores coach profile information
/// Matches Supabase coaches table schema from coach mode migration
@DataClassName('CoachEntry')
class CoachesTable extends Table {
  /// UUID primary key
  TextColumn get id => text()();

  /// References users.id - the user who is a coach
  TextColumn get userId => text().unique().named('user_id')();

  /// References users.device_id - for device-based auth
  TextColumn get deviceId => text().unique().named('device_id')();

  /// Coach's display name (min 2 characters)
  TextColumn get coachName => text().named('coach_name')();

  /// Coach bio/description
  TextColumn get bio => text().nullable()();

  /// Certifications as comma-separated values (stored as PostgreSQL array format)
  TextColumn get certifications => text().withDefault(const Constant('{}')).named('certifications')();

  /// Specializations as comma-separated values (stored as PostgreSQL array format)
  TextColumn get specializations => text().withDefault(const Constant('{}')).named('specializations')();

  /// Business name (optional)
  TextColumn get businessName => text().nullable().named('business_name')();

  /// Website URL (optional)
  TextColumn get websiteUrl => text().nullable().named('website_url')();

  /// Contact email (optional)
  TextColumn get email => text().nullable()();

  /// Contact phone (optional)
  TextColumn get phone => text().nullable()();

  /// Whether coach is active and accepting athletes
  BoolColumn get isActive => boolean().withDefault(const Constant(true)).named('is_active')();

  /// Whether coach has been verified by admin
  BoolColumn get isVerified => boolean().withDefault(const Constant(false)).named('is_verified')();

  /// Maximum number of athletes coach can manage
  IntColumn get maxAthletes => integer().withDefault(const Constant(50)).named('max_athletes')();

  /// Whether to auto-accept athlete requests
  BoolColumn get autoAcceptRequests => boolean().withDefault(const Constant(false)).named('auto_accept_requests')();

  /// When the coach profile was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the coach profile was last updated
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'coaches';

  @override
  List<String> get customConstraints => [
    'UNIQUE(user_id)',
    'UNIQUE(device_id)',
    "CHECK (length(coach_name) >= 2)",
  ];
}

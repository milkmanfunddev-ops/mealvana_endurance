import 'package:drift/drift.dart';

/// Athlete pairing codes table - stores codes athletes generate for coach connections
/// Matches Supabase athlete_pairing_codes table schema
@DataClassName('AthletePairingCodeEntry')
class AthletePairingCodesTable extends Table {
  /// UUID primary key
  TextColumn get id => text()();

  /// References users.id - the athlete who generated the code
  TextColumn get userId => text().named('user_id')();

  /// 6-character alphanumeric pairing code
  TextColumn get code => text()();

  /// When the code was created
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the code expires (24h after creation)
  DateTimeColumn get expiresAt => dateTime().named('expires_at')();

  /// Coach who used this code (null if unused)
  TextColumn get usedByCoachId => text().nullable().named('used_by_coach_id')();

  /// When the code was used (null if unused)
  DateTimeColumn get usedAt => dateTime().nullable().named('used_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'athlete_pairing_codes';

  @override
  List<String> get customConstraints => ['UNIQUE(code)'];
}

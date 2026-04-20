import 'package:drift/drift.dart';

/// Coach pairing codes table - stores codes coaches generate for athlete connections
/// Matches Supabase coach_pairing_codes table schema
@DataClassName('CoachPairingCodeEntry')
class CoachPairingCodesTable extends Table {
  /// UUID primary key
  TextColumn get id => text()();

  /// References users.id - the coach who generated the code
  TextColumn get coachUserId => text().named('coach_user_id')();

  /// 6-character alphanumeric pairing code
  TextColumn get code => text()();

  /// When the code was created
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the code expires (24h after creation)
  DateTimeColumn get expiresAt => dateTime().named('expires_at')();

  /// Athlete who used this code (null if unused)
  TextColumn get usedByAthleteId =>
      text().nullable().named('used_by_athlete_id')();

  /// When the code was used (null if unused)
  DateTimeColumn get usedAt => dateTime().nullable().named('used_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'coach_pairing_codes';

  @override
  List<String> get customConstraints => [
        'UNIQUE(code)',
      ];
}

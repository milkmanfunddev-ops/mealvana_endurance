import 'package:drift/drift.dart';

/// Coach-athlete relationships table - tracks connections between coaches and athletes
/// Matches Supabase coach_athlete_relationships table schema (simplified)
@DataClassName('CoachAthleteRelationshipEntry')
class CoachAthleteRelationshipsTable extends Table {
  /// UUID primary key
  TextColumn get id => text()();

  /// References users.id - the coach user (user with is_coach=true)
  TextColumn get coachUserId => text().named('coach_user_id')();

  /// References users.id - the athlete user
  TextColumn get athleteUserId => text().named('athlete_user_id')();

  /// Relationship status: pending, active, declined, archived
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Who initiated the relationship: 'coach' or 'athlete'
  TextColumn get requestedBy => text().named('requested_by')();

  /// When the request was made
  DateTimeColumn get requestedAt =>
      dateTime().withDefault(currentDateAndTime).named('requested_at')();

  /// When the relationship was accepted (null if pending/declined)
  DateTimeColumn get acceptedAt =>
      dateTime().nullable().named('accepted_at')();

  /// When the relationship was declined (null if not declined)
  DateTimeColumn get declinedAt =>
      dateTime().nullable().named('declined_at')();

  /// When the relationship was archived (null if not archived)
  DateTimeColumn get archivedAt =>
      dateTime().nullable().named('archived_at')();

  /// When the record was created
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the record was last updated
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'coach_athlete_relationships';

  @override
  List<String> get customConstraints => [
        'UNIQUE(coach_user_id, athlete_user_id)',
        "CHECK (status IN ('pending', 'active', 'declined', 'archived'))",
        "CHECK (requested_by IN ('coach', 'athlete'))",
        "CHECK (coach_user_id != athlete_user_id)",
      ];
}

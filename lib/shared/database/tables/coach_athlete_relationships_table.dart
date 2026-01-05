import 'package:drift/drift.dart';

/// Coach-athlete relationships table - tracks connections between coaches and athletes
/// Matches Supabase coach_athlete_relationships table schema
@DataClassName('CoachAthleteRelationshipEntry')
class CoachAthleteRelationshipsTable extends Table {
  /// UUID primary key
  TextColumn get id => text()();

  /// References coaches.id - the coach in this relationship
  TextColumn get coachId => text().named('coach_id')();

  /// References users.id - the athlete user
  TextColumn get athleteUserId => text().named('athlete_user_id')();

  /// References users.device_id - the athlete's device
  TextColumn get athleteDeviceId => text().named('athlete_device_id')();

  /// Relationship status: pending, active, declined, archived
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Permission level: view_only, full_access, custom
  TextColumn get permissionLevel => text().withDefault(const Constant('view_only')).named('permission_level')();

  /// Custom permissions as JSON when permission_level = 'custom'
  TextColumn get customPermissions => text().withDefault(const Constant('''
{
  "view_activities": true,
  "view_nutrition_plans": true,
  "view_completions": true,
  "view_notes": true,
  "view_food_preferences": false,
  "create_activities": false,
  "create_nutrition_plans": false,
  "modify_activities": false,
  "modify_nutrition_plans": false,
  "delete_activities": false,
  "delete_nutrition_plans": false,
  "add_notes": true
}''')).named('custom_permissions')();

  /// Who initiated the relationship: 'coach' or 'athlete'
  TextColumn get requestedBy => text().named('requested_by')();

  /// When the request was made
  DateTimeColumn get requestedAt => dateTime().withDefault(currentDateAndTime).named('requested_at')();

  /// When the relationship was accepted (null if pending/declined)
  DateTimeColumn get acceptedAt => dateTime().nullable().named('accepted_at')();

  /// When the relationship was declined (null if not declined)
  DateTimeColumn get declinedAt => dateTime().nullable().named('declined_at')();

  /// When the relationship was archived (null if not archived)
  DateTimeColumn get archivedAt => dateTime().nullable().named('archived_at')();

  /// Coach's private notes about this athlete
  TextColumn get coachNotes => text().nullable().named('coach_notes')();

  /// Athlete's notes about this coach
  TextColumn get athleteNotes => text().nullable().named('athlete_notes')();

  /// Invitation token for accepting invitations via link
  TextColumn get invitationToken => text().nullable().unique().named('invitation_token')();

  /// When the invitation token expires
  DateTimeColumn get invitationExpiresAt => dateTime().nullable().named('invitation_expires_at')();

  /// When the record was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the record was last updated
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'coach_athlete_relationships';

  @override
  List<String> get customConstraints => [
    'UNIQUE(coach_id, athlete_user_id)',
    "CHECK (status IN ('pending', 'active', 'declined', 'archived'))",
    "CHECK (permission_level IN ('view_only', 'full_access', 'custom'))",
    "CHECK (requested_by IN ('coach', 'athlete'))",
  ];
}

import 'package:drift/drift.dart';

/// Coach messages table - bidirectional messaging between coaches and athletes
/// Also used for comments on nutrition plans and activities
/// Matches Supabase coach_messages table schema
@DataClassName('CoachMessageEntry')
class CoachMessagesTable extends Table {
  /// UUID primary key
  TextColumn get id => text()();

  /// References users.id - the coach user in this conversation
  TextColumn get coachUserId => text().named('coach_user_id')();

  /// References users.id - the athlete user in this conversation
  TextColumn get athleteUserId => text().named('athlete_user_id')();

  /// References users.id - who sent this specific message
  TextColumn get senderUserId => text().named('sender_user_id')();

  /// The message content
  TextColumn get messageText => text().named('message_text')();

  /// Optional link to a nutrition plan (no FK - plans stored in activity.nutrition_plan_data JSON)
  TextColumn get nutritionPlanId =>
      text().nullable().named('nutrition_plan_id')();

  /// Optional link to an activity (references activities.id)
  TextColumn get activityId => text().nullable().named('activity_id')();

  /// Whether the message has been read by the recipient
  BoolColumn get isRead =>
      boolean().withDefault(const Constant(false)).named('is_read')();

  /// When the message was created
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the message was last updated
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'coach_messages';

  @override
  List<String> get customConstraints => [
        // Sender must be either the coach or the athlete in this conversation
        "CHECK (sender_user_id IN (coach_user_id, athlete_user_id))",
        // Message text must not be empty
        "CHECK (length(trim(message_text)) > 0)",
      ];
}

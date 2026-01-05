import 'package:drift/drift.dart';

/// Coach feedback table - stores feedback/notes from coaches to athletes
/// Matches Supabase coach_feedback table schema
@DataClassName('CoachFeedbackEntry')
class CoachFeedbackTable extends Table {
  /// UUID primary key
  TextColumn get id => text()();

  /// References coach_athlete_relationships.id - the relationship this feedback belongs to
  TextColumn get relationshipId => text().named('relationship_id')();

  /// References coaches.id - the coach who created the feedback
  TextColumn get coachId => text().named('coach_id')();

  /// References users.id - the athlete user receiving feedback
  TextColumn get athleteUserId => text().named('athlete_user_id')();

  /// Optional link to specific activity (references activities.id)
  TextColumn get activityId => text().nullable().named('activity_id')();

  /// Optional link to specific nutrition plan (references nutrition_plans.id)
  TextColumn get nutritionPlanId => text().nullable().named('nutrition_plan_id')();

  /// The feedback content (min 1 character)
  TextColumn get feedbackText => text().named('feedback_text')();

  /// Type of feedback: general, activity, nutrition, progress, goal
  TextColumn get feedbackType => text().withDefault(const Constant('general')).named('feedback_type')();

  /// Controls whether athlete can see this feedback
  BoolColumn get isVisibleToAthlete => boolean().withDefault(const Constant(true)).named('is_visible_to_athlete')();

  /// When the feedback was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the feedback was last updated
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'coach_feedback';

  @override
  List<String> get customConstraints => [
    "CHECK (feedback_type IN ('general', 'activity', 'nutrition', 'progress', 'goal'))",
    "CHECK (length(feedback_text) >= 1)",
    // Linked entity constraint: either activity_id OR nutrition_plan_id can be set, but not both
    "CHECK ((activity_id IS NOT NULL AND nutrition_plan_id IS NULL) OR (activity_id IS NULL AND nutrition_plan_id IS NOT NULL) OR (activity_id IS NULL AND nutrition_plan_id IS NULL))",
  ];
}

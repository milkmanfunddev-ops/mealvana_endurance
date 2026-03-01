import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Table for tracking TrainingPeaks write-back state per workout.
/// Records when a nutrition plan summary was pushed to a TP workout description.
@DataClassName('TpWritebackEntry')
class TpWritebackTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().named('user_id')();
  TextColumn get activityId => text().named('activity_id')();
  IntColumn get tpWorkoutId => integer().named('tp_workout_id')();
  TextColumn get planHash => text().named('plan_hash')();
  DateTimeColumn get pushedAt => dateTime().named('pushed_at')();
  TextColumn get status => text()(); // 'active', 'failed'
  TextColumn get lastError => text().nullable().named('last_error')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'tp_writeback_log';

  @override
  List<String> get customConstraints => [
    'UNIQUE(user_id, tp_workout_id)',
    "CHECK (status IN ('active', 'failed'))",
  ];
}

import 'package:drift/drift.dart';

/// Daily macro targets table definition for Drift
/// Caches calculated daily macro targets locally
@DataClassName('DailyMacroTargetEntry')
class DailyMacroTargetsTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().named('user_id')();
  DateTimeColumn get targetDate => dateTime().named('target_date')();
  RealColumn get carbG => real().named('carb_g')();
  RealColumn get protG => real().named('prot_g')();
  RealColumn get fatG => real().named('fat_g')();
  RealColumn get tdee => real()();
  RealColumn get rmr => real()();
  RealColumn get sessionKcal => real().withDefault(const Constant(0)).named('session_kcal')();
  RealColumn get neatKcal => real().nullable().named('neat_kcal')();
  RealColumn get tefKcal => real().nullable().named('tef_kcal')();
  TextColumn get mode => text().withDefault(const Constant('prospective'))();
  RealColumn get ea => real().nullable()();
  TextColumn get eaStatus => text().nullable().named('ea_status')();
  TextColumn get calculationInput => text().nullable().named('calculation_input')();
  TextColumn get algorithmVersion => text().withDefault(const Constant('v4')).named('algorithm_version')();
  BoolColumn get needsUpload => boolean().withDefault(const Constant(false)).named('needs_upload')();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'daily_macro_targets';

  @override
  List<String> get customConstraints => [
    'UNIQUE(user_id, target_date)',
  ];
}

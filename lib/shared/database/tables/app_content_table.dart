import 'package:drift/drift.dart';

/// App content table - dynamic content management system
@DataClassName('AppContentEntry')
class AppContentTable extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get environment => text().withDefault(const Constant('production'))();
  TextColumn get locale => text().withDefault(const Constant('en'))();
  TextColumn get content => text()(); // JSON content
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get createdBy => text().nullable()();
  TextColumn get updatedBy => text().nullable()();
  
  // Sync metadata
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  BoolColumn get isCached => boolean().withDefault(const Constant(false))();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<String> get customConstraints => [
    'CHECK(environment IN (\'production\', \'staging\', \'development\'))',
    'CHECK(version > 0)',
  ];
}
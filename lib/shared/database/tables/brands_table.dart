import 'package:drift/drift.dart';

/// Brands table - brand information for affiliate marketing
@DataClassName('BrandEntry')
class BrandsTable extends Table {
  TextColumn get id => text().withLength(min: 1, max: 50)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get websiteUrl => text().nullable()();
  TextColumn get affiliateProgramUrl => text().nullable()();
  TextColumn get affiliateNetwork => text().nullable()();
  TextColumn get defaultAffiliateUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<String> get customConstraints => [
    'UNIQUE(name)', // Unique brand names
  ];
}
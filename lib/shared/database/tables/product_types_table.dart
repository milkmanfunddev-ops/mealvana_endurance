import 'package:drift/drift.dart';

/// Product types table - standardized food product type categorization (matches Supabase schema)
@DataClassName('ProductTypeEntry')
class ProductTypesTable extends Table {
  /// UUID primary key (matches Supabase product_types.id)
  TextColumn get id => text().withLength(min: 36, max: 36)();

  /// Product type code (unique, matches Supabase product_types.code)
  TextColumn get code => text()();

  /// Display name singular (matches Supabase product_types.name)
  TextColumn get name => text()();

  /// Display name plural (matches Supabase product_types.name_plural)
  TextColumn get namePlural => text().named('name_plural')();

  /// Sort order for UI display (matches Supabase product_types.sort_order)
  IntColumn get sortOrder => integer().nullable().named('sort_order')();

  /// When the product type was created (matches Supabase product_types.created_at)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE(code)', // Ensure code is unique
  ];
}
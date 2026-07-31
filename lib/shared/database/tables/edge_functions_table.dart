import 'package:drift/drift.dart';

/// Edge functions table definition for Drift - matches Supabase edge_functions table schema
/// Stores dynamic Edge Function code for serverless deployment
@DataClassName('EdgeFunctionEntry')
class EdgeFunctionsTable extends Table {
  /// UUID primary key (matches Supabase edge_functions.id)
  TextColumn get id => text().withLength(min: 36, max: 36)();

  /// Function name (unique identifier)
  TextColumn get name => text().unique()();

  /// Function code (JavaScript/TypeScript source)
  TextColumn get code => text()();

  /// When the function was created (matches Supabase edge_functions.created_at)
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();

  /// When the function was last updated (matches Supabase edge_functions.updated_at)
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE(name)', // Ensure function names are unique
  ];
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_database.dart';

part 'database_provider.g.dart';

/// Provider for the main app database
/// This ensures a single database instance across the app
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  return AppDatabase();
}

/// Provider for database operations
/// Makes it easy to access database methods throughout the app
@riverpod
Future<AppDatabase> database(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  
  // Ensure database is ready by performing a simple check
  try {
    await db.getDatabaseStats();
    return db;
  } catch (e) {
    print('Database initialization error: $e');
    rethrow;
  }
}
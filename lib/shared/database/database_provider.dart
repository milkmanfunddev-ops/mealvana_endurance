import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

/// Provider for the main app database
/// This ensures a single database instance across the app
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Provider for database operations
/// Makes it easy to access database methods throughout the app
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  
  // Ensure database is ready by performing a simple check
  try {
    await db.getDatabaseStats();
    return db;
  } catch (e) {
    print('Database initialization error: $e');
    rethrow;
  }
});
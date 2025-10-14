import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import '../services/logging_service.dart';

/// Provider for the main app database
/// This ensures a single database instance across the app
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return AppDatabase(logger: logger);
});

/// Provider for database operations
/// Makes it easy to access database methods throughout the app
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final logger = ref.watch(appLoggerProvider);
  
  // Ensure database is ready by performing a simple check
  try {
    await db.getDatabaseStats();
    return db;
  } catch (e) {
    logger.error(
      'Database initialization error',
      context: 'DATABASE',
      error: e,
    );
    rethrow;
  }
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

/// Provider for the main app database
/// This ensures a single database instance across the app
///
/// IMPORTANT: The database is ready immediately - Drift's LazyDatabase handles
/// async initialization internally. No need for a FutureProvider wrapper.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// DEPRECATED: Use appDatabaseProvider directly instead
/// This FutureProvider caused deadlocks and race conditions
@Deprecated('Use appDatabaseProvider directly - database is ready immediately')
final databaseProvider = Provider<AppDatabase>((ref) {
  // Just return the same instance - no async needed
  return ref.watch(appDatabaseProvider);
});

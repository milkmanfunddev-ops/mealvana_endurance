// Web platform database connection implementation using drift_web
import 'package:drift/drift.dart';
import 'package:drift/web.dart';
import 'package:flutter/foundation.dart';

/// Web platform connection using sql.js (JavaScript SQLite via drift_web)
/// This approach is simpler than WasmDatabase and requires no additional WASM files.
LazyDatabase openNativeConnection() {
  return LazyDatabase(() async {
    // WebDatabase uses sql.js (JavaScript SQLite) with IndexedDB for persistence
    // This is the simplest web database setup - no WASM files needed
    final db = WebDatabase('mealvana_db', logStatements: kDebugMode);

    if (kDebugMode) {
      debugPrint('[DRIFT_WEB] Using WebDatabase with sql.js + IndexedDB storage');
    }

    return db;
  });
}

/// Create in-memory web database for testing
QueryExecutor createNativeMemoryDatabase() {
  // Use volatile storage for testing (data not persisted)
  return WebDatabase.withStorage(
    DriftWebStorage.volatile(),
    logStatements: kDebugMode,
  );
}

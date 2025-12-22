// Web platform database connection implementation
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

/// Web platform connection using WebAssembly SQLite
LazyDatabase openNativeConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'mealvana_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );

    if (kDebugMode && result.missingFeatures.isNotEmpty) {
      debugPrint('[DRIFT_WEB] Storage: ${result.chosenImplementation}');
      debugPrint('[DRIFT_WEB] Missing features: ${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  });
}

/// Create in-memory web database for testing
QueryExecutor createNativeMemoryDatabase() {
  return LazyDatabase(() async {
    // Note: WasmDatabase automatically uses ephemeral storage in memory
    // when IndexedDB is not available or for testing purposes
    final result = await WasmDatabase.open(
      databaseName: 'test_db_${DateTime.now().millisecondsSinceEpoch}',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    return result.resolvedExecutor;
  });
}

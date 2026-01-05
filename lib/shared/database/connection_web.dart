// Web platform database connection implementation using WasmDatabase (stable API)
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

/// Web platform connection using WasmDatabase.open (stable API since drift 2.9.0)
/// Requires sqlite3.wasm and drift_worker.js in the web/ folder.
///
/// See: https://drift.simonbinder.eu/platforms/web/
LazyDatabase openNativeConnection() {
  return LazyDatabase(() async {
    if (kDebugMode) {
      debugPrint('[DRIFT_WEB] Opening WasmDatabase...');
    }

    final result = await WasmDatabase.open(
      databaseName: 'mealvana_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    if (kDebugMode) {
      debugPrint('[DRIFT_WEB] Database opened successfully');
      debugPrint('[DRIFT_WEB] Storage implementation: ${result.chosenImplementation}');
      if (result.missingFeatures.isNotEmpty) {
        debugPrint('[DRIFT_WEB] Missing browser features: ${result.missingFeatures}');
      }
    }

    return result.resolvedExecutor;
  });
}

/// Create in-memory web database for testing
QueryExecutor createNativeMemoryDatabase() {
  // For web testing, use a simple in-memory database
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'test_db_${DateTime.now().millisecondsSinceEpoch}',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}

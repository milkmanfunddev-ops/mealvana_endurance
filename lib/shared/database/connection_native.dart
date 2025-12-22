// Native (iOS/Android) database connection implementation
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';

/// Native platforms (iOS/Android) connection using SQLite file
LazyDatabase openNativeConnection() {
  return LazyDatabase(() async {
    // Put the database file in the documents directory
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'mealvana_endurance_db.sqlite'));

    // Also work around limitations on old Android versions
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Make sqlite3 pick a more suitable location for temporary files
    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    // Use background isolate for database operations in all modes
    // This prevents blocking the main thread during database init (was causing 7+ second UI freeze)
    // NOTE: SQL logging disabled - was causing 77% of debug log volume
    // Set logStatements to true only when debugging specific database issues
    final db = NativeDatabase.createInBackground(file);

    return db;
  });
}

/// Create in-memory native database for testing
QueryExecutor createNativeMemoryDatabase() {
  return NativeDatabase.memory();
}

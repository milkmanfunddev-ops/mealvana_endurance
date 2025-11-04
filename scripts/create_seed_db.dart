// Script to create seed database with empty schema
// Run with: dart run scripts/create_seed_db.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;

// Import the app database to get schema
import '../lib/shared/database/app_database.dart';

Future<void> main() async {
  print('Creating seed database...');

  // Path to seed database
  final seedDbPath = path.join(
    Directory.current.path,
    'assets',
    'data',
    'app_seed.db',
  );

  // Delete existing seed database if it exists
  final seedDbFile = File(seedDbPath);
  if (await seedDbFile.exists()) {
    await seedDbFile.delete();
    print('Deleted existing seed database');
  }

  // Ensure directory exists
  await seedDbFile.parent.create(recursive: true);

  // Create database with schema
  final database = AppDatabase(NativeDatabase(seedDbFile));

  print('Seed database created at: $seedDbPath');
  print('Schema version: ${database.schemaVersion}');

  // Close database
  await database.close();

  print('✅ Seed database created successfully!');
  print('Next step: Import food data from Supabase');
}

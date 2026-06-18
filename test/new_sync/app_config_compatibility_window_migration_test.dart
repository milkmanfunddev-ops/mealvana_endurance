import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('app_config compatibility window migration', () {
    const migrationPath =
        'supabase/migrations/_archived/20260310153000_add_schema_compatibility_window_config.sql';

    test('migration file exists', () {
      final migrationFile = File(migrationPath);
      expect(migrationFile.existsSync(), isTrue);
    });

    test('migration inserts compatibility window keys', () {
      final migrationFile = File(migrationPath);
      final content = migrationFile.readAsStringSync();

      expect(content, contains("'latest_schema_version'"));
      expect(content, contains("'min_supported_schema_version'"));
      expect(content, contains("WHERE key = 'current_schema_version'"));
      expect(content, contains('ON CONFLICT (key) DO NOTHING'));
    });
  });
}

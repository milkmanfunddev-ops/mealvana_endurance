import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('app_config migration', () {
    test('migration file exists', () {
      final migrationFile = File(
        'supabase/migrations/_archived/20260118_create_app_config_table.sql',
      );
      expect(migrationFile.existsSync(), isTrue,
          reason: 'Migration file should exist');
    });

    test('migration contains required SQL statements', () {
      final migrationFile = File(
        'supabase/migrations/_archived/20260118_create_app_config_table.sql',
      );
      final content = migrationFile.readAsStringSync();

      // Verify table creation
      expect(content, contains('CREATE TABLE IF NOT EXISTS app_config'));

      // Verify required columns
      expect(content, contains('id UUID PRIMARY KEY'));
      expect(content, contains('key TEXT NOT NULL UNIQUE'));
      expect(content, contains('value TEXT NOT NULL'));
      expect(content, contains('description TEXT'));
      expect(content, contains('updated_at TIMESTAMPTZ'));

      // Verify RLS is enabled
      expect(content, contains('ENABLE ROW LEVEL SECURITY'));

      // Verify RLS policies
      expect(content, contains('Allow public read access'));
      expect(content, contains('Allow service role to manage'));

      // Verify initial data
      expect(content, contains("'min_app_version'"));
      expect(content, contains("'current_schema_version'"));
      expect(content, contains("'maintenance_mode'"));
      expect(content, contains("'force_resync_before'"));

      // Verify trigger for updated_at
      expect(content, contains('update_app_config_updated_at'));
      expect(content, contains('CREATE TRIGGER app_config_updated_at'));
    });

    test('migration has valid initial values', () {
      final migrationFile = File(
        'supabase/migrations/_archived/20260118_create_app_config_table.sql',
      );
      final content = migrationFile.readAsStringSync();

      // Verify initial values are set correctly
      expect(content, contains("'min_app_version', '1.12.0'"));
      expect(content, contains("'current_schema_version', '3'"));
      expect(content, contains("'maintenance_mode', 'false'"));

      // Verify INSERT uses ON CONFLICT to prevent duplicate key errors
      expect(content, contains('ON CONFLICT (key) DO NOTHING'));
    });

    test('migration uses best practices', () {
      final migrationFile = File(
        'supabase/migrations/_archived/20260118_create_app_config_table.sql',
      );
      final content = migrationFile.readAsStringSync();

      // Should use IF NOT EXISTS for idempotency
      expect(content, contains('IF NOT EXISTS'));

      // Should have comments for documentation
      expect(content, contains('COMMENT ON TABLE'));
      expect(content, contains('COMMENT ON COLUMN'));

      // Should have index for performance
      expect(content, contains('CREATE INDEX'));
      expect(content, contains('idx_app_config_key'));
    });
  });
}

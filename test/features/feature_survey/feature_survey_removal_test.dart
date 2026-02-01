import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

/// Verification test to ensure feature_survey code has been completely removed.
///
/// This test scans the lib directory (excluding generated files) to verify
/// that no imports or references to feature_survey remain in the codebase.
void main() {
  group('Feature Survey Removal Verification', () {
    test('should not find any feature_survey imports in lib directory', () async {
      // Get the project root directory
      final currentDir = Directory.current;
      final libDir = Directory('${currentDir.path}/lib');

      expect(libDir.existsSync(), isTrue, reason: 'lib directory should exist');

      // Find all .dart files in lib directory (excluding generated files)
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.contains('.g.dart')) // Exclude generated files
          .where((file) => !file.path.contains('schema_versions.dart')) // Exclude schema versions (generated)
          .toList();

      expect(dartFiles.isNotEmpty, isTrue, reason: 'Should find Dart files in lib directory');

      // Check each file for feature_survey references
      final filesWithFeatureSurvey = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();

        // Check for feature_survey imports or references
        if (content.contains('feature_survey')) {
          filesWithFeatureSurvey.add(file.path);
        }
      }

      // Assert no files contain feature_survey references
      expect(
        filesWithFeatureSurvey,
        isEmpty,
        reason: 'No files should contain feature_survey references.\n'
            'Found in: ${filesWithFeatureSurvey.join('\n')}',
      );
    });

    test('should not find feature_survey directory in lib/features', () {
      final currentDir = Directory.current;
      final featureSurveyDir = Directory('${currentDir.path}/lib/features/feature_survey');

      expect(
        featureSurveyDir.existsSync(),
        isFalse,
        reason: 'feature_survey directory should be deleted',
      );
    });

    test('should not find feature_survey_responses_table.dart', () {
      final currentDir = Directory.current;
      final tableFile = File('${currentDir.path}/lib/shared/database/tables/feature_survey_responses_table.dart');

      expect(
        tableFile.existsSync(),
        isFalse,
        reason: 'feature_survey_responses_table.dart should be deleted',
      );
    });

    test('should not find feature_survey in upload-all-data edge function', () async {
      final currentDir = Directory.current;
      final edgeFunctionFile = File('${currentDir.path}/supabase/functions/upload-all-data/index.ts');

      if (!edgeFunctionFile.existsSync()) {
        // Skip test if edge function doesn't exist
        return;
      }

      final content = edgeFunctionFile.readAsStringSync();

      // Check for feature_survey_responses in the TypeScript interface
      expect(
        content.contains('feature_survey_responses'),
        isFalse,
        reason: 'upload-all-data edge function should not reference feature_survey_responses',
      );
    });
  });
}

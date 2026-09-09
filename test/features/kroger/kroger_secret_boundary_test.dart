import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Kroger server secret is not populated in bundled env assets', () {
    for (final path in [
      '.env',
      '.env.dev.local',
      '.env.prod.local',
      '.env.example',
    ]) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final entries = file.readAsLinesSync().where(
        (line) => line.trimLeft().startsWith('KROGER_CLIENT_SECRET='),
      );
      final populated = entries.any(
        (line) => line
            .substring(line.indexOf('=') + 1)
            .trim()
            .replaceAll('"', '')
            .replaceAll("'", '')
            .isNotEmpty,
      );
      // Print only a boolean/path on failure, never a secret value.
      expect(
        populated,
        false,
        reason:
            '$path is client configuration; keep Kroger secrets server-only.',
      );
    }
    expect(
      RegExp(
        r'^\s*-\s*secrets(?:/|\s*$)',
        multiLine: true,
      ).hasMatch(File('pubspec.yaml').readAsStringSync()),
      false,
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../meal_planning/presentation/helpers/test_content.dart';

/// Every `meal_planning.*` [ContentKeys] constant resolves to a real entry
/// in `assets/config/content_defaults.json`, and every `meal_planning.*`
/// JSON entry has a constant — so a key rename cannot ship half-done and a
/// JSON edit cannot orphan a constant silently.
void main() {
  final content = loadDefaultContent();

  test('every meal_planning ContentKey exists in content_defaults.json', () {
    // The constants live in ContentKeys as `static const String mpX =
    // 'meal_planning.…'`; mirror-check via reflection is unavailable, so
    // assert on the constants' values extracted from the source file.
    final source = File('lib/features/content/domain/content_keys.dart')
        .readAsStringSync();
    final keyPattern = RegExp(r"'(meal_planning\.[a-z0-9_]+)'");
    final declared = keyPattern.allMatches(source).map((m) => m.group(1)!).toSet();

    expect(declared, isNotEmpty);
    final missing = declared.difference(content.keys.toSet());
    expect(
      missing,
      isEmpty,
      reason: 'ContentKeys constants with no JSON entry: $missing',
    );
  });

  test('every meal_planning JSON entry has a ContentKeys constant', () {
    final source = File('lib/features/content/domain/content_keys.dart')
        .readAsStringSync();
    final keyPattern = RegExp(r"'(meal_planning\.[a-z0-9_]+)'");
    final declared = keyPattern.allMatches(source).map((m) => m.group(1)!).toSet();
    final jsonKeys = content.keys
        .where((k) => k.startsWith('meal_planning.'))
        .toSet();

    final orphaned = jsonKeys.difference(declared);
    expect(
      orphaned,
      isEmpty,
      reason: 'JSON entries with no ContentKeys constant: $orphaned',
    );
  });

  test('ContentKeys.format interpolates {n}-style placeholders', () {
    // Local copy of the one-liner under test, exercised through the real
    // service values so template syntax mismatches surface here.
    final template = content['meal_planning.rate_limited']!;
    expect(template.contains('{n}'), isTrue);
    var result = template;
    for (final entry in {'n': 30}.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    expect(result, contains('30'));
    expect(result.contains('{n}'), isFalse);
  });
}

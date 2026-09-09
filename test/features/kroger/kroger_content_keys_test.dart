import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/kroger/domain/kroger_messages.dart';

import '../meal_planning/presentation/helpers/test_content.dart';

/// Kroger's copy is declared like every other feature's: a typed constant per
/// key, with `assets/config/content_defaults.json` as the other half of the
/// pair. These tests keep the two halves honest, and keep the screen from
/// going back to assembling keys out of bare strings at the call site.
void main() {
  final content = loadDefaultContent();
  final keysSource = File(
    'lib/features/content/domain/content_keys.dart',
  ).readAsStringSync();
  final declared = RegExp(
    r"'(kroger\.[a-z0-9_]+)'",
  ).allMatches(keysSource).map((m) => m.group(1)!).toSet();

  test('every kroger ContentKey exists in content_defaults.json', () {
    expect(declared, isNotEmpty);
    expect(
      declared.difference(content.keys.toSet()),
      isEmpty,
      reason: 'ContentKeys constants with no JSON entry',
    );
  });

  test('every kroger JSON entry has a ContentKeys constant', () {
    final jsonKeys = content.keys.where((k) => k.startsWith('kroger.')).toSet();
    expect(
      jsonKeys.difference(declared),
      isEmpty,
      reason: 'JSON entries with no ContentKeys constant',
    );
  });

  test('no Kroger copy is looked up by a bare string, anywhere in lib', () {
    // `getValue('kroger.$key')` is how this screen used to look copy up, and
    // it is what made a typo indistinguishable from a missing key. A spelled
    // out `'kroger.title'` is the same mistake written differently, and the
    // entry point into the feature lives outside lib/features/kroger — so
    // scan all of lib, exempting the registry that has to spell keys itself.
    // Only lookup sites: a `'kroger.…'` reaching getValue or krogerText.
    // Preference keys and widget ValueKeys share the prefix and are not copy.
    final bare = [
      RegExp(r"getValue\(\s*'kroger\."),
      RegExp(r"krogerText\([^)]*'kroger\."),
      RegExp(r"'kroger\.\$"),
    ];
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.path != 'lib/features/content/domain/content_keys.dart')
        .where((f) => bare.any((p) => p.hasMatch(f.readAsStringSync())))
        .map((f) => f.path)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'these name a content key instead of using ContentKeys',
    );
  });

  group('krogerMessageKey', () {
    test('resolves every code the app can raise', () {
      // The codes KrogerException carries, read from the source rather than
      // copied, so a new throw site cannot quietly lose its explanation.
      final thrown = RegExp(r"KrogerException\('([a-z_]+)'\)")
          .allMatches(
            Directory('lib/features/kroger')
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))
                .map((f) => f.readAsStringSync())
                .join('\n'),
          )
          .map((m) => m.group(1)!)
          .toSet();

      expect(thrown, contains('reconnect_required'));
      for (final code in thrown) {
        final key = krogerMessageKey(code);
        expect(key, isNotNull, reason: 'no content key for "$code"');
        expect(content, contains(key), reason: 'no copy for "$code"');
      }
    });

    test('resolves the codes the edge function returns', () {
      // Codes a shopper can act on. The rest — invalid_body and its kin —
      // describe a malformed request and deliberately have no copy.
      for (final code in const [
        'connection_busy',
        'invalid_items',
        'invalid_zip',
        'kroger_unavailable',
        'not_configured',
        'plan_not_found',
        'pro_required',
        'product_unavailable',
        'rate_limited',
        'storage_unavailable',
      ]) {
        expect(content, contains(krogerMessageKey(code)), reason: code);
      }
    });

    test('returns null for a code it has nothing to say about', () {
      expect(krogerMessageKey('invalid_token_response'), isNull);
      expect(krogerMessageKey('nonsense'), isNull);
    });
  });
}

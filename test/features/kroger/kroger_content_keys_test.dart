import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
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

    test('resolves every code the edge function can return', () {
      // Read from the function's source, like the app's own codes above, so a
      // server code added without copy fails here rather than on a device.
      // The auth and entitlement helpers are the kroger function's imports
      // that answer on its behalf (`unauthenticated`, `pro_required`).
      // It sees string literals only: a code passed through a constant, or
      // raised from a module outside these files, has to be added by hand.
      final sources = [
        File('supabase/functions/kroger/index.ts'),
        ...Directory('supabase/functions/_shared/kroger')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.ts'))
            .where((f) => !f.path.endsWith('_test.ts')),
        File('supabase/functions/_shared/vana/auth.ts'),
        File('supabase/functions/_shared/vana/entitlement.ts'),
      ].map((f) => f.readAsStringSync()).join('\n');
      final literal = RegExp(r"""["']([a-z_]+)["']""");
      final codes = {
        // `new KrogerError(...)`, including a ternary choosing between codes.
        for (final call in RegExp(
          r'KrogerError\(([^)]*)\)',
        ).allMatches(sources))
          for (final m in literal.allMatches(call.group(1)!)) m.group(1)!,
        // `{ error: '…' }` responses and `reason: '…'` results.
        for (final m in RegExp(
          r"""(?:error|reason): ["']([a-z_]+)["']""",
        ).allMatches(sources))
          m.group(1)!,
      };

      expect(
        codes,
        containsAll(const [
          'invalid_action',
          'invalid_body',
          'unauthenticated',
          'pro_required',
          'kroger_unavailable',
          'reconnect_required',
          'invalid_token_response',
        ]),
        reason: 'the scan no longer finds the codes it was written against',
      );
      for (final code in codes) {
        final key = krogerMessageKey(code);
        expect(key, isNotNull, reason: 'no content key for "$code"');
        expect(content, contains(key), reason: 'no copy for "$code"');
      }
    });

    test('returns null for a code it has nothing to say about', () {
      expect(krogerMessageKey('nonsense'), isNull);
    });
  });

  group('only a failure to reach Kroger says Kroger could not be reached', () {
    const unreachable = 'Kroger could not be reached';

    test('a request this app built wrong does not blame Kroger', () {
      // Version skew and malformed requests: Mealvana's own fault, and
      // nothing the shopper can do differently about any of them.
      for (final code in const [
        'invalid_action',
        'invalid_body',
        'invalid_input',
        'invalid_id',
        'invalid_modality',
        'invalid_token_response',
        'method_not_allowed',
        'internal_error',
        'unexpected',
      ]) {
        final key = krogerMessageKey(code);
        expect(key, ContentKeys.krogerUnexpected, reason: code);
        expect(content[key], isNot(contains(unreachable)), reason: code);
      }
    });

    test('an expired Mealvana session asks for a sign-in', () {
      expect(krogerMessageKey('unauthenticated'), ContentKeys.krogerSignedOut);
      expect(content[ContentKeys.krogerSignedOut], contains('Sign in'));
      expect(
        content[ContentKeys.krogerSignedOut],
        isNot(contains(unreachable)),
      );
    });

    test(
      'Kroger failing and the network failing still say so, differently',
      () {
        final upstream = content[krogerMessageKey('kroger_unavailable')]!;
        final network = content[krogerMessageKey('unavailable')]!;
        expect(upstream, contains(unreachable));
        expect(network, contains(unreachable));
        expect(upstream, isNot(network));
      },
    );
  });
}

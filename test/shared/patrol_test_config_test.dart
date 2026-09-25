// Patrol's TestConfig takes the Supabase project from the run's env file and
// has no built-in fallback: a baked-in dev anon key went stale when dev's
// keys changed, and every auth call in a bare `patrol test` failed with
// "Invalid API key" (Finding 02-007). A run with no env file must fail at
// launch, saying which file to pass.
//
// Plain Dart: test_config.dart imports nothing, so no device is involved.
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/helpers/test_config.dart';

void main() {
  group('TestConfig Supabase env', () {
    test(
      'has no default project: without an env file both values are empty',
      () {
        expect(TestConfig.supabaseUrl, isEmpty);
        expect(TestConfig.supabaseAnonKey, isEmpty);
      },
      skip:
          const bool.hasEnvironment('SUPABASE_ANON_KEY') ||
              const bool.hasEnvironment('SUPABASE_URL')
          ? 'this run passed the Supabase env as dart-defines'
          : false,
    );

    test('a run with neither value fails with the env file to pass', () {
      expect(
        () => TestConfig.requireSupabaseEnv(url: '', anonKey: ''),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('SUPABASE_URL'),
              contains('SUPABASE_ANON_KEY'),
              contains('--dart-define-from-file=.env.dev.local'),
            ),
          ),
        ),
      );
    });

    test('a missing anon key alone is named on its own', () {
      expect(
        () => TestConfig.requireSupabaseEnv(
          url: 'https://vlmtsdzpnjnavdgytcmi.supabase.co',
          anonKey: '',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('SUPABASE_ANON_KEY'),
              isNot(contains('SUPABASE_URL,')),
            ),
          ),
        ),
      );
    });

    test('a run with both values passes', () {
      expect(
        () => TestConfig.requireSupabaseEnv(
          url: 'https://vlmtsdzpnjnavdgytcmi.supabase.co',
          anonKey: 'some-anon-key',
        ),
        returnsNormally,
      );
    });

    test('with no arguments it checks the run\'s own values', () {
      final missing =
          TestConfig.supabaseUrl.isEmpty || TestConfig.supabaseAnonKey.isEmpty;
      expect(
        TestConfig.requireSupabaseEnv,
        missing ? throwsA(isA<StateError>()) : returnsNormally,
      );
    });
  });
}

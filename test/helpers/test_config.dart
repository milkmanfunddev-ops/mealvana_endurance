import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/shared/services/app_config.dart';

/// Test configuration utilities for Phase 1 Step 2
class TestConfig {
  /// Create a test provider container with config overrides
  ///
  /// Usage:
  /// ```dart
  /// final container = TestConfig.createTestContainer(
  ///   config: AppConfig.forTesting(
  ///     supabaseUrl: 'http://localhost:54321',
  ///   ),
  /// );
  /// ```
  static ProviderContainer createTestContainer({
    AppConfig? config,
    List<dynamic> additionalOverrides = const [],
  }) {
    return ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          config ?? AppConfig.forTesting(),
        ),
        ...additionalOverrides,
      ],
    );
  }

  /// Load configuration from .env.test_supabase for edge function testing
  ///
  /// Usage:
  /// ```dart
  /// await TestConfig.loadTestEnv();
  /// final config = AppConfig.fromEnv();
  /// ```
  static Future<void> loadTestEnv() async {
    await dotenv.load(fileName: '.env.test_supabase');
  }

  /// Create config for edge function testing against dev cloud
  /// This loads from .env.test_supabase
  static Future<AppConfig> forEdgeTesting() async {
    await loadTestEnv();
    return AppConfig.fromEnv();
  }

  /// Create config for local Supabase testing
  /// Uses localhost URLs for Supabase stack
  static AppConfig forLocalTesting() {
    return AppConfig.forTesting(
      supabaseUrl: 'http://localhost:54321',
      supabaseAnonKey: dotenv.get('SUPABASE_ANON_KEY', fallback: 'local-anon-key'),
    );
  }

  /// Create a minimal test config with no-op services
  /// Useful for unit tests that don't need external dependencies
  static AppConfig minimal() {
    return AppConfig.forTesting(
      supabaseUrl: 'http://test-supabase',
      supabaseAnonKey: 'test-key',
      sentryDsn: 'https://test@test.ingest.sentry.io/test',
      mixpanelToken: 'test-mixpanel',
    );
  }
}

/// Extension for testing with ProviderContainer
extension ProviderContainerTest on ProviderContainer {
  /// Dispose container after test completes
  ///
  /// Usage:
  /// ```dart
  /// test('my test', () {
  ///   final container = TestConfig.createTestContainer()
  ///     ..disposeAfterTest();
  ///   // test code
  /// });
  /// ```
  ProviderContainer disposeAfterTest() {
    addTearDown(dispose);
    return this;
  }
}

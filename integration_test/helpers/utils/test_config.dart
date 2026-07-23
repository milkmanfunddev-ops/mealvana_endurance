import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/supabase/supabase_client_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../mocks/recording_analytics_tracker.dart';
import '../mocks/recording_sentry_reporter.dart';
import '../mocks/recording_app_logger.dart';
import '../mocks/mock_supabase_client.dart';

/// Configuration utilities for integration tests
/// Provides standardized setup for test containers and dependencies
class TestConfig {
  /// Creates a test ProviderContainer with common overrides
  /// for integration testing
  static ProviderContainer createTestContainer({
    AppConfig? config,
    AppDatabase? database,
    AnalyticsTracker? analytics,
    SentryReporter? sentry,
    AppLogger? logger,
    SupabaseClient? supabaseClient,
    List? additionalOverrides,
  }) {
    final overrides = [
      // Override AppConfig with test configuration
      appConfigProvider.overrideWithValue(config ?? AppConfig.forTesting()),

      // Override database with in-memory database
      appDatabaseProvider.overrideWithValue(database ?? AppDatabase.memory()),

      // Override analytics with recording tracker
      analyticsTrackerProvider.overrideWithValue(
        analytics ?? RecordingAnalyticsTracker(),
      ),

      // Override sentry with recording reporter
      sentryReporterProvider.overrideWithValue(
        sentry ?? RecordingSentryReporter(),
      ),

      // Override logger with recording logger
      appLoggerProvider.overrideWithValue(logger ?? RecordingAppLogger()),
    ];

    // Add Supabase client override if provided
    if (supabaseClient != null) {
      overrides.add(supabaseClientProvider.overrideWithValue(supabaseClient));
    }

    // Add any additional overrides
    if (additionalOverrides != null) {
      overrides.addAll(additionalOverrides.cast());
    }

    return ProviderContainer(overrides: overrides.cast());
  }

  /// Creates mock external dependencies for testing
  /// Note: You must call SharedPreferences.setMockInitialValues({}) before using this
  static Future<AppExternalDeps> createMockExternalDeps({
    RecordingAnalyticsTracker? analytics,
    RecordingSentryReporter? sentry,
    RecordingAppLogger? logger,
    SupabaseClient? supabaseClient,
    SharedPreferences? sharedPreferences,
  }) async {
    // Get or create SharedPreferences instance for testing
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    return AppExternalDeps(
      analytics: analytics ?? RecordingAnalyticsTracker(),
      supabaseClient: supabaseClient ?? MockSupabaseClient(),
      sentry: sentry ?? RecordingSentryReporter(),
      logger: logger ?? RecordingAppLogger(),
      sharedPreferences: prefs,
    );
  }

  /// Creates a standard test configuration with all recording dependencies
  /// Returns a map of {container, analytics, sentry, logger, database}
  /// for easy access in tests
  static TestDependencies createStandardTestDeps() {
    final analytics = RecordingAnalyticsTracker();
    final sentry = RecordingSentryReporter();
    final logger = RecordingAppLogger();
    final database = AppDatabase.memory();
    final config = AppConfig.forTesting();
    final supabaseClient = MockSupabaseClient();

    final container = createTestContainer(
      config: config,
      database: database,
      analytics: analytics,
      sentry: sentry,
      logger: logger,
      supabaseClient: supabaseClient,
    );

    return TestDependencies(
      container: container,
      analytics: analytics,
      sentry: sentry,
      logger: logger,
      database: database,
      config: config,
      supabaseClient: supabaseClient,
    );
  }

  /// Creates provider overrides list for widget testing
  static List createStandardOverrides({
    AppConfig? config,
    AppDatabase? database,
    AnalyticsTracker? analytics,
    SentryReporter? sentry,
    AppLogger? logger,
    SupabaseClient? supabaseClient,
  }) {
    final overrides = [
      appConfigProvider.overrideWithValue(config ?? AppConfig.forTesting()),
      appDatabaseProvider.overrideWithValue(database ?? AppDatabase.memory()),
      analyticsTrackerProvider.overrideWithValue(
        analytics ?? RecordingAnalyticsTracker(),
      ),
      sentryReporterProvider.overrideWithValue(
        sentry ?? RecordingSentryReporter(),
      ),
      appLoggerProvider.overrideWithValue(logger ?? RecordingAppLogger()),
    ];

    if (supabaseClient != null) {
      overrides.add(supabaseClientProvider.overrideWithValue(supabaseClient));
    }

    return overrides;
  }
}

/// Container class for test dependencies
/// Makes it easy to pass around all test dependencies together
class TestDependencies {
  TestDependencies({
    required this.container,
    required this.analytics,
    required this.sentry,
    required this.logger,
    required this.database,
    required this.config,
    required this.supabaseClient,
  });

  final ProviderContainer container;
  final RecordingAnalyticsTracker analytics;
  final RecordingSentryReporter sentry;
  final RecordingAppLogger logger;
  final AppDatabase database;
  final AppConfig config;
  final SupabaseClient supabaseClient;

  /// Clean up all test dependencies
  Future<void> dispose() async {
    analytics.clear();
    sentry.clear();
    logger.clear();
    await database.close();
    container.dispose();
  }

  /// Reset all recorded calls without disposing
  void reset() {
    analytics.clear();
    sentry.clear();
    logger.clear();
  }
}

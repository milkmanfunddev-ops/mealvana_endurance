import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized application configuration loaded from .env files
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.supabasePublishableKey,
    required this.supabaseSecretKey,
    required this.sentryDsn,
    required this.sentryEnvironment,
    required this.mixpanelProjectToken,
    required this.usdaApiKey,
    this.enableDebugLogging = false,
    this.enableSentryProfiling = false,
  });

  // Supabase configuration
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String supabasePublishableKey;
  final String supabaseSecretKey;

  // Sentry configuration
  final String sentryDsn;
  final String sentryEnvironment;

  // Analytics configuration
  final String mixpanelProjectToken;

  // External API keys
  final String usdaApiKey;

  // Feature flags / debug settings
  final bool enableDebugLogging;
  final bool enableSentryProfiling;

  /// Factory for loading configuration from .env file
  /// Must call dotenv.load() before using this factory
  factory AppConfig.fromEnv() {
    return AppConfig(
      // Supabase configuration
      supabaseUrl: dotenv.get(
        'SUPABASE_URL',
        fallback: 'https://wvmvsodrvbkxfydabqed.supabase.co',
      ),
      supabaseAnonKey: dotenv.get(
        'SUPABASE_ANON_KEY',
        fallback: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyOTMxMDcsImV4cCI6MjA3MDg2OTEwN30.pG2IYdEIIFS8_zPxzr6pZplzWQqvD13dvslrpFMAPCk',
      ),
      supabasePublishableKey: dotenv.get(
        'SUPABASE_PUBLISHABLE_KEY',
        fallback: '',
      ),
      supabaseSecretKey: dotenv.get(
        'SUPABASE_SECRET_KEY',
        fallback: '',
      ),

      // Sentry configuration
      sentryDsn: dotenv.get(
        'SENTRY_DSN',
        fallback: 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328',
      ),
      sentryEnvironment: dotenv.get(
        'SENTRY_ENVIRONMENT',
        fallback: kDebugMode ? 'development' : 'production',
      ),

      // Analytics configuration
      mixpanelProjectToken: dotenv.get(
        'MIXPANEL_PROJECT_TOKEN',
        fallback: 'bd8fe50bb67b1dd0860351e6297347db',
      ),

      // External API keys
      usdaApiKey: dotenv.get(
        'USDA_API_KEY',
        fallback: '',
      ),

      // Debug settings
      enableDebugLogging: kDebugMode,
      enableSentryProfiling: !kDebugMode, // Disabled in debug due to iOS crash
    );
  }

  /// Factory for test configuration
  /// Used in tests to override configuration values
  factory AppConfig.forTesting({
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? supabasePublishableKey,
    String? supabaseSecretKey,
    String? sentryDsn,
    String? sentryEnvironment,
    String? mixpanelToken,
    String? usdaApiKey,
    bool enableDebugLogging = true,
    bool enableSentryProfiling = false,
  }) {
    return AppConfig(
      supabaseUrl: supabaseUrl ?? 'http://localhost:54321',
      supabaseAnonKey: supabaseAnonKey ?? 'test-anon-key',
      supabasePublishableKey: supabasePublishableKey ?? 'test-publishable-key',
      supabaseSecretKey: supabaseSecretKey ?? 'test-secret-key',
      sentryDsn: sentryDsn ?? 'https://test-sentry-dsn@test.ingest.sentry.io/test',
      sentryEnvironment: sentryEnvironment ?? 'test',
      mixpanelProjectToken: mixpanelToken ?? 'test-mixpanel-token',
      usdaApiKey: usdaApiKey ?? 'test-usda-api-key',
      enableDebugLogging: enableDebugLogging,
      enableSentryProfiling: enableSentryProfiling,
    );
  }

  /// Load configuration from specific .env file
  /// Useful for loading test configuration
  static Future<AppConfig> loadFromFile(String fileName) async {
    await dotenv.load(fileName: fileName);
    return AppConfig.fromEnv();
  }
}

/// Provider exposing application configuration
/// This will be overridden in main.dart after loading .env
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError(
    'appConfigProvider must be overridden in main.dart after loading .env',
  );
});

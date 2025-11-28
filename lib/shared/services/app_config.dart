import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    required this.devModeEnabled,
    required this.appEnvironment,
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

  // Environment configuration
  final bool devModeEnabled;
  final String appEnvironment; // 'dev' or 'prod'

  // Feature flags / debug settings
  final bool enableDebugLogging;
  final bool enableSentryProfiling;

  // Environment control - CHANGE THIS TO false FOR PRODUCTION RELEASE BUILDS
  // When true: loads .env.dev.local (dev Supabase, dev Mixpanel)
  // When false: loads .env.prod.local (prod Supabase, prod Mixpanel)
  // ignore: constant_identifier_names
  static const bool _DEFAULT_DEV_MODE = false;

  // Runtime override (persisted in SharedPreferences)
  static bool? _runtimeOverride;

  /// Get the effective dev mode setting
  /// Priority order:
  /// 1. Runtime override (if set via SharedPreferences)
  /// 2. kDebugMode (debug builds always use dev environment as safety net)
  /// 3. _DEFAULT_DEV_MODE (fallback for release builds)
  static bool get effectiveDevMode {
    // Runtime override takes highest priority
    if (_runtimeOverride != null) {
      return _runtimeOverride!;
    }
    // Debug builds always use dev environment (safety net)
    // if (kDebugMode) {
    //   return true;
    // }
    // Release builds use the configured default
    return _DEFAULT_DEV_MODE;
  }

  /// Override dev mode at runtime (requires app restart to take effect)
  static Future<void> setDevModeOverride(bool value) async {
    _runtimeOverride = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_mode_override', value);
  }

  /// Clear runtime override (revert to default)
  static Future<void> clearDevModeOverride() async {
    _runtimeOverride = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dev_mode_override');
  }

  /// Initialize runtime override from SharedPreferences
  static Future<void> loadDevModeOverride() async {
    final prefs = await SharedPreferences.getInstance();
    _runtimeOverride = prefs.getBool('dev_mode_override');
  }

  /// Helper methods
  bool get isProduction => appEnvironment == 'prod' && !devModeEnabled;
  bool get isDevelopment => appEnvironment == 'dev' || devModeEnabled;

  /// Factory for loading configuration from .env file
  /// Must call dotenv.load() before using this factory
  /// Now reads from .env.dev.local or .env.prod.local based on dev mode
  factory AppConfig.fromEnv() {
    final isDevMode = effectiveDevMode;
    final appEnv = isDevMode ? 'dev' : 'prod';

    // Read all configuration from loaded .env file
    final supabaseUrl = dotenv.get('SUPABASE_URL', fallback: '');
    final supabaseAnonKey = dotenv.get('SUPABASE_ANON_KEY', fallback: '');

    return AppConfig(
      // Environment configuration
      devModeEnabled: isDevMode,
      appEnvironment: appEnv,

      // Supabase configuration - read from loaded .env file
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      supabasePublishableKey: dotenv.get(
        'SUPABASE_PUBLISHABLE_KEY',
        fallback: '',
      ),
      supabaseSecretKey: dotenv.get(
        'SUPABASE_SECRET_KEY',
        fallback: '',
      ),

      // Sentry configuration - read from loaded .env file
      sentryDsn: dotenv.get(
        'SENTRY_DSN',
        fallback: 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328',
      ),
      sentryEnvironment: dotenv.get(
        'SENTRY_ENVIRONMENT',
        fallback: isDevMode ? 'development' : 'production',
      ),

      // Analytics configuration - read from loaded .env file
      mixpanelProjectToken: dotenv.get(
        'MIXPANEL_PROJECT_TOKEN',
        fallback: isDevMode
            ? 'df6e8dd4f3dc1363fa194a156298b16c' // Dev token
            : 'bd8fe50bb67b1dd0860351e6297347db', // Prod token
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
    bool devModeEnabled = true,
    String appEnvironment = 'dev',
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
      devModeEnabled: devModeEnabled,
      appEnvironment: appEnvironment,
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

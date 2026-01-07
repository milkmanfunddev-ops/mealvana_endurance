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
    required this.wiredashProjectId,
    required this.wiredashSecret,
    required this.oneSignalAppId,
    required this.trainingPeaksClientId,
    required this.trainingPeaksClientSecret,
    required this.trainingPeaksUseSandbox,
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

  // Wiredash (User Feedback) configuration
  final String wiredashProjectId;
  final String wiredashSecret;

  // OneSignal (Push Notifications) configuration
  final String oneSignalAppId;

  // External API keys
  final String usdaApiKey;

  // TrainingPeaks integration
  final String trainingPeaksClientId;
  final String trainingPeaksClientSecret;
  final bool trainingPeaksUseSandbox;

  // Environment configuration
  final bool devModeEnabled;
  final String appEnvironment; // 'dev' or 'prod'

  // Feature flags / debug settings
  final bool enableDebugLogging;
  final bool enableSentryProfiling;

  /// Helper methods
  bool get isProduction => appEnvironment == 'prod' && !devModeEnabled;
  bool get isDevelopment => appEnvironment == 'dev' || devModeEnabled;

  /// Factory for loading configuration from .env file
  /// Must call dotenv.load() before using this factory
  /// Environment is determined from the loaded .env file (dev or prod)
  factory AppConfig.fromEnv() {
    // Read environment from .env file (should be 'dev' or 'prod')
    final appEnv = dotenv.get('APP_ENVIRONMENT', fallback: 'prod');
    final isDevMode = appEnv == 'dev';

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

      // Wiredash (User Feedback) configuration
      wiredashProjectId: dotenv.get(
        'WIREDASH_PROJECT_ID',
        fallback: 'mealvana-endurance-vn1pxw3',
      ),
      wiredashSecret: dotenv.get(
        'WIREDASH_SECRET',
        fallback: 'wuQrGN_DMojjIopfhEblvMpU53FSChuD',
      ),

      // OneSignal (Push Notifications) configuration
      // App ID from OneSignal dashboard - must be configured in .env files
      oneSignalAppId: dotenv.get(
        'ONESIGNAL_APP_ID',
        fallback: '', // No fallback - must be configured
      ),

      // External API keys
      usdaApiKey: dotenv.get(
        'USDA_API_KEY',
        fallback: '',
      ),

      // TrainingPeaks integration
      trainingPeaksClientId: dotenv.get(
        'TRAININGPEAKS_CLIENT_ID',
        fallback: 'mealvana',
      ),
      trainingPeaksClientSecret: dotenv.get(
        'TRAININGPEAKS_CLIENT_SECRET',
        fallback: '',
      ),
      // Use sandbox in dev, production API in prod
      trainingPeaksUseSandbox: isDevMode,

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
    String? wiredashProjectId,
    String? wiredashSecret,
    String? oneSignalAppId,
    String? usdaApiKey,
    String? trainingPeaksClientId,
    String? trainingPeaksClientSecret,
    bool trainingPeaksUseSandbox = true,
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
      wiredashProjectId: wiredashProjectId ?? 'test-wiredash-project',
      wiredashSecret: wiredashSecret ?? 'test-wiredash-secret',
      oneSignalAppId: oneSignalAppId ?? 'test-onesignal-app-id',
      usdaApiKey: usdaApiKey ?? 'test-usda-api-key',
      trainingPeaksClientId: trainingPeaksClientId ?? 'test-tp-client-id',
      trainingPeaksClientSecret: trainingPeaksClientSecret ?? 'test-tp-secret',
      trainingPeaksUseSandbox: trainingPeaksUseSandbox,
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

  /// Factory for web builds using --dart-define
  /// Web builds cannot use dotenv files (they would be publicly accessible)
  /// Instead, environment variables are passed via --dart-define at build time
  ///
  /// Required defines:
  /// - SUPABASE_URL: Supabase project URL
  /// - SUPABASE_ANON_KEY: Supabase anonymous key
  ///
  /// Optional defines (have fallbacks):
  /// - APP_ENVIRONMENT: 'dev' or 'prod' (default: 'prod')
  /// - SENTRY_DSN: Sentry DSN for error tracking
  /// - MIXPANEL_PROJECT_TOKEN: Mixpanel analytics token
  factory AppConfig.fromDartDefines() {
    // All String.fromEnvironment calls MUST be const (compile-time only)
    const appEnv = String.fromEnvironment('APP_ENVIRONMENT', defaultValue: 'prod');
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const sentryDsn = String.fromEnvironment(
      'SENTRY_DSN',
      defaultValue: 'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328',
    );
    const sentryEnvironment = String.fromEnvironment('SENTRY_ENVIRONMENT');
    const mixpanelToken = String.fromEnvironment('MIXPANEL_PROJECT_TOKEN');
    const wiredashProjectId = String.fromEnvironment(
      'WIREDASH_PROJECT_ID',
      defaultValue: 'mealvana-endurance-vn1pxw3',
    );
    const wiredashSecret = String.fromEnvironment(
      'WIREDASH_SECRET',
      defaultValue: 'wuQrGN_DMojjIopfhEblvMpU53FSChuD',
    );
    const usdaApiKey = String.fromEnvironment('USDA_API_KEY');

    // Runtime logic applied after const extraction
    final isDevMode = appEnv == 'dev';

    // Validate required configuration
    if (supabaseUrl.isEmpty) {
      throw StateError('SUPABASE_URL must be provided via --dart-define');
    }
    if (supabaseAnonKey.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY must be provided via --dart-define');
    }

    // Apply defaults that depend on runtime values
    final effectiveSentryEnv = sentryEnvironment.isNotEmpty
        ? sentryEnvironment
        : (isDevMode ? 'development' : 'production');

    final effectiveMixpanelToken = mixpanelToken.isNotEmpty
        ? mixpanelToken
        : (isDevMode
            ? 'df6e8dd4f3dc1363fa194a156298b16c'  // Dev token
            : 'bd8fe50bb67b1dd0860351e6297347db'); // Prod token

    return AppConfig(
      // Environment configuration
      devModeEnabled: isDevMode,
      appEnvironment: appEnv,

      // Supabase configuration
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      supabasePublishableKey: supabasePublishableKey,
      supabaseSecretKey: '', // Never include secret key in web builds

      // Sentry configuration
      sentryDsn: sentryDsn,
      sentryEnvironment: effectiveSentryEnv,

      // Analytics configuration
      mixpanelProjectToken: effectiveMixpanelToken,

      // Wiredash (User Feedback)
      wiredashProjectId: wiredashProjectId,
      wiredashSecret: wiredashSecret,

      // OneSignal - not used on web
      oneSignalAppId: '',

      // External API keys
      usdaApiKey: usdaApiKey,

      // Debug settings
      enableDebugLogging: kDebugMode,
      enableSentryProfiling: false, // Disable profiling on web
    );
  }
}

/// Provider exposing application configuration
/// This will be overridden in main.dart after loading .env
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError(
    'appConfigProvider must be overridden in main.dart after loading .env',
  );
});

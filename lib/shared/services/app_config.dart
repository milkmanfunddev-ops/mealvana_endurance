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
    required this.oneSignalAppId,
    required this.usdaApiKey,
    required this.wiredashProjectId,
    required this.wiredashSecret,
    required this.trainingPeaksClientId,
    required this.trainingPeaksClientSecret,
    required this.trainingPeaksUseSandbox,
    required this.finalSurgeClientId,
    required this.finalSurgeClientSecret,
    required this.finalSurgeBaseUrl,
    required this.garminClientId,
    required this.garminClientSecret,
    required this.garminRedirectUri,
    required this.vdotClientId,
    required this.vdotClientSecret,
    required this.vdotUseSandbox,
    required this.devModeEnabled,
    required this.appEnvironment,
    required this.revenueCatApiKeyApple,
    required this.revenueCatApiKeyGoogle,
    required this.aiCreditsEnabled,
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

  // Push notifications
  final String oneSignalAppId;

  // Wiredash (User Feedback) configuration
  final String wiredashProjectId;
  final String wiredashSecret;

  // External API keys
  final String usdaApiKey;

  // TrainingPeaks integration
  final String trainingPeaksClientId;
  final String trainingPeaksClientSecret;
  final bool trainingPeaksUseSandbox;

  // Final Surge integration
  final String finalSurgeClientId;
  final String finalSurgeClientSecret;
  final String finalSurgeBaseUrl;

  // Garmin Connect integration
  final String garminClientId;
  final String garminClientSecret;
  final String garminRedirectUri;

  // V.O2 (VDOT) integration
  final String vdotClientId;
  final String vdotClientSecret;
  final bool vdotUseSandbox;

  /// Base host for the V.O2 OAuth authorize/token endpoints.
  ///
  /// Note: VDOT documents `app.sandbox.vdoto2.com` as the sandbox OAuth host,
  /// but that hostname does not resolve in DNS (verified 2026-05-18). Only
  /// `app.vdoto2.com` exists. The sandbox toggle only switches the API base.
  String get vdotAuthBaseUrl => 'https://app.vdoto2.com';

  /// Base host for the V.O2 REST API.
  String get vdotApiBaseUrl =>
      vdotUseSandbox ? 'https://api.sandbox.vdoto2.com' : 'https://api.vdoto2.com';

  // Environment configuration
  final bool devModeEnabled;
  final String appEnvironment; // 'dev' or 'prod'

  // RevenueCat (AI Credit Packs)
  final String revenueCatApiKeyApple;
  final String revenueCatApiKeyGoogle;

  /// Feature flag controlling AI credit purchasing UI.
  ///
  /// Default false — the paywall and balance chip are hidden until explicitly
  /// enabled via the `AI_CREDITS_ENABLED=true` env var.
  final bool aiCreditsEnabled;

  /// Platform-appropriate RevenueCat public API key.
  ///
  /// Returns the Apple key on iOS/macOS and the Google key on Android.
  /// Empty string on web or when the keys have not been configured.
  String get revenueCatApiKey {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return revenueCatApiKeyApple;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return revenueCatApiKeyGoogle;
    }
    return ''; // Web / other platforms: RC not supported
  }

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
      supabaseSecretKey: dotenv.get('SUPABASE_SECRET_KEY', fallback: ''),

      // Sentry configuration - read from loaded .env file
      sentryDsn: dotenv.get(
        'SENTRY_DSN',
        fallback:
            'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328',
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
      oneSignalAppId: dotenv.get('ONESIGNAL_APP_ID', fallback: ''),

      // Wiredash (User Feedback) configuration
      wiredashProjectId: dotenv.get(
        'WIREDASH_PROJECT_ID',
        fallback: 'mealvana-endurance-vn1pxw3',
      ),
      wiredashSecret: dotenv.get(
        'WIREDASH_SECRET',
        fallback: 'wuQrGN_DMojjIopfhEblvMpU53FSChuD',
      ),

      // External API keys
      usdaApiKey: dotenv.get('USDA_API_KEY', fallback: ''),

      // TrainingPeaks integration
      trainingPeaksClientId: dotenv.get(
        'TRAININGPEAKS_CLIENT_ID',
        fallback: 'mealvana',
      ),
      trainingPeaksClientSecret: dotenv.get(
        'TRAININGPEAKS_CLIENT_SECRET',
        fallback: '',
      ),
      // Use sandbox unless explicitly set to 'false' in .env
      // This allows prod builds to use sandbox during testing
      trainingPeaksUseSandbox:
          dotenv.get('TRAININGPEAKS_USE_SANDBOX', fallback: 'true') == 'true',

      // Final Surge integration
      finalSurgeClientId: dotenv.get(
        'FINAL_SURGE_CLIENT_ID',
        fallback: 'BD5D0C2B-7507-405B-8A3F-DB161288E6FC',
      ),
      finalSurgeClientSecret: dotenv.get(
        'FINAL_SURGE_CLIENT_SECRET',
        fallback: '',
      ),
      finalSurgeBaseUrl: dotenv.get(
        'FINAL_SURGE_BASE_URL',
        fallback: 'https://log.finalsurge.com',
      ),

      // Garmin Connect integration
      garminClientId: dotenv.get('GARMIN_CLIENT_ID', fallback: ''),
      garminClientSecret: dotenv.get('GARMIN_CLIENT_SECRET', fallback: ''),
      garminRedirectUri: dotenv.get('GARMIN_REDIRECT_URI', fallback: ''),

      // V.O2 (VDOT) integration
      vdotClientId: dotenv.get('VDOT_CLIENT_ID', fallback: 'mealvana'),
      vdotClientSecret: dotenv.get('VDOT_CLIENT_SECRET', fallback: ''),
      // Default to sandbox during development; flip to production once registered.
      vdotUseSandbox:
          dotenv.get('VDOT_USE_SANDBOX', fallback: 'true') == 'true',

      // RevenueCat (AI Credit Packs)
      revenueCatApiKeyApple: dotenv.get(
        'REVENUECAT_API_KEY_APPLE',
        fallback: '',
      ),
      revenueCatApiKeyGoogle: dotenv.get(
        'REVENUECAT_API_KEY_GOOGLE',
        fallback: '',
      ),
      aiCreditsEnabled:
          dotenv.get('AI_CREDITS_ENABLED', fallback: 'false') == 'true',

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
    String? oneSignalAppId,
    String? wiredashProjectId,
    String? wiredashSecret,
    String? usdaApiKey,
    String? trainingPeaksClientId,
    String? trainingPeaksClientSecret,
    bool trainingPeaksUseSandbox = true,
    String? finalSurgeClientId,
    String? finalSurgeClientSecret,
    String? finalSurgeBaseUrl,
    String? garminClientId,
    String? garminClientSecret,
    String? garminRedirectUri,
    String? vdotClientId,
    String? vdotClientSecret,
    bool vdotUseSandbox = true,
    bool devModeEnabled = true,
    String appEnvironment = 'dev',
    String revenueCatApiKeyApple = '',
    String revenueCatApiKeyGoogle = '',
    bool aiCreditsEnabled = false,
    bool enableDebugLogging = true,
    bool enableSentryProfiling = false,
  }) {
    return AppConfig(
      supabaseUrl: supabaseUrl ?? 'http://localhost:54321',
      supabaseAnonKey: supabaseAnonKey ?? 'test-anon-key',
      supabasePublishableKey: supabasePublishableKey ?? 'test-publishable-key',
      supabaseSecretKey: supabaseSecretKey ?? 'test-secret-key',
      sentryDsn:
          sentryDsn ?? 'https://test-sentry-dsn@test.ingest.sentry.io/test',
      sentryEnvironment: sentryEnvironment ?? 'test',
      mixpanelProjectToken: mixpanelToken ?? 'test-mixpanel-token',
      oneSignalAppId: oneSignalAppId ?? '',
      wiredashProjectId: wiredashProjectId ?? 'test-wiredash-project',
      wiredashSecret: wiredashSecret ?? 'test-wiredash-secret',
      usdaApiKey: usdaApiKey ?? 'test-usda-api-key',
      trainingPeaksClientId: trainingPeaksClientId ?? 'test-tp-client-id',
      trainingPeaksClientSecret: trainingPeaksClientSecret ?? 'test-tp-secret',
      trainingPeaksUseSandbox: trainingPeaksUseSandbox,
      finalSurgeClientId: finalSurgeClientId ?? 'test-fs-client-id',
      finalSurgeClientSecret: finalSurgeClientSecret ?? 'test-fs-secret',
      finalSurgeBaseUrl: finalSurgeBaseUrl ?? 'https://log.finalsurge.com',
      garminClientId: garminClientId ?? 'test-garmin-client-id',
      garminClientSecret: garminClientSecret ?? 'test-garmin-secret',
      garminRedirectUri:
          garminRedirectUri ?? 'com.milkman.mealvanaendurance://callback',
      vdotClientId: vdotClientId ?? 'test-vdot-client-id',
      vdotClientSecret: vdotClientSecret ?? 'test-vdot-secret',
      vdotUseSandbox: vdotUseSandbox,
      devModeEnabled: devModeEnabled,
      appEnvironment: appEnvironment,
      revenueCatApiKeyApple: revenueCatApiKeyApple,
      revenueCatApiKeyGoogle: revenueCatApiKeyGoogle,
      aiCreditsEnabled: aiCreditsEnabled,
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
  /// - ONESIGNAL_APP_ID: OneSignal app id for remote push
  factory AppConfig.fromDartDefines() {
    // All String.fromEnvironment calls MUST be const (compile-time only)
    const appEnv = String.fromEnvironment(
      'APP_ENVIRONMENT',
      defaultValue: 'prod',
    );
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const supabasePublishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    );
    const sentryDsn = String.fromEnvironment(
      'SENTRY_DSN',
      defaultValue:
          'https://00d9cb3e5fc60c90fd5ca3ed2bf690c5@o4509882392969216.ingest.us.sentry.io/4509882394083328',
    );
    const sentryEnvironment = String.fromEnvironment('SENTRY_ENVIRONMENT');
    const mixpanelToken = String.fromEnvironment('MIXPANEL_PROJECT_TOKEN');
    const oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');
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
              ? 'df6e8dd4f3dc1363fa194a156298b16c' // Dev token
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
      oneSignalAppId: oneSignalAppId,

      // Wiredash (User Feedback)
      wiredashProjectId: wiredashProjectId,
      wiredashSecret: wiredashSecret,

      // External API keys
      usdaApiKey: usdaApiKey,

      // TrainingPeaks configuration - read from dart-define for web builds
      trainingPeaksClientId: const String.fromEnvironment(
        'TRAININGPEAKS_CLIENT_ID',
        defaultValue: 'mealvana',
      ),
      trainingPeaksClientSecret: const String.fromEnvironment(
        'TRAININGPEAKS_CLIENT_SECRET',
        defaultValue: '',
      ),
      trainingPeaksUseSandbox:
          const String.fromEnvironment(
            'TRAININGPEAKS_USE_SANDBOX',
            defaultValue: 'true',
          ) ==
          'true',

      // Final Surge configuration - read from dart-define for web builds
      finalSurgeClientId: const String.fromEnvironment(
        'FINAL_SURGE_CLIENT_ID',
        defaultValue: 'BD5D0C2B-7507-405B-8A3F-DB161288E6FC',
      ),
      finalSurgeClientSecret: const String.fromEnvironment(
        'FINAL_SURGE_CLIENT_SECRET',
        defaultValue: '',
      ),
      finalSurgeBaseUrl: const String.fromEnvironment(
        'FINAL_SURGE_BASE_URL',
        defaultValue: 'https://log.finalsurge.com',
      ),

      // Garmin Connect configuration - read from dart-define for web builds
      garminClientId: const String.fromEnvironment(
        'GARMIN_CLIENT_ID',
        defaultValue: '',
      ),
      garminClientSecret: const String.fromEnvironment(
        'GARMIN_CLIENT_SECRET',
        defaultValue: '',
      ),
      garminRedirectUri: const String.fromEnvironment(
        'GARMIN_REDIRECT_URI',
        defaultValue: '',
      ),

      // V.O2 (VDOT) configuration - read from dart-define for web builds
      vdotClientId: const String.fromEnvironment(
        'VDOT_CLIENT_ID',
        defaultValue: 'mealvana',
      ),
      vdotClientSecret: const String.fromEnvironment(
        'VDOT_CLIENT_SECRET',
        defaultValue: '',
      ),
      vdotUseSandbox:
          const String.fromEnvironment(
            'VDOT_USE_SANDBOX',
            defaultValue: 'true',
          ) ==
          'true',

      // RevenueCat (AI Credit Packs)
      revenueCatApiKeyApple: const String.fromEnvironment(
        'REVENUECAT_API_KEY_APPLE',
        defaultValue: '',
      ),
      revenueCatApiKeyGoogle: const String.fromEnvironment(
        'REVENUECAT_API_KEY_GOOGLE',
        defaultValue: '',
      ),
      aiCreditsEnabled:
          const String.fromEnvironment(
            'AI_CREDITS_ENABLED',
            defaultValue: 'false',
          ) ==
          'true',

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

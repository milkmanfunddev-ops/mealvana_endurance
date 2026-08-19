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
    this.revenueCatApiKeyTest = '',
    this.describeMealEnabled = true,
    this.coachInsightsEnabled = false,
    this.macroDashboardEnabled = false,
    this.analyticsDevEnabled = false,
    this.enableDebugLogging = false,
    this.enableSentryProfiling = false,
  });

  // Supabase configuration
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String supabasePublishableKey;
  final String supabaseSecretKey;

  /// The client-facing key for `Supabase.initialize`. Prefers the new
  /// publishable key (`sb_publishable_…`) when present, falling back to the
  /// legacy anon JWT — so the legacy anon key can eventually be disabled once
  /// every build ships the publishable key.
  String get supabaseClientKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : supabaseAnonKey;

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
  String get vdotApiBaseUrl => vdotUseSandbox
      ? 'https://api.sandbox.vdoto2.com'
      : 'https://api.vdoto2.com';

  // Environment configuration
  final bool devModeEnabled;
  final String appEnvironment; // 'dev' or 'prod'

  /// Opt-in: send real analytics from dev builds to the dev Mixpanel project
  /// ("Mealvana Endurance Dev") instead of the no-op tracker. Verification
  /// sandbox only — prod remains the analysis target.
  final bool analyticsDevEnabled;

  // RevenueCat (AI Credit Packs)
  final String revenueCatApiKeyApple;
  final String revenueCatApiKeyGoogle;

  /// RevenueCat **Test Store** public key (`test_…`), for exercising the whole
  /// purchase → webhook → wallet path without a real store.
  ///
  /// The Test Store is platform-agnostic and completes purchases instantly with
  /// no payment method, which is the only way to test buying on a simulator —
  /// StoreKit returns no products there without a sandbox account or a
  /// `.storekit` config file.
  ///
  /// **Honoured only in a DEBUG build of the dev flavor** (see
  /// [revenueCatApiKey]). RevenueCat forbids Test Store keys in release
  /// binaries, and enforces it at runtime: a release build handed a `test_` key
  /// shows a native "wrong API key" alert on launch and terminates when it is
  /// dismissed. So a TestFlight dev build uses the real Apple key and cannot
  /// complete Test Store purchases — exercise those on a simulator or a local
  /// `flutter run` instead.
  final String revenueCatApiKeyTest;

  /// Feature flag controlling AI credit purchasing UI (token pill, top-up
  /// sheet, buy-credits screen).
  ///
  /// **ON by default in dev builds, off in prod** — same rule as
  /// [describeMealEnabled] and [coachInsightsEnabled]. `AI_CREDITS_ENABLED=false`
  /// still turns it off explicitly.
  final bool aiCreditsEnabled;

  /// Release gate for text/photo meal analysis entry points.
  ///
  /// Pinned open in every build (2026-08-10, Lee): the Describe tab and the
  /// photo/describe routes always show, dev and prod alike. The field is kept
  /// so the gate can be re-closed at one choke point if metering ever demands
  /// it.
  final bool describeMealEnabled;

  /// Release gate for Formula Kit coach insights.
  ///
  /// Defaults off for the same fail-closed cost protection as
  /// [describeMealEnabled].
  final bool coachInsightsEnabled;

  /// Release gate for the redesigned macro dashboard
  /// (bundle daily-macros-dashboard@v1). Fail-closed: the Fuel Timeline
  /// stays the default surface until product flips this on.
  final bool macroDashboardEnabled;

  /// Platform-appropriate RevenueCat public API key.
  ///
  /// Returns the Apple key on iOS/macOS and the Google key on Android.
  /// Empty string on web or when the keys have not been configured.
  String get revenueCatApiKey {
    // Dev opt-in: a Test Store key wins over the real store key so purchases
    // can be exercised end to end without paying.
    //
    // Gated on `kDebugMode`, NOT merely on the dev flavor. RevenueCat's own
    // rule is "never submit an app configured with a Test Store API key" —
    // debug builds get the test key, release builds get the platform key. A
    // Codemagic dev build is a *release* build (Shorebird → TestFlight), so
    // handing it a `test_` key made the native SDK raise its "wrong API key"
    // alert at launch and then take the app down when the alert was dismissed.
    // The dev *flavor* is not the same thing as a debug *build*, and only the
    // latter is safe here.
    if (isDevelopment && kDebugMode && revenueCatApiKeyTest.isNotEmpty) {
      return revenueCatApiKeyTest;
    }
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
      analyticsDevEnabled:
          dotenv.get('ANALYTICS_DEV_ENABLED', fallback: 'false') == 'true',
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
      revenueCatApiKeyTest: dotenv.get('REVENUECAT_API_KEY_TEST', fallback: ''),
      // AI surfaces default ON for dev builds (2026-07-22, Lee): dev is the
      // proving ground for Describe/Photo meal logging, formula coach insights,
      // and the token/paywall surfaces. An explicit env value still wins in
      // either direction, and prod keeps the OFF fallback until the
      // release-gating decision flips.
      //
      // `aiCreditsEnabled` was missed by that change and kept a hard `false`
      // fallback, which made the token pill and the whole RevenueCat paywall
      // invisible in **Codemagic-built dev apps** — CI writes `.env.dev.local`
      // from the `DOTENV_DEV_LOCAL` secret, and that secret does not carry
      // `AI_CREDITS_ENABLED`. Local dev builds worked, because a developer's own
      // `.env.dev.local` sets it. Same class of bug as the
      // `ANALYTICS_DEV_ENABLED` gap patched in codemagic.yaml.
      aiCreditsEnabled:
          dotenv.get(
            'AI_CREDITS_ENABLED',
            fallback: isDevMode ? 'true' : 'false',
          ) ==
          'true',
      // Describe/photo meal AI ships everywhere (2026-08-10, Lee): prod
      // TestFlight needs the Describe tab visible to exercise real purchase
      // flows, so the release gate is pinned open — an env value no longer
      // hides it. Re-introduce the DESCRIBE_MEAL_ENABLED read here if the
      // gate ever needs to close again.
      describeMealEnabled: true,
      coachInsightsEnabled:
          dotenv.get(
            'COACH_INSIGHTS_ENABLED',
            fallback: isDevMode ? 'true' : 'false',
          ) ==
          'true',
      macroDashboardEnabled:
          dotenv.get('MACRO_DASHBOARD_ENABLED', fallback: 'false') == 'true',

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
    String revenueCatApiKeyTest = '',
    bool aiCreditsEnabled = false,
    bool describeMealEnabled = true,
    bool coachInsightsEnabled = true,
    bool macroDashboardEnabled = false,
    bool analyticsDevEnabled = false,
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
      revenueCatApiKeyTest: revenueCatApiKeyTest,
      aiCreditsEnabled: aiCreditsEnabled,
      describeMealEnabled: describeMealEnabled,
      coachInsightsEnabled: coachInsightsEnabled,
      macroDashboardEnabled: macroDashboardEnabled,
      analyticsDevEnabled: analyticsDevEnabled,
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
      analyticsDevEnabled:
          const String.fromEnvironment(
            'ANALYTICS_DEV_ENABLED',
            defaultValue: 'false',
          ) ==
          'true',
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
      revenueCatApiKeyTest: const String.fromEnvironment(
        'REVENUECAT_API_KEY_TEST',
        defaultValue: '',
      ),
      // Same dev-default-ON rule as fromEnv: an explicit define wins, an
      // absent one falls back to the flavor (dev shows the AI surfaces).
      aiCreditsEnabled: const String.fromEnvironment('AI_CREDITS_ENABLED') != ''
          ? const String.fromEnvironment('AI_CREDITS_ENABLED') == 'true'
          : isDevMode,
      // Pinned open — same rule as fromEnv (2026-08-10, Lee).
      describeMealEnabled: true,
      coachInsightsEnabled:
          const String.fromEnvironment('COACH_INSIGHTS_ENABLED') != ''
          ? const String.fromEnvironment('COACH_INSIGHTS_ENABLED') == 'true'
          : isDevMode,
      macroDashboardEnabled:
          const String.fromEnvironment('MACRO_DASHBOARD_ENABLED') == 'true',

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

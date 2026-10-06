/// The one bootstrap for all four entry points (spec: `.scratch/sentry/spec.md`
/// § Bootstrap; ticket 02). `main*.dart` is a one-line call to [bootstrap].
///
/// Shape, as the SDK documents it: `SentryFlutter.init(options,
/// appRunner: runApp)`. The SDK's own integrations wrap `FlutterError.onError`
/// and `PlatformDispatcher.onError` and run the app in a guarded zone, so a
/// crash arrives marked unhandled with the Flutter mechanism. App code installs
/// no handler of its own (`entry_points_test.dart` enforces that).
///
/// Non-recoverable setup lives here (CLAUDE.md § App Initialization Pattern):
/// env, Sentry, Supabase, bundled content defaults. Recoverable init belongs
/// to the startup flow. This file and `lib/shared/services/report/` are the
/// only places in `lib/` that may import the Sentry SDK.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_drift/sentry_drift.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../database/app_database.dart';
import '../../services/app_config.dart';
import '../../services/app_external_deps.dart';
import '../../services/privacy/analytics_consent.dart';
import '../../services/report/report.dart';
import '../../services/sentry/sentry_provider_observer.dart';
import '../../widgets/root_app_widget.dart';
import 'sentry_event_filter.dart';
import 'sentry_flavor_settings.dart';
import 'sentry_replay_sampling.dart';

export 'sentry_flavor_settings.dart' show AppFlavor;

/// The app router's navigator key. Sentry uses it for screenshots and the
/// feedback form; app code uses it to reach a context from outside the tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Boots the app for [flavor]. Never throws past the DSN check: a flavor
/// with no DSN runs the app with Sentry disabled and says so on the console.
Future<void> bootstrap(AppFlavor flavor) async {
  // Before Sentry init so the SDK's frame tracking sees the first frame.
  SentryWidgetsFlutterBinding.ensureInitialized();

  final config = await _loadConfig(flavor);
  final packageInfo = await PackageInfo.fromPlatform();

  // Consent must be resolved BEFORE Sentry is configured: session replay is
  // armed at init and cannot be disarmed for the rest of the session. The
  // cohort roll is persisted exactly once per install
  // (`sentry_replay_sampling.dart` has the battery story).
  final sharedPreferences = await SharedPreferences.getInstance();
  final replayCohortRate = flavor == AppFlavor.prod
      ? await resolveReplayOnErrorSampleRate(
          sharedPreferences,
          analyticsConsented: analyticsConsentGrantedFromPrefs(
            sharedPreferences,
          ),
        )
      : kReplayOff;

  final settings = SentryFlavorSettings.resolve(
    flavor,
    config: config,
    replayOnErrorCohortRate: replayCohortRate,
  );

  Future<void> runMealvana() => _runMealvanaApp(config, sharedPreferences);

  if (!settings.isEnabled) {
    // Rule D9: a silent path writes down what it did. There is no Sentry to
    // write to, so the console is the channel; the fallback to the prod DSN
    // that used to hide this is gone on purpose.
    debugPrint(
      '[bootstrap] FAULT: SENTRY_DSN is empty for flavor ${flavor.name}. '
      'Sentry is disabled for this run; nothing will be reported.',
    );
    await runMealvana();
    return;
  }

  await SentryFlutter.init(
    (options) => _configureSentry(options, settings, packageInfo),
    appRunner: runMealvana,
  );
}

Future<AppConfig> _loadConfig(AppFlavor flavor) async {
  switch (flavor) {
    case AppFlavor.dev:
      await dotenv.load(fileName: '.env.dev.local');
      return AppConfig.fromEnv();
    case AppFlavor.prod:
      await dotenv.load(fileName: '.env.prod.local');
      return AppConfig.fromEnv();
    case AppFlavor.web:
      // Web cannot ship an env file; values arrive as --dart-define.
      return AppConfig.fromDartDefines();
  }
}

void _configureSentry(
  SentryFlutterOptions options,
  SentryFlavorSettings settings,
  PackageInfo packageInfo,
) {
  options.dsn = settings.dsn;
  options.environment = settings.environment;

  // Must match what sentry_dart_plugin uploaded or symbolication fails
  // silently. Format: mealvana_endurance@1.20.0+42, dist 42.
  options.release =
      'mealvana_endurance@${packageInfo.version}+${packageInfo.buildNumber}';
  options.dist = packageInfo.buildNumber;

  // Profiling stays at its default (off): iOS-only alpha and paid, out of
  // scope (spec § Out of Scope).
  options.tracesSampleRate = settings.tracesSampleRate;

  options.debug = settings.debug;
  if (settings.debug) {
    // Keep the per-query "[sentry_drift] Active Sentry transaction does not
    // exist" chatter off the console; error/fatal diagnostics still print.
    options.diagnosticLevel = SentryLevel.error;
  }

  // Replay: never whole sessions; on-error only for the prod cohort. Text
  // and images are masked so a replay carries no personal content.
  options.replay.sessionSampleRate = settings.replaySessionSampleRate;
  options.replay.onErrorSampleRate = settings.replayOnErrorSampleRate;
  options.privacy.maskAllText = true;
  options.privacy.maskAllImages = true;

  // Identity is the Supabase user id plus role and device_id tags, set by
  // `Report.setUser`. No email, no default PII.
  options.sendDefaultPii = false;
  options.attachStacktrace = true;
  options.maxBreadcrumbs = 100;

  // App-hang detection only means something on a real device in release;
  // debugger, hot reload and JIT GC pauses trip the 2s threshold otherwise.
  options.enableAppHangTracking = !kDebugMode;

  // Navigation breadcrumbs come from the router's SentryNavigatorObserver;
  // this adds time-to-full-display on top of time-to-initial-display.
  options.enableTimeToFullDisplayTracing = true;

  // Stamp W3C `traceparent` (next to `sentry-trace`) on outgoing requests so
  // Supabase API-gateway and edge-function logs carry the app's trace id.
  options.propagateTraceparent = true;

  // Structured logs (`Report.info` / `Report.debug`).
  options.enableLogs = true;

  // One filter for every flavor: drops test-runner leaks, downgrades expected
  // failures to warnings, drops info/debug in release builds.
  options.beforeSend = (event, hint) => filterSentryEvent(event);

  options.beforeBreadcrumb = (breadcrumb, hint) {
    // Admin routes are not a trail worth keeping.
    if (breadcrumb?.category == 'navigation' &&
        breadcrumb?.data?['to']?.contains('admin') == true) {
      return null;
    }
    return breadcrumb;
  };

  // Screenshots on error and the feedback form need the navigator.
  options.navigatorKey = appNavigatorKey;
  options.attachScreenshot = true;
}

/// Runs inside the SDK's `appRunner` (or directly when Sentry is disabled).
Future<void> _runMealvanaApp(
  AppConfig config,
  SharedPreferences sharedPreferences,
) async {
  await _tagShorebirdPatch();

  // Drift spans (`db.sql.query` per statement, transaction, batch). The
  // database layer may not import the Sentry SDK (source guard), so the
  // interceptor is handed in here, before the first AppDatabase opens.
  // Native only, as before: the web executor never carried it.
  if (!kIsWeb) {
    AppDatabase.queryInterceptorFactory = () =>
        SentryQueryInterceptor(databaseName: 'mealvana_endurance');
  }

  // Two layers. The inner SentryHttpClient reports failed requests
  // (`SentryHttpClientError`, which the event filter's weather rule expects),
  // writes one `http` breadcrumb per request, including auth, storage and
  // edge calls, and stamps `sentry-trace`, `baggage` and `traceparent` on
  // every outgoing request. The outer SentrySupabaseClient adds a `db.*`
  // span per PostgREST call; its own breadcrumbs and errors are off so a
  // query is never recorded twice.
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseClientKey,
    httpClient: SentrySupabaseClient(
      enableBreadcrumbs: false,
      enableErrors: false,
      client: SentryHttpClient(),
    ),
  );

  // 1. SentryWidget: screenshots and session replay
  // 2. ProviderScope: Riverpod, with the provider-failure net attached. The
  //    observer and the retry hook are one object so a retried failure is a
  //    breadcrumb, not an event (spec § Riverpod).
  // 3. RootAppWidget: MaterialApp.router with Wiredash and AppStartupWidget
  final providerNet = SentryProviderObserver();
  runApp(
    SentryWidget(
      child: ProviderScope(
        observers: [providerNet],
        retry: providerNet.retry,
        overrides: [
          appConfigProvider.overrideWithValue(config),
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const RootAppWidget(),
      ),
    ),
  );
}

/// Tags every event with the Shorebird patch number so a patched release is
/// told apart from its base build. `none` on the base build and on web.
Future<void> _tagShorebirdPatch() async {
  int? patchNumber;
  try {
    final updater = ShorebirdUpdater();
    if (updater.isAvailable) {
      patchNumber = (await updater.readCurrentPatch())?.number;
    }
  } catch (error, stackTrace) {
    // The tag is diagnostic only; a failed read must not stop the launch,
    // but it is a startup Note so it is promoted to a warning (rule D9).
    await SentryReport.global.degraded(
      error,
      stackTrace: stackTrace,
      area: 'startup',
      message: 'Shorebird patch read failed; shorebird_patch tag left as none',
    );
  }
  await Sentry.configureScope(
    (scope) => scope.setTag('shorebird_patch', shorebirdPatchTag(patchNumber)),
  );
}

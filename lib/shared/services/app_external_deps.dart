import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics/analytics_tracker.dart';
import 'logging_service.dart';
import 'prefs_provider.dart';
import 'report/report.dart';
import 'sentry/sentry_reporter.dart';
import 'supabase/supabase_client_provider.dart';

// Re-export so all existing importers of app_external_deps.dart continue to
// find sharedPreferencesProvider without any import-site changes.
export 'prefs_provider.dart' show sharedPreferencesProvider;

class AppExternalDeps {
  const AppExternalDeps({
    required this.analytics,
    required this.supabaseClient,
    required this.sharedPreferences,
    this.report = const NoopReport(),
    @Deprecated('alias onto report; deleted by ticket 10') this.sentry,
    @Deprecated('alias onto report; deleted by ticket 10') this.logger,
  });

  final AnalyticsTracker analytics;
  final SupabaseClient supabaseClient;
  final SharedPreferences sharedPreferences;

  /// The one error service (CONTEXT.md § Error reporting).
  final Report report;

  /// Legacy aliases, optional so callers can stop passing them one by one.
  final SentryReporter? sentry;
  final AppLogger? logger;
}

final appExternalDepsProvider = Provider<AppExternalDeps>((ref) {
  final analytics = ref.watch(analyticsTrackerProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  final sentry = ref.watch(sentryReporterProvider);
  final logger = ref.watch(appLoggerProvider);
  final sharedPreferences = ref.watch(sharedPreferencesProvider);
  final report = ref.watch(reportProvider);
  return AppExternalDeps(
    analytics: analytics,
    supabaseClient: supabaseClient,
    sentry: sentry,
    logger: logger,
    sharedPreferences: sharedPreferences,
    report: report,
  );
});

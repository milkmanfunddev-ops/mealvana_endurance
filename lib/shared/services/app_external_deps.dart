import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics/analytics_tracker.dart';
import 'prefs_provider.dart';
import 'report/report.dart';
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
  });

  final AnalyticsTracker analytics;
  final SupabaseClient supabaseClient;
  final SharedPreferences sharedPreferences;

  /// The one error service (CONTEXT.md § Error reporting).
  final Report report;
}

final appExternalDepsProvider = Provider<AppExternalDeps>((ref) {
  final analytics = ref.watch(analyticsTrackerProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  final sharedPreferences = ref.watch(sharedPreferencesProvider);
  final report = ref.watch(reportProvider);
  return AppExternalDeps(
    analytics: analytics,
    supabaseClient: supabaseClient,
    sharedPreferences: sharedPreferences,
    report: report,
  );
});

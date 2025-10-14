import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics/analytics_tracker.dart';
import 'logging_service.dart';
import 'sentry/sentry_reporter.dart';
import 'supabase/supabase_client_provider.dart';

class AppExternalDeps {
  const AppExternalDeps({
    required this.analytics,
    required this.supabaseClient,
    required this.sentry,
    required this.logger,
  });

  final AnalyticsTracker analytics;
  final SupabaseClient supabaseClient;
  final SentryReporter sentry;
  final AppLogger logger;
}

final appExternalDepsProvider = Provider<AppExternalDeps>((ref) {
  final analytics = ref.watch(analyticsTrackerProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);
  final sentry = ref.watch(sentryReporterProvider);
  final logger = ref.watch(appLoggerProvider);
  return AppExternalDeps(
    analytics: analytics,
    supabaseClient: supabaseClient,
    sentry: sentry,
    logger: logger,
  );
});

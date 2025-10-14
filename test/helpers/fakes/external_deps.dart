import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_supabase_client.dart';
import 'recording_analytics_tracker.dart';
import 'recording_app_logger.dart';
import 'recording_sentry_reporter.dart';

/// Convenience factory for tests to create an [AppExternalDeps] bundle populated
/// with fake/recording implementations. Callers can override any dependency to
/// tailor behaviour for a specific suite while defaulting the rest.
AppExternalDeps buildTestExternalDeps({
  AnalyticsTracker? analytics,
  SupabaseClient? supabaseClient,
  SentryReporter? sentry,
  AppLogger? logger,
}) {
  return AppExternalDeps(
    analytics: analytics ?? RecordingAnalyticsTracker(),
    supabaseClient: supabaseClient ?? FakeSupabaseClient(),
    sentry: sentry ?? RecordingSentryReporter(),
    logger: logger ?? RecordingAppLogger(),
  );
}

/// Riverpod override helper so tests can swap the production [appExternalDepsProvider]
/// with the fake bundle produced by [buildTestExternalDeps].
Override overrideAppExternalDeps({
  AnalyticsTracker? analytics,
  SupabaseClient? supabaseClient,
  SentryReporter? sentry,
  AppLogger? logger,
}) {
  return appExternalDepsProvider.overrideWithValue(
    buildTestExternalDeps(
      analytics: analytics,
      supabaseClient: supabaseClient,
      sentry: sentry,
      logger: logger,
    ),
  );
}

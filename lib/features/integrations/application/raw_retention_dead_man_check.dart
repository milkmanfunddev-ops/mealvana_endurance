import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';

/// Dead-man watch for the raw-retention sweep (real-payload-corpus@v1,
/// lifecycle.md L-7 item 4).
///
/// The sweep's own alerting runs INSIDE the pg_cron job, so a dead scheduler
/// silences its own alarm. This check watches the audit row's freshness from
/// OUTSIDE the scheduler: during sync, if the newest `raw_retention_audit`
/// row is older than 48 hours (or missing entirely — a scheduler that never
/// ran is the same failure), a Sentry warning fires.
///
/// Mixed-fleet safety: a client running this code against a database that
/// does not carry the audit table yet (or where RLS denies the read) gets a
/// query error — swallowed silently, never a false alarm and never a failed
/// sync. Throttled to once per [recheckInterval] per app process.
/// Returns the newest sweep timestamp, or null when no sweep has ever run.
typedef NewestSweepFetcher = Future<DateTime?> Function();

class RawRetentionDeadManCheck {
  RawRetentionDeadManCheck({
    required SupabaseClient supabase,
    required SentryReporter sentry,
    AppLogger? logger,
    NewestSweepFetcher? fetchNewestSweep,
  }) : _supabase = supabase,
       _sentry = sentry,
       _logger = logger ?? const NoopAppLogger(),
       _fetchNewestSweep = fetchNewestSweep;

  final SupabaseClient _supabase;

  /// Seam for DI-27: the audit read, injectable so the behaviour can be
  /// driven in both directions without standing up a PostgREST chain.
  /// Null means "use the real Supabase read" (production path).
  final NewestSweepFetcher? _fetchNewestSweep;
  final SentryReporter _sentry;
  final AppLogger _logger;

  static const staleThreshold = Duration(hours: 48);
  static const recheckInterval = Duration(hours: 12);

  DateTime? _lastCheckedAt;

  /// Reads the newest audit row's timestamp from Supabase (production path).
  Future<DateTime?> _readNewestSweepFromSupabase() async {
    final rows = await _supabase
        .from('raw_retention_audit')
        .select('swept_at')
        .order('swept_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['swept_at'] as String? ?? '');
  }

  /// Best-effort; never throws.
  Future<void> checkDuringSync() async {
    final now = DateTime.now().toUtc();
    final last = _lastCheckedAt;
    if (last != null && now.difference(last) < recheckInterval) return;
    _lastCheckedAt = now;

    try {
      final newest = await (_fetchNewestSweep ?? _readNewestSweepFromSupabase)();
      final age = newest == null ? null : now.difference(newest.toUtc());
      final stale = age == null || age > staleThreshold;
      if (!stale) return;

      _logger.warning(
        'Raw-retention sweep stale',
        context: 'RAW_RETENTION_DEAD_MAN',
        data: {'newestSweptAt': newest?.toIso8601String()},
      );
      await _sentry.captureMessage(
        'raw_retention_sweep_stale',
        level: SentryLevel.warning,
        tags: {'component': 'raw_retention'},
        extra: {
          'newest_swept_at': newest?.toIso8601String() ?? 'never',
          'age_hours': age?.inHours,
          'threshold_hours': staleThreshold.inHours,
        },
        // One issue regardless of which device notices first.
        fingerprint: const ['raw_retention_sweep_stale'],
      );
    } catch (_) {
      // Table absent / RLS / offline: silence is correct here — this check
      // must never fail a sync or false-alarm a pre-migration database.
    }
  }
}

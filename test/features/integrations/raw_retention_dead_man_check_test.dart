/// DI-27 — the dead-man clause behaves in BOTH directions.
///
/// L-7 item 4: the sweep's own alerting runs inside the scheduler, so a dead
/// scheduler silences its own alarm. This check watches audit-row freshness
/// from outside it. The implementation landed untested; these are its reds.
///
/// The contract, both ways:
///   newest audit row older than 48h (or none at all) => Degraded report
///   fresh audit row                                   => silence
/// plus the properties that keep it safe to run on every sync: a failing
/// read never throws and never alerts (it leaves a Note), and the 12h
/// throttle holds.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/integrations/application/raw_retention_dead_man_check.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes/recording_report.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  RawRetentionDeadManCheck build(
    RecordingReport report,
    NewestSweepFetcher fetch,
  ) => RawRetentionDeadManCheck(
    supabase: MockSupabaseClient(),
    report: report,
    fetchNewestSweep: fetch,
  );

  test('a sweep older than 48h fires a Degraded report', () async {
    final report = RecordingReport();
    final stale = DateTime.now().toUtc().subtract(const Duration(hours: 49));
    await build(report, () async => stale).checkDuringSync();

    final degraded = report.degradeds.single;
    expect(degraded.error.toString(), 'raw_retention_sweep_stale');
    expect(degraded.area, 'integrations');
    expect(degraded.tags, {'component': 'raw_retention'});
    expect(degraded.extra?['age_hours'], 49);
    expect(report.faults, isEmpty);
  });

  test('a sweep that has NEVER run is treated as stale, not as healthy', () async {
    final report = RecordingReport();
    await build(report, () async => null).checkDuringSync();
    expect(report.degradeds, hasLength(1));
    expect(report.degradeds.single.extra?['newest_swept_at'], 'never');
  });

  test('a fresh sweep is silent', () async {
    final report = RecordingReport();
    final fresh = DateTime.now().toUtc().subtract(const Duration(hours: 2));
    await build(report, () async => fresh).checkDuringSync();
    expect(report.calls, isEmpty);
  });

  test('exactly at the 48h threshold is still fresh (strictly-older, as ruled)', () async {
    final report = RecordingReport();
    // A hair inside 48h: the boundary belongs to "fresh".
    final boundary = DateTime.now().toUtc().subtract(
      const Duration(hours: 47, minutes: 59),
    );
    await build(report, () async => boundary).checkDuringSync();
    expect(report.calls, isEmpty);
  });

  test('a failing audit read never throws and never alerts — it must not '
      'alarm a database that predates the migration; it leaves a Note', () async {
    final report = RecordingReport();
    final check = build(report, () async => throw StateError('no such table'));
    await expectLater(check.checkDuringSync(), completes);
    expect(report.degradeds, isEmpty);
    expect(report.faults, isEmpty);
    final note = report.notes.single;
    expect(note.area, 'integrations');
    expect(note.data?['error'], contains('no such table'));
  });

  test('the 12h throttle holds: a second sync does not re-read or re-alert', () async {
    final report = RecordingReport();
    var reads = 0;
    final stale = DateTime.now().toUtc().subtract(const Duration(hours: 72));
    final check = build(report, () async {
      reads++;
      return stale;
    });

    await check.checkDuringSync();
    await check.checkDuringSync();
    await check.checkDuringSync();

    expect(reads, 1, reason: 'throttled to one read per interval');
    expect(report.degradeds, hasLength(1));
  });
}

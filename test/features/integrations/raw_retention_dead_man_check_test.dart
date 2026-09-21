/// DI-27 — the dead-man clause behaves in BOTH directions.
///
/// L-7 item 4: the sweep's own alerting runs inside the scheduler, so a dead
/// scheduler silences its own alarm. This check watches audit-row freshness
/// from outside it. The implementation landed untested; these are its reds.
///
/// The contract, both ways:
///   newest audit row older than 48h (or none at all) => Sentry warning
///   fresh audit row                                   => silence
/// plus the properties that keep it safe to run on every sync: a failing
/// read never throws and never alerts, and the 12h throttle holds.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/integrations/application/raw_retention_dead_man_check.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSentryReporter extends Mock implements SentryReporter {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(SentryLevel.warning);
  });

  RawRetentionDeadManCheck build(
    MockSentryReporter sentry,
    NewestSweepFetcher fetch,
  ) =>
      RawRetentionDeadManCheck(
        supabase: MockSupabaseClient(),
        sentry: sentry,
        fetchNewestSweep: fetch,
      );

  MockSentryReporter sentryStub() {
    final s = MockSentryReporter();
    when(
      () => s.captureMessage(
        any(),
        level: any(named: 'level'),
        tags: any(named: 'tags'),
        extra: any(named: 'extra'),
        fingerprint: any(named: 'fingerprint'),
      ),
    ).thenAnswer((_) async {});
    return s;
  }

  test('a sweep older than 48h fires the Sentry warning', () async {
    final sentry = sentryStub();
    final stale = DateTime.now().toUtc().subtract(const Duration(hours: 49));
    await build(sentry, () async => stale).checkDuringSync();

    final captured = verify(
      () => sentry.captureMessage(
        captureAny(),
        level: captureAny(named: 'level'),
        tags: any(named: 'tags'),
        extra: any(named: 'extra'),
        fingerprint: captureAny(named: 'fingerprint'),
      ),
    ).captured;
    expect(captured[0], 'raw_retention_sweep_stale');
    expect(captured[1], SentryLevel.warning);
    // One issue however many devices notice it.
    expect(captured[2], ['raw_retention_sweep_stale']);
  });

  test('a sweep that has NEVER run is treated as stale, not as healthy',
      () async {
    final sentry = sentryStub();
    await build(sentry, () async => null).checkDuringSync();
    verify(
      () => sentry.captureMessage(
        any(),
        level: any(named: 'level'),
        tags: any(named: 'tags'),
        extra: any(named: 'extra'),
        fingerprint: any(named: 'fingerprint'),
      ),
    ).called(1);
  });

  test('a fresh sweep is silent', () async {
    final sentry = sentryStub();
    final fresh = DateTime.now().toUtc().subtract(const Duration(hours: 2));
    await build(sentry, () async => fresh).checkDuringSync();
    verifyNever(
      () => sentry.captureMessage(
        any(),
        level: any(named: 'level'),
        tags: any(named: 'tags'),
        extra: any(named: 'extra'),
        fingerprint: any(named: 'fingerprint'),
      ),
    );
  });

  test('exactly at the 48h threshold is still fresh (strictly-older, as ruled)',
      () async {
    final sentry = sentryStub();
    // A hair inside 48h: the boundary belongs to "fresh".
    final boundary =
        DateTime.now().toUtc().subtract(const Duration(hours: 47, minutes: 59));
    await build(sentry, () async => boundary).checkDuringSync();
    verifyNever(
      () => sentry.captureMessage(
        any(),
        level: any(named: 'level'),
        tags: any(named: 'tags'),
        extra: any(named: 'extra'),
        fingerprint: any(named: 'fingerprint'),
      ),
    );
  });

  test('a failing audit read is silent and never throws — it must not '
      'alarm a database that predates the migration', () async {
    final sentry = sentryStub();
    final check = build(sentry, () async => throw StateError('no such table'));
    await expectLater(check.checkDuringSync(), completes);
    verifyNever(
      () => sentry.captureMessage(
        any(),
        level: any(named: 'level'),
        tags: any(named: 'tags'),
        extra: any(named: 'extra'),
        fingerprint: any(named: 'fingerprint'),
      ),
    );
  });

  test('the 12h throttle holds: a second sync does not re-read or re-alert',
      () async {
    final sentry = sentryStub();
    var reads = 0;
    final stale = DateTime.now().toUtc().subtract(const Duration(hours: 72));
    final check = build(sentry, () async {
      reads++;
      return stale;
    });

    await check.checkDuringSync();
    await check.checkDuringSync();
    await check.checkDuringSync();

    expect(reads, 1, reason: 'throttled to one read per interval');
    verify(
      () => sentry.captureMessage(
        any(),
        level: any(named: 'level'),
        tags: any(named: 'tags'),
        extra: any(named: 'extra'),
        fingerprint: any(named: 'fingerprint'),
      ),
    ).called(1);
  });
}

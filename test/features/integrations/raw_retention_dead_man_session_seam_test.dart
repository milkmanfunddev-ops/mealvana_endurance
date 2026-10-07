// DEV-9B (round-up 2026-10): `raw_retention_sweep_stale` fired twice (09-25,
// 10-01) for user 4a74be96 while the dev sweep ran every night at 03:17 UTC
// (cron.job_run_details: succeeded daily; newest audit row 10-06 03:17).
//
// The 10-01 trail: "User signed out" at 17:03:04.970, then the dead-man read
// `GET raw_retention_audit?select=swept_at` at 17:03:05.459, then the alarm.
// The table's only read policy admits `authenticated` / `service_role`, so a
// read with no session is answered 200 [] by PostgREST, which the check took
// for "no sweep has ever run". RLS answers an anon SELECT with zero rows,
// not an error, so the class's own promise ("where RLS denies the read: a
// Note, never a false alarm") did not hold.
//
// Real check, real PostgREST client; the seam is the HTTP boundary, faked by
// a server that applies that policy.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/integrations/application/raw_retention_dead_man_check.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_report.dart';

class _MockUser extends Mock implements User {}

void main() {
  String? sessionUserId;
  late List<String> auditRows;
  late int reads;

  RawRetentionDeadManCheck build(RecordingReport report) {
    final real = SupabaseClient(
      'http://fake-supabase.local',
      'anon-key',
      httpClient: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/rest/v1/raw_retention_audit')) {
          reads++;
          // "Authenticated can read retention audit": anon sees nothing.
          final visible = sessionUserId == null
              ? const <Object>[]
              : [
                  for (final at in auditRows) {'swept_at': at},
                ];
          return http.Response(
            jsonEncode(visible),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
            request: request,
          );
        }
        return http.Response('{}', 404, request: request);
      }),
    );
    addTearDown(real.dispose);
    final goTrue = fakeGoTrueClient();
    when(() => goTrue.currentUser).thenAnswer((_) {
      final uid = sessionUserId;
      if (uid == null) return null;
      final user = _MockUser();
      when(() => user.id).thenReturn(uid);
      return user;
    });
    final client = fakeSupabaseClient(auth: goTrue) as MockSupabaseClient;
    when(
      () => client.from(any()),
    ).thenAnswer((i) => real.from(i.positionalArguments.first as String));
    return RawRetentionDeadManCheck(supabase: client, report: report);
  }

  setUp(() {
    reads = 0;
    // Last night's sweep: fresh by any measure.
    auditRows = [
      DateTime.now().toUtc().subtract(const Duration(hours: 14)).toIso8601String(),
    ];
  });

  test('signed out: the audit rows are invisible, which is not "never '
      'swept"; no alarm, and the skip is a Note (DEV-9B)', () async {
    sessionUserId = null;
    final report = RecordingReport();
    await build(report).checkDuringSync();

    expect(report.degradeds, isEmpty, reason: 'a false alarm');
    expect(report.faults, isEmpty);
    expect(report.notes.single.area, 'sync');
  });

  test('signed in with a fresh sweep: silent', () async {
    sessionUserId = '4a74be96-fce8-4894-a82c-2a77199d601d';
    final report = RecordingReport();
    await build(report).checkDuringSync();

    expect(reads, 1);
    expect(report.calls, isEmpty);
  });

  test('signed in and the table really is empty: still the alarm', () async {
    sessionUserId = '4a74be96-fce8-4894-a82c-2a77199d601d';
    auditRows = [];
    final report = RecordingReport();
    await build(report).checkDuringSync();

    expect(report.degradeds.single.extra?['newest_swept_at'], 'never');
  });

  test('a signed-out skip does not spend the 12h throttle: the next signed-in '
      'sync still checks', () async {
    final report = RecordingReport();
    final check = build(report);

    sessionUserId = null;
    await check.checkDuringSync();
    expect(report.degradeds, isEmpty);

    sessionUserId = '4a74be96-fce8-4894-a82c-2a77199d601d';
    auditRows = [];
    await check.checkDuringSync();

    expect(reads, 1, reason: 'only the signed-in check read the table');
    expect(report.degradeds.single.extra?['newest_swept_at'], 'never');
  });
}

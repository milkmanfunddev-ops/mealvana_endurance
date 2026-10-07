// Seam test for DEV-A2 (round-up 2026-10): the `users` upload must respect
// the server's RLS policy, the way ticket 16 made the integrations upload
// respect it.
//
// The event (1.29.0+6, 2026-10-01): a sync started for user 4a74be96 and
// marked the profile dirty; 0.13 s later the athlete signed out and went to
// the welcome screen; the in-flight sync then upserted the dirty `users` row
// with no session at all. PostgREST answered 403 / 42501 "new row violates
// row-level security policy for table "users"", and SyncCoordinator turned
// that into a Fault. The policy is correct (`users_insert_own` /
// `users_update_own`: `id = auth.uid()`, read from the dev database), so the
// fix is the client's.
//
// Everything on our side runs for real: UserRepository, in-memory Drift, the
// real PostgREST client. The seam is the HTTP boundary, faked by a server
// that applies that policy and answers with PostgREST's wire shape.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_report.dart';

class _MockUser extends Mock implements User {}

const _athlete = '4a74be96-fce8-4894-a82c-2a77199d601d';
const _otherUser = 'e377ed4e-a3e0-4250-acb0-b9ca12bd80e2';

/// Fake PostgREST applying the dev `users` write policies.
class _FakePostgrest {
  String? sessionUserId;
  final List<Map<String, dynamic>> userPosts = [];

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'POST' && path.endsWith('/rest/v1/users')) {
      final decoded = jsonDecode(request.body);
      final rows = (decoded is List ? decoded : [decoded])
          .cast<Map<String, dynamic>>();
      userPosts.addAll(rows);
      for (final row in rows) {
        // users_insert_own / users_update_own: id = auth.uid()
        if (row['id'] != sessionUserId) {
          return _json({
            'code': '42501',
            'details': null,
            'hint': null,
            'message':
                'new row violates row-level security policy for table "users"',
          }, 403);
        }
      }
      return http.Response('', 201);
    }
    return _json({'message': 'unexpected ${request.method} $path'}, 404);
  }

  static http.Response _json(Object body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

UserProfile _profile(String id) => UserProfile(
  id: id,
  deviceId: 'device-a2',
  gender: Gender.male,
  birthday: DateTime(1985, 3, 20),
  heightFeet: 5,
  heightInches: 11,
  weightPounds: 150,
  runsWithWaterBottle: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 10, 1),
  appVersion: '1.29.0+6',
);

void main() {
  late AppDatabase db;
  late RecordingReport report;
  late _FakePostgrest server;
  late UserRepository repository;

  UserRepository build() {
    final real = SupabaseClient(
      'http://fake-supabase.local',
      'anon-key',
      httpClient: MockClient((request) async {
        // Real responses carry their request; postgrest reads it.
        final res = await server.handle(request);
        return http.Response(
          res.body,
          res.statusCode,
          headers: res.headers,
          request: request,
        );
      }),
    );
    addTearDown(real.dispose);
    final goTrue = fakeGoTrueClient();
    when(() => goTrue.currentUser).thenAnswer((_) {
      final uid = server.sessionUserId;
      if (uid == null) return null;
      final user = _MockUser();
      when(() => user.id).thenReturn(uid);
      return user;
    });
    final client = fakeSupabaseClient(auth: goTrue) as MockSupabaseClient;
    when(
      () => client.from(any()),
    ).thenAnswer((i) => real.from(i.positionalArguments.first as String));
    return UserRepository(database: db, supabase: client, report: report);
  }

  Future<bool> isDirty(String id) async =>
      (await (db.select(
        db.userProfilesTable,
      )..where((t) => t.id.equals(id))).getSingle()).needsUpload;

  setUp(() {
    db = AppDatabase.memory();
    addTearDown(db.close);
    report = RecordingReport();
    server = _FakePostgrest();
    repository = build();
  });

  test('signed out while a sync is in flight: the dirty profile is not '
      'pushed, stays dirty, and the skip is a promoted sync Note (DEV-A2)', () async {
    server.sessionUserId = _athlete;
    await repository.saveUserProfile(_profile(_athlete), needsUpload: true);

    // Sign-out lands before the in-flight sync reaches the upload.
    server.sessionUserId = null;
    final result = await repository.uploadDirtyRecords(_athlete);

    expect(server.userPosts, isEmpty, reason: 'no POST without its session');
    expect(result.success, isFalse);
    expect(result.deferred, isTrue);
    expect(result.count, 0);
    expect(await isDirty(_athlete), isTrue);
    expect(report.faults, isEmpty);
    expect(report.degradeds, isEmpty);
    final skip = report.notes.single;
    expect(skip.area, 'sync');
    expect(skip.data?['rowUserId'], _athlete);
    expect(skip.data?['hasSession'], isFalse);

    // The owner signs back in: the dirty profile uploads and is clean.
    server.sessionUserId = _athlete;
    final back = await repository.uploadDirtyRecords(_athlete);
    expect(back.success, isTrue);
    expect(back.count, 1);
    expect(server.userPosts.single['id'], _athlete);
    expect(await isDirty(_athlete), isFalse);
  });

  test('another user is signed in: the previous user\'s profile is not '
      'pushed under their session', () async {
    server.sessionUserId = _athlete;
    await repository.saveUserProfile(_profile(_athlete), needsUpload: true);

    server.sessionUserId = _otherUser;
    final result = await repository.uploadDirtyRecords(_athlete);

    expect(server.userPosts, isEmpty);
    expect(result.deferred, isTrue);
    expect(await isDirty(_athlete), isTrue);
    expect(report.faults, isEmpty);
    expect(report.notes.single.data?['sessionUserId'], _otherUser);
  });

  test('the session matches in a different case: it uploads (the activities '
      'code lowercases ids, Supabase does not)', () async {
    server.sessionUserId = _athlete;
    await repository.saveUserProfile(_profile(_athlete), needsUpload: true);

    // The session reports the id upper-cased; the row is the same user.
    final goTrue = (repository.supabase as MockSupabaseClient).auth;
    final upper = _MockUser();
    when(() => upper.id).thenReturn(_athlete.toUpperCase());
    when(() => goTrue.currentUser).thenReturn(upper);

    final result = await repository.uploadDirtyRecords(_athlete);
    expect(result.success, isTrue);
    expect(result.count, 1);
    expect(report.notes, isEmpty);
  });
}

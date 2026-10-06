// Seam test for ticket 16 (Sentry MEALVANA-ENDURANCE-3W): integrations
// writes must respect the server's RLS policy and foreign key.
//
// Prod events: after sign-out, Get Started on the welcome screen signs in a
// fresh anonymous user. A write that still carried the previous user's id
// then reached `POST /rest/v1/integrations` under the new session and
// PostgREST answered 403 / 42501. Before the profile row exists, a provider
// connected during onboarding answered 409 / 23503.
//
// Everything on our side runs for real: IntegrationsRepository, in-memory
// Drift, the real PostgREST client. The seam is the HTTP boundary, faked by
// a server that applies the prod policy (`auth.uid() = user_id` on insert,
// `users_select_own` on the parent-row probe, the `integrations_user_id_fkey`
// check) and answers with PostgREST's wire shape for each failure.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_report.dart';

class _MockUser extends Mock implements User {}

const _previousUser = 'e92cb452-0368-4bb3-a888-3e86a65d097f';
const _anonUser = 'e377ed4e-a3e0-4250-acb0-b9ca12bd80e2';

/// Fake PostgREST applying the prod `integrations` + `users` policies.
class _FakePostgrest {
  _FakePostgrest({required this.remoteUsers});

  String? sessionUserId;
  final Set<String> remoteUsers;
  final List<List<Map<String, dynamic>>> integrationPosts = [];

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path.endsWith('/rest/v1/users')) {
      final id = (request.url.queryParameters['id'] ?? '').replaceFirst(
        'eq.',
        '',
      );
      // users_select_own: (id = auth.uid()) — coaches aside.
      final visible = remoteUsers.contains(id) && id == sessionUserId;
      return _json(
        visible
            ? [
                {'id': id},
              ]
            : <Object>[],
        200,
      );
    }
    if (request.method == 'POST' && path.endsWith('/rest/v1/integrations')) {
      final decoded = jsonDecode(request.body);
      final rows = (decoded is List ? decoded : [decoded])
          .cast<Map<String, dynamic>>();
      integrationPosts.add(rows);
      for (final row in rows) {
        if (row['user_id'] != sessionUserId) {
          return _json({
            'code': '42501',
            'details': null,
            'hint': null,
            'message':
                'new row violates row-level security policy for table "integrations"',
          }, 403);
        }
        if (!remoteUsers.contains(row['user_id'])) {
          return _json({
            'code': '23503',
            'details': 'Key is not present in table "users".',
            'hint': null,
            'message':
                'insert or update on table "integrations" violates foreign key constraint "integrations_user_id_fkey"',
          }, 409);
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

void main() {
  late AppDatabase db;
  late RecordingReport report;
  late _FakePostgrest server;
  late IntegrationsRepository repository;

  IntegrationsRepository build() {
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
    return IntegrationsRepository(
      database: db,
      supabase: client,
      report: report,
    );
  }

  Future<Integration> rowFor(String userId) async => (db.select(
    db.integrationsTable,
  )..where((t) => t.userId.equals(userId))).getSingle();

  IntegrationModel tp(String userId) => IntegrationModel(
    userId: userId,
    provider: 'training_peaks',
    accessToken: 'tp-token',
    providerAthleteId: 'tp-athlete-1',
    isActive: true,
  );

  setUp(() {
    db = AppDatabase.memory();
    addTearDown(db.close);
    report = RecordingReport();
    server = _FakePostgrest(remoteUsers: {_previousUser});
  });

  test('a write for the previous user lands after Get Started signed in a '
      'fresh anonymous user: nothing is pushed, the row stays dirty, a '
      'promoted Note records the skip', () async {
    // The previous user is signed in and connected.
    server.sessionUserId = _previousUser;
    repository = build();
    await repository.upsertIntegration(tp(_previousUser));
    expect(server.integrationPosts, hasLength(1));
    expect((await rowFor(_previousUser)).needsUpload, isFalse);

    // Sign-out, then Get Started: a fresh anonymous session. A provider sync
    // that captured the previous id finishes now.
    server.sessionUserId = _anonUser;
    await repository.updateSyncStatus(
      _previousUser,
      'training_peaks',
      status: 'success',
    );

    expect(server.integrationPosts, hasLength(1), reason: 'no second POST');
    expect((await rowFor(_previousUser)).needsUpload, isTrue);
    expect(report.faults, isEmpty);
    expect(report.degradeds, isEmpty);
    final skip = report.notes.single;
    expect(skip.area, 'sync');
    expect(skip.data?['rowUserId'], _previousUser);
    expect(skip.data?['sessionUserId'], _anonUser);
    expect(skip.data?['path'], 'immediate');

    // The dirty-record pass under the anonymous session defers too.
    final result = await repository.uploadDirtyRecords(_previousUser);
    expect(result.success, isTrue);
    expect(result.count, 0);
    expect(server.integrationPosts, hasLength(1));

    // The owner signs back in: the dirty row uploads.
    server.sessionUserId = _previousUser;
    final back = await repository.uploadDirtyRecords(_previousUser);
    expect(back.count, 1);
    expect(server.integrationPosts, hasLength(2));
    expect((await rowFor(_previousUser)).needsUpload, isFalse);
  });

  test('signed out entirely: the immediate push is skipped', () async {
    server.sessionUserId = null;
    repository = build();
    await repository.upsertIntegration(tp(_previousUser));

    expect(server.integrationPosts, isEmpty);
    expect((await rowFor(_previousUser)).needsUpload, isTrue);
    expect(report.notes.single.data?['hasSession'], isFalse);
    expect(report.degradeds, isEmpty);
  });

  test('anonymous onboarding connects a provider before the profile row is '
      'remote: deferred without a 23503, uploads once the row lands', () async {
    server.sessionUserId = _anonUser;
    repository = build();
    await repository.upsertIntegration(tp(_anonUser));

    expect(server.integrationPosts, isEmpty);
    expect((await rowFor(_anonUser)).needsUpload, isTrue);
    expect(report.degradeds, isEmpty);
    expect(report.faults, isEmpty);

    server.remoteUsers.add(_anonUser);
    final result = await repository.uploadDirtyRecords(_anonUser);
    expect(result.count, 1);
    expect(server.integrationPosts.single.single['user_id'], _anonUser);
    expect((await rowFor(_anonUser)).needsUpload, isFalse);
  });
}

/// [GrantSourceRepository] (mp-615) against PostgREST answering at the wire:
/// the `pro_grants` rows as the table holds them (migration
/// 20260926070000_pro_grants_source.sql), the query it sends, and an empty
/// answer whenever the read cannot be made.
///
///   flutter test test/features/subscription/data/grant_source_repository_test.dart
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/subscription/data/grant_source_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/grant.dart';

const _userId = '6f1c2b1e-0000-4000-8000-00000000c0ac';

void main() {
  late List<http.Request> requests;

  GrantSourceRepository answering(
    http.Response Function(http.Request req) respond, {
    String? userId = _userId,
  }) {
    requests = [];
    return GrantSourceRepository(
      supabase: SupabaseClient(
        'https://example.supabase.co',
        'anon',
        httpClient: MockClient((req) async {
          requests.add(req);
          return respond(req);
        }),
      ),
      currentUserId: () => userId,
      timeout: const Duration(seconds: 1),
    );
  }

  // PostgREST's client reads the request back off the response.
  http.Response Function(http.Request) rows(List<Map<String, Object?>> body) =>
      (req) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
        request: req,
      );

  test('reads its own newest rows and maps each source', () async {
    final repo = answering(
      rows([
        {
          'source': 'coach',
          'pro_days': 30,
          'granted_at': '2026-10-05T12:00:03.412+00:00',
        },
        {
          'source': 'grace',
          'pro_days': 30,
          'granted_at': '2026-10-01T15:02:11.9+00:00',
        },
        {
          'source': 'code',
          'pro_days': 365,
          'granted_at': '2026-09-22T10:00:00+00:00',
        },
      ]),
    );

    final records = await repo.recentGrants();

    expect(records.map((r) => r.source), [
      GrantSource.coach,
      GrantSource.legacyGrace,
      GrantSource.code,
    ]);
    expect(records.first.grantedAt, DateTime.utc(2026, 10, 5, 12, 0, 3, 412));
    expect(records.first.proDays, 30);

    final query = requests.single.url;
    expect(query.path, '/rest/v1/pro_grants');
    expect(query.queryParameters['user_id'], 'eq.$_userId');
    expect(query.queryParameters['order'], 'granted_at.desc.nullslast');
    expect(query.queryParameters['limit'], '5');
  });

  test('a source this build does not know reads as no source', () async {
    final repo = answering(
      rows([
        {
          'source': 'partner',
          'pro_days': 60,
          'granted_at': '2026-10-05T12:00:00+00:00',
        },
      ]),
    );
    final records = await repo.recentGrants();
    expect(records.single.source, isNull);
  });

  test('signed out: nothing is asked', () async {
    final repo = answering(rows([]), userId: null);
    expect(await repo.recentGrants(), isEmpty);
    expect(requests, isEmpty);
  });

  test('a refused read (the table not there yet) answers no records', () async {
    final repo = answering(
      (req) => http.Response(
        jsonEncode({
          'code': '42P01',
          'message': 'relation "public.pro_grants" does not exist',
        }),
        404,
        headers: {'content-type': 'application/json'},
        request: req,
      ),
    );
    expect(await repo.recentGrants(), isEmpty);
  });

  test('offline answers no records', () async {
    final repo = answering(
      (_) => throw http.ClientException('Connection refused'),
    );
    expect(await repo.recentGrants(), isEmpty);
  });
}

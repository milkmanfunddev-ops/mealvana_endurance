// A real SupabaseClient whose HTTP goes to an in-memory PostgREST.
//
// Repositories build their queries with the real postgrest-dart builder, so
// a test exercises the real `syncFromRemote` / `uploadDirtyRecords` code end
// to end; only the wire is faked. GETs answer the rows in [FakePostgrest.tables]
// filtered by `eq.` params; writes are recorded and either accepted or, for a
// table in [FakePostgrest.rejectWrites], refused the way RLS refuses them.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakePostgrest {
  FakePostgrest();

  /// The server's rows per table.
  final Map<String, List<Map<String, dynamic>>> tables = {};

  /// Tables whose writes the server refuses with PostgREST 42501 (RLS).
  final Set<String> rejectWrites = {};

  /// Every write, in order: (method, table, decoded body).
  final List<({String method, String table, Object? body})> writes = [];

  late final SupabaseClient client = SupabaseClient(
    'http://fake-postgrest.test',
    'anon-key',
    httpClient: MockClient(_handle),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  Future<http.Response> _handle(http.Request request) async {
    final segments = request.url.pathSegments;
    if (segments.length < 3 || segments[0] != 'rest') {
      return _json(request, 404, {'message': 'not faked: ${request.url}'});
    }
    final table = segments[2];

    if (request.method == 'GET' || request.method == 'HEAD') {
      final rows = _filter(tables[table] ?? const [], request.url);
      final wantsObject =
          request.headers['Accept'] == 'application/vnd.pgrst.object+json';
      if (!wantsObject) return _json(request, 200, rows);
      if (rows.length == 1) return _json(request, 200, rows.single);
      return _json(request, 406, {
        'code': 'PGRST116',
        'message': 'JSON object requested, multiple (or no) rows returned',
        'details': 'The result contains ${rows.length} rows',
        'hint': null,
      });
    }

    final body = request.body.isEmpty ? null : jsonDecode(request.body);
    writes.add((method: request.method, table: table, body: body));
    if (rejectWrites.contains(table)) {
      return _json(request, 403, {
        'code': '42501',
        'message':
            'new row violates row-level security policy for table "$table"',
        'details': null,
        'hint': null,
      });
    }
    return _json(request, 201, body is List ? body : [if (body != null) body]);
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> rows, Uri url) {
    var out = rows;
    url.queryParameters.forEach((column, value) {
      if (!value.startsWith('eq.')) return;
      final wanted = value.substring(3);
      out = out.where((r) => '${r[column]}' == wanted).toList();
    });
    return out;
  }

  // postgrest-dart reads `response.request`, so every answer carries it.
  http.Response _json(http.Request request, int status, Object? body) =>
      http.Response(
        jsonEncode(body),
        status,
        request: request,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}

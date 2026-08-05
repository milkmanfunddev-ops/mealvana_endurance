/// Authenticated read-only probe into Supabase, for asserting that a flow's
/// write actually landed.
///
/// **Why this exists.** Every Patrol flow asserts on the widget tree and
/// nothing else, so "I created a brick" has meant "a tile appeared". That is
/// exactly the blind spot bf0b591f had to cover by hand: re-saving a brick
/// silently erased its provenance (`originalActivityIds` /
/// `createdFromExisting`), and no UI-only test can see that — the screen looks
/// identical either way.
///
/// **Why the existing DatabaseVerification helper never worked.** It sends the
/// anon key as the bearer token. Under RLS an anon request is not the test
/// user, so every query returns `200 []` — indistinguishable from "the write
/// was lost". Verified directly on 2026-08-03: the anon query returned `[]`
/// while the rows were plainly present.
///
/// **What this does instead.** It exchanges the credentials the suite already
/// has — `INTEGRATION_TEST_EMAIL` / `INTEGRATION_TEST_PASSWORD`, the same pair
/// `ensureAuthenticated` logs in with — for a real user JWT via
/// `/auth/v1/token?grant_type=password`, then queries PostgREST as that user.
/// RLS is satisfied because the request genuinely *is* the test user.
///
/// No new secret is required, and deliberately so: no service-role key is
/// involved anywhere, so this cannot read another user's rows and cannot write
/// anything. It sees exactly what the signed-in athlete sees.
///
/// Flavor-aware through [TestConfig]: a `--flavor prod` run signs in with the
/// prod tester account and probes the prod project, the same way the flows do.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'test_config.dart';

/// A signed-in session against the project this run targets.
class SupabaseProbe {
  SupabaseProbe._(this._accessToken, this.userId);

  final String _accessToken;

  /// The authenticated athlete's id — the real implementation of what
  /// `DatabaseVerification.getCurrentUserId()` stubs out with `null`.
  final String userId;

  static SupabaseProbe? _cached;

  /// Sign in once per test bundle and reuse the session.
  ///
  /// Returns null when credentials are absent or rejected, so callers can fall
  /// back to UI-only assertions rather than fail on a probe that is itself
  /// unavailable. Never throws: a broken probe must not turn a healthy flow
  /// red.
  static Future<SupabaseProbe?> signIn() async {
    if (_cached != null) return _cached;
    if (TestConfig.loginEmail.isEmpty || TestConfig.loginPassword.isEmpty) {
      return null;
    }
    try {
      final res = await http
          .post(
            Uri.parse(
              '${TestConfig.supabaseUrl}/auth/v1/token?grant_type=password',
            ),
            headers: {
              'apikey': TestConfig.supabaseAnonKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': TestConfig.loginEmail,
              'password': TestConfig.loginPassword,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final token = body['access_token'] as String?;
      final id = (body['user'] as Map<String, dynamic>?)?['id'] as String?;
      if (token == null || id == null) return null;
      return _cached = SupabaseProbe._(token, id);
    } on Exception {
      return null;
    }
  }

  Map<String, String> get _headers => {
    'apikey': TestConfig.supabaseAnonKey,
    // The USER's token, not the anon key — this is the whole point.
    'Authorization': 'Bearer $_accessToken',
  };

  /// Rows from [table] matching [query] (a raw PostgREST filter string).
  ///
  /// Returns an empty list on any transport failure, so a probe outage reads
  /// as "no rows" to the caller, which then reports its own assertion.
  Future<List<Map<String, dynamic>>> select(
    String table, {
    required String query,
  }) async {
    try {
      final res = await http
          .get(
            Uri.parse('${TestConfig.supabaseUrl}/rest/v1/$table?$query'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return const [];
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    } on Exception {
      return const [];
    }
  }

  /// The activity titled [title] for this athlete, or null.
  ///
  /// Flows stamp titles with epoch millis, so this identifies exactly the row
  /// the calling flow just created — something the Fuel Timeline cannot do for
  /// a brick, whose tile renders no name at all.
  Future<Map<String, dynamic>?> activityByTitle(String title) async {
    final rows = await select(
      'activities',
      query:
          'user_id=eq.$userId'
          '&title=eq.${Uri.encodeQueryComponent(title)}'
          '&select=*',
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// The meal log named [name] for this athlete, or null.
  Future<Map<String, dynamic>?> mealLogByName(String name) async {
    final rows = await select(
      'meal_logs',
      query:
          'user_id=eq.$userId'
          '&name=eq.${Uri.encodeQueryComponent(name)}'
          '&select=*',
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// True when [title] is absent or tombstoned — the shape a soft delete
  /// leaves behind, which a disappearing card alone does not prove.
  Future<bool> activityIsGone(String title) async {
    final row = await activityByTitle(title);
    return row == null || row['deleted_at'] != null;
  }

  /// The event named [name] for this athlete, or null.
  Future<Map<String, dynamic>?> eventByName(String name) async {
    final rows = await select(
      'events',
      query:
          'user_id=eq.$userId'
          '&event_name=eq.${Uri.encodeQueryComponent(name)}'
          '&select=*',
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Personal formulas for this athlete whose name is [name].
  ///
  /// Returns every match rather than the first: creating a formula must not
  /// duplicate the row, and only a count can show that it did.
  Future<List<Map<String, dynamic>>> formulasByName(String name) async {
    return select(
      'personal_formulas',
      query:
          'user_id=eq.$userId'
          '&name=eq.${Uri.encodeQueryComponent(name)}'
          '&select=*',
    );
  }
}

/// Parsed `brick_metadata`, or null when the column is absent/!JSON.
///
/// Stored as JSON, and [BrickMetadata.fromJson] accepts both snake_case and
/// camelCase, so read the raw keys defensively here.
Map<String, dynamic>? brickMetadataOf(Map<String, dynamic> activity) {
  final raw = activity['brick_metadata'];
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
  return null;
}

/// Segment count from a brick's metadata, or null when unreadable.
int? brickSegmentCount(Map<String, dynamic> activity) {
  final meta = brickMetadataOf(activity);
  final segments = meta?['segments'] ?? meta?['segment_order'];
  return segments is List ? segments.length : null;
}

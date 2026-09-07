/// Shared fakes for the meal-planning data + application tests.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_remote.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_transport.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/connectivity_checker.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Logger ──────────────────────────────────────────────────────────────────

class FakeLogger extends Fake implements AppLogger {
  final List<String> errors = [];
  final List<String> warnings = [];

  @override
  void debug(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {}

  @override
  void info(String message, {String? context, Map<String, dynamic>? data}) {}

  @override
  void warning(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) => warnings.add(message);

  @override
  void error(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) => errors.add(message);
}

// ── Connectivity ────────────────────────────────────────────────────────────

class StubConnectivity extends ConnectivityChecker {
  StubConnectivity({this.online = true});

  bool online;

  @override
  Future<bool> isOnline() async => online;
}

// ── Supabase auth surface for VanaTransport ─────────────────────────────────

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

class MockAppConfig extends Mock implements AppConfig {}

/// A Supabase client whose auth surface answers `currentSession` /
/// `currentUser` (or neither when [signedIn] is false).
SupabaseClient supabaseWithSession({bool signedIn = true}) {
  final client = MockSupabaseClient();
  final auth = MockGoTrueClient();
  when(() => client.auth).thenReturn(auth);
  if (signedIn) {
    final session = MockSession();
    final user = MockUser();
    when(() => session.accessToken).thenReturn('test-token');
    when(() => user.id).thenReturn('user-1');
    when(() => auth.currentSession).thenReturn(session);
    when(() => auth.currentUser).thenReturn(user);
  } else {
    when(() => auth.currentSession).thenReturn(null);
    when(() => auth.currentUser).thenReturn(null);
  }
  return client;
}

AppConfig testConfig() {
  final config = MockAppConfig();
  when(() => config.supabaseUrl).thenReturn('https://example.supabase.co');
  when(() => config.supabaseAnonKey).thenReturn('anon');
  return config;
}

/// One recorded request the fake HTTP client saw.
class RecordedRequest {
  RecordedRequest(this.request, this.body);

  final http.BaseRequest request;
  final Map<String, dynamic> body;

  String get path => request.url.path;
}

/// Builds a [VanaTransport] backed by an `http` MockClient that answers with
/// [status] / [body] / [headers]. Requests are recorded on [requests].
class TransportHarness {
  TransportHarness({
    required this.status,
    required this.body,
    this.headers = const {},
    bool signedIn = true,
    this.throwOnSend,
  }) : logger = FakeLogger(),
       supabase = supabaseWithSession(signedIn: signedIn);

  final int status;
  final String body;
  final Map<String, String> headers;
  final Object? throwOnSend;
  final FakeLogger logger;
  final SupabaseClient supabase;
  final List<RecordedRequest> requests = [];

  late final VanaTransport transport = VanaTransport(
    supabase: supabase,
    config: testConfig(),
    logger: logger,
    clientFactory: () => MockClient.streaming((request, bodyStream) async {
      final raw = await bodyStream.bytesToString();
      requests.add(
        RecordedRequest(
          request,
          raw.isEmpty ? const {} : jsonDecode(raw) as Map<String, dynamic>,
        ),
      );
      if (throwOnSend != null) throw throwOnSend!;
      return http.StreamedResponse(
        Stream.fromIterable(_chunks(utf8.encode(body))),
        status,
        headers: headers,
      );
    }),
  );

  /// Deliver the body in uneven chunks so line splitting across chunk
  /// boundaries is exercised.
  static Iterable<List<int>> _chunks(List<int> bytes) sync* {
    const size = 37;
    for (var i = 0; i < bytes.length; i += size) {
      yield bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size);
    }
  }
}

/// NDJSON body from a contract fixture's `lines` array.
String ndjsonFromFixture(Map<String, dynamic> fixture) =>
    (fixture['lines'] as List).map(jsonEncode).join('\n') + '\n';

// ── Remote gateways ─────────────────────────────────────────────────────────

/// Records every replay call the repository makes.
class RecordingMealPlanRemote implements MealPlanRemote {
  List<Map<String, dynamic>> plans = [];
  List<Map<String, dynamic>> meals = [];
  final List<String> calls = [];
  final List<(String, Map<String, dynamic>)> updates = [];
  Object? failWith;

  void _maybeFail() {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlans(String userId) async {
    calls.add('fetchPlans:$userId');
    _maybeFail();
    return plans;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlanMeals(
    String userId,
    List<String> planIds,
  ) async {
    calls.add('fetchPlanMeals:${planIds.join(',')}');
    _maybeFail();
    return meals.where((m) => planIds.contains(m['plan_id'])).toList();
  }

  @override
  Future<void> removeMeal(String planMealId) async {
    calls.add('plan_remove_meal:$planMealId');
    _maybeFail();
  }

  @override
  Future<void> setServings(String planMealId, int servings) async {
    calls.add('plan_set_servings:$planMealId:$servings');
    _maybeFail();
  }

  @override
  Future<void> updatePlanMeal(
    String planMealId,
    Map<String, dynamic> fields,
  ) async {
    calls.add('update_plan_meal:$planMealId');
    updates.add((planMealId, fields));
    _maybeFail();
  }

  @override
  Future<void> updatePlan(String planId, Map<String, dynamic> fields) async {
    calls.add('update_plan:$planId');
    updates.add((planId, fields));
    _maybeFail();
  }
}

class RecordingUserMemoryRemote implements UserMemoryRemote {
  List<Map<String, dynamic>> memories = [];
  final List<List<Map<String, dynamic>>> upserts = [];
  final Map<String, String> settingIds = {};
  Object? failWith;

  @override
  Future<List<Map<String, dynamic>>> fetchMemories(String userId) async {
    if (failWith != null) throw failWith!;
    return memories;
  }

  @override
  Future<void> upsertMemories(List<Map<String, dynamic>> rows) async {
    if (failWith != null) throw failWith!;
    upserts.add(rows);
  }

  @override
  Future<String?> findSettingId(String userId, String key) async =>
      settingIds[key];
}

// MealAiService refreshes the credit balance after the server may have moved
// it (round develop-2026-10, ticket 23: 02-001, 02-012).
//
// The real Functions client runs; the seam is HTTP, answered with the bodies
// `describe-meal` produces: a 200 analysis with `_usage`, and the 402 from
// `insufficientCreditsBody` (supabase/functions/_shared/ai/credits.ts).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_report.dart';

class _MockUser extends Mock implements User {}

const _userId = '4a74be96-fce8-4894-a82c-2a77199d601d';

/// describe-meal's 200 body: the analysis spread, plus `_usage`.
const _describe200 = {
  'name': 'Oatmeal with banana',
  'suggested_slot': 'breakfast',
  'confidence': 'high',
  'items': [
    {
      'name': 'Rolled oats',
      'portion': '1 cup cooked',
      'calories': 166,
      'carb_g': 28.1,
      'protein_g': 5.9,
      'fat_g': 3.6,
      'sodium_mg': 9.4,
    },
    {
      'name': 'Banana',
      'portion': '1 medium',
      'calories': 105,
      'carb_g': 27,
      'protein_g': 1.3,
      'fat_g': 0.4,
      'sodium_mg': 1.2,
    },
  ],
  'totals': {
    'calories': 271,
    'carb_g': 55.1,
    'protein_g': 7.2,
    'fat_g': 4,
    'sodium_mg': 10.6,
  },
  'notes': null,
  '_usage': {
    'input_tokens': 812,
    'output_tokens': 233,
    'model': 'anthropic/claude-sonnet-4.6',
    'cost_usd': 0.005931,
  },
};

/// insufficientCreditsBody({allowed:false, balance:0, cost:1}).
const _producer402 = {
  'error': 'insufficient_credits',
  'message': 'You are out of AI credits. Purchase more to continue.',
  'balance': 0,
  'cost': 1,
};

void main() {
  late int status;
  late Object body;
  late int refreshes;
  late MealAiService service;

  setUp(() {
    refreshes = 0;
    final real = SupabaseClient(
      'http://fake-supabase.local',
      'anon-key',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(real.dispose);
    final goTrue = fakeGoTrueClient();
    final user = _MockUser();
    when(() => user.id).thenReturn(_userId);
    when(() => goTrue.currentUser).thenReturn(user);
    final client = fakeSupabaseClient(auth: goTrue) as MockSupabaseClient;
    when(() => client.functions).thenReturn(real.functions);
    service = MealAiService(
      supabase: client,
      report: RecordingReport(),
      onCreditsChanged: () async => refreshes++,
    );
  });

  test('a 200 describe answer refreshes credits once', () async {
    status = 200;
    body = _describe200;

    final result = await service.describeMeal('oatmeal and a banana');
    await Future<void>.delayed(Duration.zero);

    expect(result.name, 'Oatmeal with banana');
    expect(refreshes, 1);
  });

  test(
    'a 402 throws InsufficientCreditsException(0, 1) and refreshes once',
    () async {
      status = 402;
      body = _producer402;

      await expectLater(
        service.describeMeal('oatmeal'),
        throwsA(
          isA<InsufficientCreditsException>()
              .having((e) => e.balance, 'balance', 0)
              .having((e) => e.cost, 'cost', 1),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(refreshes, 1);
    },
  );

  test('a 500 refreshes nothing', () async {
    status = 500;
    body = {'success': false, 'error': 'Internal server error'};

    await expectLater(
      service.describeMeal('oatmeal'),
      throwsA(isA<MealAiException>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 0);
  });

  test(
    'a refresh that throws is reported and never reaches the caller',
    () async {
      final report = RecordingReport();
      final goTrue = fakeGoTrueClient();
      final client = fakeSupabaseClient(auth: goTrue) as MockSupabaseClient;
      final real = SupabaseClient(
        'http://fake-supabase.local',
        'anon-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(_describe200),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(real.dispose);
      final user = _MockUser();
      when(() => user.id).thenReturn(_userId);
      when(() => goTrue.currentUser).thenReturn(user);
      when(() => client.functions).thenReturn(real.functions);
      final failing = MealAiService(
        supabase: client,
        report: report,
        onCreditsChanged: () async => throw StateError('refresh failed'),
      );

      final result = await failing.describeMeal('oatmeal');
      await Future<void>.delayed(Duration.zero);

      expect(result.items, hasLength(2));
      expect(report.degradeds, hasLength(1));
    },
  );
}

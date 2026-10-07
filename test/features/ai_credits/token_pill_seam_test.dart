// Seam test for the token pill (round develop-2026-10, ticket 23: 02-001).
//
// Everything on our side runs for real: TokenPill, CreditsController,
// CreditsRepository, the real Functions and PostgREST clients. The seam is the
// HTTP boundary, faked by a server that answers exactly as the producers do:
// `ensure-credits` with its body ({balance, free_monthly, enforced}) and
// PostgREST with a `token_wallets` row in the shape dev serves it (the
// mealplanning columns `unit` / `allowance*` present, `updated_at` with
// microseconds and `+00:00`).
//
// Only the realtime subscription is stubbed: a websocket has no fake here,
// and the refresh under test is the path that must hold without it (prod's
// `token_wallets` is not in the realtime publication).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/data/credits_repository.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/features/ai_credits/presentation/widgets/token_pill.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_report.dart';

class _MockUser extends Mock implements User {}

const _userId = '4a74be96-fce8-4894-a82c-2a77199d601d';

/// Fake Supabase edge + PostgREST for the caller's wallet.
class _FakeServer {
  int balance = 50;

  Map<String, dynamic> walletRow() => {
    'user_id': _userId,
    'balance': balance,
    'free_period': '2026-10',
    'unit': 'credit',
    'allowance': 0,
    'allowance_monthly': 0,
    'allowance_expires_at': null,
    'created_at': '2026-10-07T08:02:11.093561+00:00',
    'updated_at': '2026-10-07T09:14:22.512834+00:00',
  };

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/functions/v1/ensure-credits')) {
      return _json({'balance': balance, 'free_monthly': 50, 'enforced': true});
    }
    if (request.method == 'GET' && path.endsWith('/rest/v1/token_wallets')) {
      // maybeSingle() asks for an object; PostgREST answers the row itself.
      return _json(walletRow());
    }
    return _json({'message': 'unexpected ${request.method} $path'}, 404);
  }

  static http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// The real repository with the realtime channel switched off.
class _NoRealtimeCreditsRepository extends CreditsRepository {
  _NoRealtimeCreditsRepository({required super.supabase, super.report});

  @override
  RealtimeChannel? subscribeToWallet(void Function(CreditWallet) onChange) =>
      null;
}

void main() {
  late _FakeServer server;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    server = _FakeServer();
  });

  CreditsRepository repository() {
    final real = SupabaseClient(
      'http://fake-supabase.local',
      'anon-key',
      httpClient: MockClient((request) async {
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
    final user = _MockUser();
    when(() => user.id).thenReturn(_userId);
    when(() => user.isAnonymous).thenReturn(false);
    when(() => goTrue.currentUser).thenReturn(user);
    final client = fakeSupabaseClient(auth: goTrue) as MockSupabaseClient;
    when(
      () => client.from(any()),
    ).thenAnswer((i) => real.from(i.positionalArguments.first as String));
    when(() => client.functions).thenReturn(real.functions);
    return _NoRealtimeCreditsRepository(
      supabase: client,
      report: RecordingReport(),
    );
  }

  late ProviderContainer container;

  // Built in setUp, outside testWidgets' fake-async zone: the real Supabase
  // client and the controller's first load run on real async.
  setUp(() async {
    container = ProviderContainer(
      overrides: [
        creditsRepositoryProvider.overrideWithValue(repository()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        reportProvider.overrideWithValue(RecordingReport()),
        appConfigProvider.overrideWithValue(
          AppConfig.forTesting(aiCreditsEnabled: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(creditsControllerProvider.future);
  });

  Future<ProviderContainer> pumpPill(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: TokenPill())),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> refresh(WidgetTester tester, ProviderContainer c) async {
    await tester.runAsync(
      () => c.read(creditsControllerProvider.notifier).refresh(),
    );
    await tester.pump();
  }

  testWidgets('a new account shows the 50-token grant', (tester) async {
    await pumpPill(tester);
    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('after a spend, refresh moves the pill to 49', (tester) async {
    final c = await pumpPill(tester);
    server.balance = 49;
    await refresh(tester, c);
    expect(find.text('49'), findsOneWidget);
  });

  testWidgets('a wallet in the wrong unit shows its real number, not 99999', (
    tester,
  ) async {
    final c = await pumpPill(tester);
    server.balance = 49897485;
    await refresh(tester, c);
    expect(find.text('49897485'), findsOneWidget);
    expect(find.text('99999'), findsNothing);
  });
}

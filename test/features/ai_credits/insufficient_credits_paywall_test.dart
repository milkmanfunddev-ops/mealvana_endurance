// The Out of AI credits dialog takes its words from the content system, not
// from the server's English 402 `message`, and "Get credits" opens
// /buy-credits (round develop-2026-10, ticket 23: 02-001).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';
import 'package:mealvana_endurance/features/ai_credits/presentation/insufficient_credits_paywall.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/shared/core/bootstrap/bootstrap.dart'
    show appNavigatorKey;

import '../../helpers/test_content.dart';

/// The producer's 402 body, as the client parses it.
final _serverError = InsufficientCreditsException.fromMap(const {
  'error': 'insufficient_credits',
  'message': 'You are out of AI credits. Purchase more to continue.',
  'balance': 0,
  'cost': 1,
});

void main() {
  final defaults = loadDefaultContent();

  Future<void> pumpApp(WidgetTester tester, Map<String, String> content) async {
    final router = GoRouter(
      navigatorKey: appNavigatorKey,
      initialLocation: '/log',
      routes: [
        GoRoute(
          path: '/log',
          builder: (_, __) => const Scaffold(body: Text('log meal')),
        ),
        GoRoute(
          path: '/buy-credits',
          builder: (_, __) => const Scaffold(body: Text('buy credits screen')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(
            (ref) => TestContentService(ref, content),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the defaults keep today\'s words', (tester) async {
    expect(defaults[ContentKeys.aiCreditsOutTitle], 'Out of AI credits');
    expect(
      defaults[ContentKeys.aiCreditsOutBody],
      "You've used all your AI credits. Get more to keep using AI features.",
    );
    expect(defaults[ContentKeys.aiCreditsOutNotNow], 'Not now');
    expect(defaults[ContentKeys.aiCreditsOutGetCredits], 'Get credits');
  });

  testWidgets('the dialog shows the content strings, not the server message', (
    tester,
  ) async {
    await pumpApp(tester, {
      ContentKeys.aiCreditsOutTitle: 'T: out',
      ContentKeys.aiCreditsOutBody: 'B: body from content',
      ContentKeys.aiCreditsOutNotNow: 'N: later',
      ContentKeys.aiCreditsOutGetCredits: 'G: buy',
    });

    expect(maybeShowInsufficientCreditsPaywall(_serverError), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('T: out'), findsOneWidget);
    expect(find.text('B: body from content'), findsOneWidget);
    expect(find.text('N: later'), findsOneWidget);
    expect(find.text('G: buy'), findsOneWidget);
    expect(find.text(_serverError.message), findsNothing);
  });

  testWidgets('Get credits pushes /buy-credits', (tester) async {
    await pumpApp(tester, defaults);

    maybeShowInsufficientCreditsPaywall(_serverError);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get credits'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('buy credits screen'), findsOneWidget);
  });

  testWidgets('Not now closes the dialog and stays put', (tester) async {
    await pumpApp(tester, defaults);

    maybeShowInsufficientCreditsPaywall(_serverError);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('log meal'), findsOneWidget);
  });

  test('any other error is not the paywall', () {
    expect(maybeShowInsufficientCreditsPaywall(StateError('x')), isFalse);
  });
}

/// The Vana launcher and sheet over a real GoRouter (vana-sheet spec,
/// Conformance L2): VS-6 over the router, VS-1 summon over the current route,
/// VS-2 dismiss back to the same route and scroll position, VS-3 the chat
/// route with the same conversation, VS-5 through the real notifiers, VS-9
/// the condense, and the Situation of the screen underneath riding each
/// message.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_ambient_conversation_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_chat_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_companion.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_situation_scope.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/vana_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/container.dart';
import '../helpers/test_content.dart';

const _launcher = ValueKey('vana_sheet.launcher');

class _FakeChatRepo extends Fake implements VanaChatRepository {
  final List<Map<String, Object?>> calls = [];
  final List<String> fetched = [];
  List<VanaMessage> history = const [];
  Object? throwOnStream;

  /// When set, a turn's events wait for this before completing — a turn in
  /// flight.
  Completer<void>? hold;

  /// When set, a turn waits for this before its first event — the server
  /// has not yet named the conversation.
  Completer<void>? holdFirst;

  @override
  Future<VanaChatResponse> streamChat({
    String? message,
    String? conversationId,
    required VanaConversationKind kind,
    bool opener = false,
    String? anchorDate,
    String? timezone,
    VanaSituation? situation,
  }) async {
    calls.add({
      'message': message,
      'conversationId': conversationId,
      'kind': kind,
      'opener': opener,
      'situation': situation?.toJson(),
    });
    if (throwOnStream != null) throw throwOnStream!;
    final hold = this.hold;
    final holdFirst = this.holdFirst;
    Stream<VanaStreamEvent> events() async* {
      if (holdFirst != null) await holdFirst.future;
      yield VanaTextEvent(opener ? 'Morning. What is on your mind?' : 'Sure.');
      if (hold != null) await hold.future;
      yield const VanaDoneEvent();
    }

    return VanaChatResponse(
      conversationId: conversationId ?? 'conv-server',
      kind: kind,
      events: events(),
    );
  }

  @override
  Future<List<VanaMessage>> fetchMessages(String conversationId) async {
    fetched.add(conversationId);
    return history;
  }
}

class _FakeActionClient extends Fake implements VanaActionClient {
  @override
  Future<VanaActionResult> run(UiAction action) async =>
      const VanaActionResult(parts: [], extras: {});
}

/// Every path the tests visit. `/fuel-log` is a scoped, scrollable screen;
/// the rest are plain pages labelled with their path.
const _paths = [
  '/main',
  '/settings',
  '/events',
  '/pro',
  '/buy-credits',
  '/welcome',
  '/onboarding',
  '/auth/email-login',
  '/privacy-consent',
  '/force-upgrade',
  '/vana',
  '/vana/conversations',
  '/settings/vana',
];

class _Harness {
  _Harness(this.router, this.repo, this.container);
  final GoRouter router;
  final _FakeChatRepo repo;
  final ProviderContainer container;

  /// The top route's location — a pushed route carries its own match list.
  String get location {
    final config = router.routerDelegate.currentConfiguration;
    final last = config.last;
    return (last is ImperativeRouteMatch ? last.matches : config).uri
        .toString();
  }
}

class _FuelLogPage extends StatelessWidget {
  const _FuelLogPage();

  @override
  Widget build(BuildContext context) => VanaSituationScope(
    situation: VanaSituation.screen(
      VanaScreen.fuelLog,
      entityId: 'act-1',
      date: DateTime(2026, 9, 12),
    ),
    child: Scaffold(
      body: ListView.builder(
        key: const ValueKey('fuel_log.list'),
        itemCount: 60,
        itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
      ),
    ),
  );
}

Future<_Harness> _pump(
  WidgetTester tester, {
  String initial = '/main',
  bool pro = true,
  _FakeChatRepo? repo,
  DateTime Function()? clock,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final chat = repo ?? _FakeChatRepo();
  final observer = VanaCompanionObserver();
  final router = GoRouter(
    initialLocation: initial,
    observers: [observer],
    routes: [
      GoRoute(path: '/fuel-log', builder: (_, _) => const _FuelLogPage()),
      for (final path in _paths)
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Center(child: Text('page $path'))),
        ),
    ],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [
      ...baseOverrides(),
      sharedPreferencesProvider.overrideWithValue(prefs),
      contentServiceProvider.overrideWith(testContentService),
      proUnlockedProvider.overrideWithValue(pro),
      vanaChatRepositoryProvider.overrideWithValue(chat),
      vanaActionClientProvider.overrideWithValue(_FakeActionClient()),
      vanaClockProvider.overrideWithValue(
        clock ?? () => DateTime(2026, 9, 10, 9),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            VanaCompanionHost(router: router, observer: observer, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(router, chat, container);
}

/// Let a streamed turn land (the typing indicator animates forever while a
/// turn is in flight, so never pumpAndSettle with one open).
Future<void> _settleTurn(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_launcher));
  await tester.pump();
  await tester.pump(VanaSheet.riseDuration);
  await _settleTurn(tester);
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('vana_sheet.close')));
  await _condensed(tester);
}

/// Run a dismissal to its end. The scrim and system back pop through
/// `maybePop`, which is async, so the condense can start a frame late.
Future<void> _condensed(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(
    VanaSheet.condenseDuration + const Duration(milliseconds: 50),
  );
  await tester.pump();
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('vana_sheet.composer')), text);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('vana_sheet.send')));
  await tester.pump();
  await _settleTurn(tester);
}

void main() {

  group('VS-6: where the launcher renders', () {
    testWidgets('absent on every excluded route, present elsewhere', (
      tester,
    ) async {
      final h = await _pump(tester);
      const excluded = {
        '/pro',
        '/buy-credits',
        '/welcome',
        '/onboarding',
        '/auth/email-login',
        '/privacy-consent',
        '/force-upgrade',
        '/vana',
        '/vana/conversations',
        '/settings/vana',
      };
      for (final path in [..._paths, '/fuel-log']) {
        h.router.go(path);
        await tester.pumpAndSettle();
        expect(
          find.byKey(_launcher),
          excluded.contains(path) ? findsNothing : findsOneWidget,
          reason: path,
        );
      }
    });

    testWidgets('a pushed route counts, not the one under it', (tester) async {
      final h = await _pump(tester);
      expect(find.byKey(_launcher), findsOneWidget);
      unawaited(h.router.push('/vana/conversations'));
      await tester.pumpAndSettle();
      expect(find.byKey(_launcher), findsNothing);
      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_launcher), findsOneWidget);
    });

    testWidgets('a dialog over the page takes the launcher with it', (
      tester,
    ) async {
      final h = await _pump(tester);
      final navigator = h.router.routerDelegate.navigatorKey.currentState!;
      unawaited(
        showDialog<void>(
          context: navigator.context,
          builder: (_) => const AlertDialog(content: Text('dialog')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_launcher), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_launcher), findsOneWidget);
    });

    testWidgets('a double tap opens one sheet', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(_launcher));
      await tester.tap(find.byKey(_launcher), warnIfMissed: false);
      await tester.pump();
      await tester.pump(VanaSheet.riseDuration);
      await _settleTurn(tester);
      expect(find.byType(VanaSheet), findsOneWidget);
    });

    testWidgets('without Pro the launcher leads to the paywall, as the chat '
        'route does', (tester) async {
      final h = await _pump(tester, pro: false);
      await tester.tap(find.byKey(_launcher));
      await tester.pumpAndSettle();
      expect(h.location, '/pro');
      expect(find.byType(VanaSheet), findsNothing);
    });
  });

  group('VS-1 / VS-2: summon and dismiss over the current screen', () {
    testWidgets('the sheet rises over the screen without leaving it', (
      tester,
    ) async {
      final h = await _pump(tester, initial: '/fuel-log');
      await tester.drag(
        find.byKey(const ValueKey('fuel_log.list')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final scrolled = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;

      await _open(tester);
      expect(find.byType(VanaSheet), findsOneWidget);
      expect(h.location, '/fuel-log');
      // The page stays mounted and visible above the sheet.
      expect(find.text('row 5', skipOffstage: false), findsOneWidget);
      // The launcher is the sheet now; it is not drawn over the composer.
      expect(find.byKey(_launcher), findsNothing);

      final sheetTop = tester.getTopLeft(find.byType(VanaSheet)).dy;
      expect(sheetTop, closeTo(844 * (1 - VanaSheet.restHeightFraction), 1));

      // Scrim tap: back to exactly where they were.
      await tester.tapAt(const Offset(195, 40));
      await _condensed(tester);
      expect(find.byType(VanaSheet), findsNothing);
      expect(h.location, '/fuel-log');
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        scrolled,
      );
      expect(find.byKey(_launcher), findsOneWidget);
    });

    testWidgets('system back closes the sheet, not the screen', (tester) async {
      final h = await _pump(tester, initial: '/main');
      unawaited(h.router.push('/fuel-log'));
      await tester.pumpAndSettle();
      await _open(tester);

      await tester.binding.handlePopRoute();
      await _condensed(tester);
      expect(find.byType(VanaSheet), findsNothing);
      expect(h.location, '/fuel-log');
    });
  });

  group('VS-9: every dismissal condenses into the launcher', () {
    testWidgets('mid-dismiss the sheet is shrinking toward the launcher, '
        'not sliding down', (tester) async {
      await _pump(tester);
      await _open(tester);
      final open = tester.getRect(find.byType(VanaSheet));

      await tester.tap(find.byKey(const ValueKey('vana_sheet.close')));
      await tester.pump();
      await tester.pump(
        Duration(milliseconds: VanaSheet.condenseDuration.inMilliseconds ~/ 2),
      );
      final mid = tester.getRect(find.byType(VanaSheet));
      final launcher = VanaLauncher.centerOn(const Size(390, 844));

      // A slide keeps its width; a condense does not.
      expect(mid.width, lessThan(open.width * 0.8));
      expect(mid.height, lessThan(open.height * 0.8));
      // It stays on screen and closes on the launcher's corner.
      expect(mid.bottom, lessThanOrEqualTo(844));
      expect(
        (mid.center - launcher).distance,
        lessThan((open.center - launcher).distance),
      );

      await tester.pump(VanaSheet.condenseDuration);
      await tester.pump();
      expect(find.byType(VanaSheet), findsNothing);
      expect(find.byKey(_launcher), findsOneWidget);
    });
  });

  group('the conversation', () {
    testWidgets('an empty conversation opens to the opener', (tester) async {
      final h = await _pump(tester);
      await _open(tester);
      expect(h.repo.calls, hasLength(1));
      expect(h.repo.calls.single['opener'], isTrue);
      expect(h.repo.calls.single['kind'], VanaConversationKind.general);
      expect(find.text('Morning. What is on your mind?'), findsOneWidget);
    });

    testWidgets('each message carries the Situation of the screen underneath', (
      tester,
    ) async {
      final h = await _pump(tester, initial: '/main');
      unawaited(h.router.push('/fuel-log'));
      await tester.pumpAndSettle();
      await _open(tester);
      await _send(tester, 'what should I eat before this');

      final sent = h.repo.calls.last;
      expect(sent['message'], 'what should I eat before this');
      expect(sent['situation'], {
        'route': '/fuel-log',
        'entityId': 'act-1',
        'date': '2026-09-12',
      });

      // Settings has no scope: it speaks as its route, not as the fuel log.
      await _close(tester);
      h.router.go('/settings');
      await tester.pumpAndSettle();
      await _open(tester);
      await _send(tester, 'and now?');
      expect(h.repo.calls.last['situation'], {'route': '/settings'});
    });

    testWidgets('VS-5: later the same day the sheet continues the same '
        'conversation; the next day starts a new one', (tester) async {
      var now = DateTime(2026, 9, 10, 9);
      final h = await _pump(tester, clock: () => now);
      await _open(tester);
      // The opener named the conversation; the sheet holds it for today.
      await _close(tester);
      expect(
        await h.container.read(vanaAmbientConversationProvider.future),
        'conv-server',
      );

      now = DateTime(2026, 9, 10, 18);
      h.repo.history = [
        VanaMessage(
          id: 'm1',
          conversationId: 'conv-server',
          role: VanaMessageRole.assistant,
          content: 'Morning. What is on your mind?',
          createdAt: DateTime(2026, 9, 10, 9),
        ),
      ];
      await _open(tester);
      expect(h.repo.fetched, ['conv-server']);
      // It opens to what the conversation holds, so no second opener.
      expect(h.repo.calls.where((c) => c['opener'] == true), hasLength(1));
      await _send(tester, 'still me');
      expect(h.repo.calls.last['conversationId'], 'conv-server');

      await _close(tester);
      now = DateTime(2026, 9, 11, 7);
      await _open(tester);
      final opener = h.repo.calls.last;
      expect(opener['opener'], isTrue);
      expect(opener['conversationId'], isNull);
    });

    testWidgets('VS-3: full screen opens the chat route with the same '
        'conversation', (tester) async {
      final h = await _pump(tester);
      await _open(tester);
      await _close(tester);
      // Reopened: the sheet is holding today's conversation.
      await _open(tester);

      await tester.tap(find.byKey(const ValueKey('vana_sheet.full_screen')));
      await tester.pump();
      await tester.pump(VanaSheet.condenseDuration);
      await tester.pumpAndSettle();
      expect(h.location, '/vana?mode=general&c=conv-server');
      expect(find.byType(VanaSheet), findsNothing);
      expect(find.byKey(_launcher), findsNothing);
    });

    testWidgets('VS-3 before the server has named it: the chat route shares '
        'the sheet\'s own conversation', (tester) async {
      final h = await _pump(tester);
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('vana_sheet.full_screen')));
      await tester.pump();
      // The sheet's conversation is the unnamed-general one; the chat route
      // opened without an id reads the same notifier, so it is the same
      // conversation, not a new one.
      expect(h.location, '/vana?mode=general');
      final shared = h.container.read(
        vanaChatControllerProvider(kind: VanaConversationKind.general),
      );
      expect(shared.value!.conversationId, 'conv-server');
      await tester.pumpAndSettle();
      expect(
        await h.container.read(vanaAmbientConversationProvider.future),
        'conv-server',
      );
    });

    testWidgets('VS-5 holds when the sheet closes before the server has named '
        'the conversation', (tester) async {
      final repo = _FakeChatRepo()..holdFirst = Completer<void>();
      final h = await _pump(tester, repo: repo);
      await _open(tester);
      await _close(tester);
      // The opener is still in flight; the sheet is gone.
      repo.holdFirst!.complete();
      await _settleTurn(tester);
      expect(
        await h.container.read(vanaAmbientConversationProvider.future),
        'conv-server',
      );

      // So the next sheet that day continues it rather than starting over.
      repo.history = [
        VanaMessage(
          id: 'm1',
          conversationId: 'conv-server',
          role: VanaMessageRole.assistant,
          content: 'Morning. What is on your mind?',
          createdAt: DateTime(2026, 9, 10, 9),
        ),
      ];
      await _open(tester);
      expect(repo.fetched, ['conv-server']);
      expect(repo.calls.where((c) => c['opener'] == true), hasLength(1));
    });


    testWidgets('ERROR: one plain line and a retry, never a snackbar', (
      tester,
    ) async {
      final repo = _FakeChatRepo()..throwOnStream = const VanaOfflineException('offline');
      await _pump(tester, repo: repo);
      await _open(tester);
      final offline = loadDefaultContent()['meal_planning.vana_offline']!;
      expect(find.text(offline), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      repo.throwOnStream = null;
      await tester.tap(find.byKey(const ValueKey('vana_sheet.retry')));
      await tester.pump();
      await _settleTurn(tester);
      expect(find.text(offline), findsNothing);
      expect(find.text('Morning. What is on your mind?'), findsOneWidget);
      expect(repo.calls.where((c) => c['opener'] == true), hasLength(2));
    });

    testWidgets('STREAMING: the sheet does not resize while a turn is in '
        'flight', (tester) async {
      final repo = _FakeChatRepo();
      final h = await _pump(tester, repo: repo);
      await _open(tester);
      final before = tester.getRect(find.byType(VanaSheet));

      repo.hold = Completer<void>();
      await tester.enterText(
        find.byKey(const ValueKey('vana_sheet.composer')),
        'hello',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('vana_sheet.send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final state = h.container
          .read(
            vanaChatControllerProvider(kind: VanaConversationKind.general),
          )
          .value!;
      expect(state.isStreaming, isTrue);
      expect(tester.getRect(find.byType(VanaSheet)), before);

      repo.hold!.complete();
      await _settleTurn(tester);
    });
  });
}

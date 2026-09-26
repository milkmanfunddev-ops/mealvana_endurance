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
import 'package:mealvana_endurance/features/meal_planning/domain/vana_input_mode.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/choice_chips.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_picker_carousel.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_companion.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_situation_scope.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/icons/vana_avatar.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/materials/glass.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/vana_sheet.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/container.dart';
import '../../helpers/vana_moment_inputs.dart';
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

  /// Parts the opener's turn carries after its prose (its offers).
  List<VanaPart> openerParts = const [];

  /// Parts an athlete's turn is answered with after the prose.
  List<VanaPart> replyParts = const [];

  /// Parts a turn carries before any prose, then the turn waits on this
  /// before its text: a tool result landed, the prose has not.
  (List<VanaPart>, Completer<void>)? leadParts;

  @override
  Future<VanaChatResponse> streamChat({
    String? message,
    String? conversationId,
    required VanaConversationKind kind,
    bool opener = false,
    String? anchorDate,
    String? timezone,
    VanaSituation? situation,
    VanaMoment? moment,
    bool newPlan = false,
    VanaInputMode? inputMode,
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
      if (leadParts case (final parts, final gate)?) {
        for (final part in parts) {
          yield VanaUiEvent(part);
        }
        await gate.future;
      }
      yield VanaTextEvent(opener ? 'Morning. What is on your mind?' : 'Sure.');
      for (final part in opener ? openerParts : replyParts) {
        yield VanaUiEvent(part);
      }
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

final _picker = VanaMealPickerPart(
  title: 'Dinners that fit',
  meals: [
    MealRef.fromJson(const {
      'source': 'library',
      'id': 'D-001',
      'name': 'Salmon rice bowl',
      'mealType': 'dinner',
    }),
  ],
);

class _FakeActionClient extends Fake implements VanaActionClient {
  @override
  Future<VanaActionResult> run(UiAction action) async =>
      const VanaActionResult(parts: [], extras: {});
}

/// Coach formulas: the third of the three screens (mp-264), with no
/// Situation scope of its own.
const _formulas = '/settings/food-preferences/formula-library';

/// Every plain page the tests visit, labelled with its path: two of the
/// three launcher screens, and a sample of everything else (the old
/// deny-list's routes among them). `/food`, the third, is [_PlanTabPage].
const _paths = [
  '/main',
  _formulas,
  '/settings',
  '/events',
  '/paywall',
  '/buy-credits',
  '/welcome',
  '/onboarding',
  '/auth/email-login',
  '/privacy-consent',
  '/force-upgrade',
  '/vana',
  '/vana/conversations',
  '/settings/vana',
  '/distancepacegut',
  '/events/create',
  '/meal-log/review',
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

/// The meal-planning screen: scoped and scrollable.
class _PlanTabPage extends StatelessWidget {
  const _PlanTabPage();

  @override
  Widget build(BuildContext context) => VanaSituationScope(
    situation: VanaSituation.screen(
      VanaScreen.planTab,
      entityId: 'act-1',
      date: DateTime(2026, 9, 12),
    ),
    child: Scaffold(
      body: ListView.builder(
        key: const ValueKey('plan_tab.list'),
        itemCount: 60,
        itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
      ),
    ),
  );
}

Future<_Harness> _pump(
  WidgetTester tester, {
  String initial = '/main',
  _FakeChatRepo? repo,
  DateTime Function()? clock,
  bool canWrite = true,
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
      GoRoute(path: '/food', builder: (_, _) => const _PlanTabPage()),
      GoRoute(
        path: '/paywall',
        builder: (_, _) => const Scaffold(body: Center(child: Text('paywall'))),
      ),
      GoRoute(
        path: '/food/cook/:id',
        builder: (_, _) => const Scaffold(body: Center(child: Text('cook'))),
      ),
      for (final path in _paths)
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Center(child: Text('page $path'))),
        ),
      // After the plain pages, so `/events/create` stays itself.
      GoRoute(
        path: '/events/:eventId',
        builder: (_, state) => Scaffold(
          body: Center(child: Text('event ${state.pathParameters['eventId']}')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [
      ...baseOverrides(writeAccess: canWrite),
      ...vanaMomentInputs(),
      sharedPreferencesProvider.overrideWithValue(prefs),
      contentServiceProvider.overrideWith(testContentService),
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
        builder: (context, child) => VanaCompanionHost(
          router: router,
          observer: observer,
          child: child!,
        ),
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
  await tester.enterText(
    find.byKey(const ValueKey('vana_sheet.composer')),
    text,
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('vana_sheet.send')));
  await tester.pump();
  await _settleTurn(tester);
}

void main() {
  group('a lapsed account (mp-457)', () {
    testWidgets('the launcher opens the paywall instead of the sheet', (
      tester,
    ) async {
      final h = await _pump(tester, canWrite: false);
      expect(find.byKey(_launcher), findsOneWidget);

      await tester.tap(find.byKey(_launcher));
      await tester.pumpAndSettle();

      expect(find.text('paywall'), findsOneWidget);
      expect(find.byType(VanaCompanionSheet), findsNothing);
      expect(h.repo.calls, isEmpty);
    });
  });

  group('VS-6: where the launcher renders', () {
    testWidgets('present on the three screens, absent on every other route', (
      tester,
    ) async {
      final h = await _pump(tester);
      const shown = {'/main', '/food', _formulas};
      for (final path in [..._paths, '/food']) {
        h.router.go(path);
        await tester.pumpAndSettle();
        expect(
          find.byKey(_launcher),
          shown.contains(path) ? findsOneWidget : findsNothing,
          reason: path,
        );
      }
    });

    testWidgets('a route pushed over one of the three has no launcher; the '
        'screen it returns to has one', (tester) async {
      final h = await _pump(tester, initial: '/food');
      expect(find.byKey(_launcher), findsOneWidget);
      unawaited(h.router.push('/food/cook/D-048'));
      await tester.pumpAndSettle();
      expect(find.byKey(_launcher), findsNothing);
      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_launcher), findsOneWidget);
    });

    testWidgets('a page pushed without the router hides the launcher without '
        'naming itself', (tester) async {
      final h = await _pump(tester, initial: '/main');
      final navigator = h.router.routerDelegate.navigatorKey.currentState!;
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('event form')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_launcher), findsNothing);
      // A dialog over it, then gone: still the pushed page underneath.
      unawaited(
        showDialog<void>(
          context: navigator.context,
          builder: (_) => const AlertDialog(content: Text('dialog')),
        ),
      );
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_launcher), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_launcher), findsOneWidget);
    });

    testWidgets('a name on a pushed page changes nothing, even one of the '
        'three', (tester) async {
      final h = await _pump(tester, initial: '/main');
      final navigator = h.router.routerDelegate.navigatorKey.currentState!;
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/main'),
            builder: (_) => const Scaffold(body: Text('named page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_launcher), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_launcher), findsOneWidget);
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

    testWidgets('the launcher is its own accessibility node, the size of '
        'the launcher', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      final node = tester.getSemantics(find.byKey(_launcher));
      expect(node.label, 'Ask Vana');
      expect(node.rect.size, const Size.square(VanaLauncher.size));
      // The page underneath keeps its own nodes; it is not relabelled.
      expect(tester.getSemantics(find.text('page /main')).label, 'page /main');
      handle.dispose();
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
  });

  group('VS-1 / VS-2: summon and dismiss over the current screen', () {
    testWidgets('the sheet rises over the screen without leaving it', (
      tester,
    ) async {
      final h = await _pump(tester, initial: '/food');
      await tester.drag(
        find.byKey(const ValueKey('plan_tab.list')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final scrolled = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;

      await _open(tester);
      expect(find.byType(VanaSheet), findsOneWidget);
      expect(h.location, '/food');
      // The page stays mounted and visible above the sheet.
      expect(find.text('row 5', skipOffstage: false), findsOneWidget);
      // The launcher is the sheet now; it is not drawn over the composer.
      expect(find.byKey(_launcher), findsNothing);

      final sheetTop = tester.getTopLeft(find.byType(VanaSheet)).dy;
      expect(sheetTop, closeTo(844 * (1 - VanaSheet.heightFraction), 1));

      // Scrim tap: back to exactly where they were.
      await tester.tapAt(const Offset(195, 40));
      await _condensed(tester);
      expect(find.byType(VanaSheet), findsNothing);
      expect(h.location, '/food');
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
      unawaited(h.router.push('/food'));
      await tester.pumpAndSettle();
      await _open(tester);

      await tester.binding.handlePopRoute();
      await _condensed(tester);
      expect(find.byType(VanaSheet), findsNothing);
      expect(h.location, '/food');
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

  group('VS-7 and one height (mp-265)', () {
    Rect glass(WidgetTester tester) =>
        tester.getRect(find.byType(GlassSheetSurface));

    testWidgets('a drag down closes to the same screen, condensing', (
      tester,
    ) async {
      final h = await _pump(tester, initial: '/food');
      await _open(tester);
      final open = glass(tester);
      await tester.drag(
        find.byKey(const ValueKey('vana_sheet.grabber')),
        Offset(0, open.height * 0.6),
      );
      await tester.pump();
      await tester.pump(
        Duration(milliseconds: VanaSheet.condenseDuration.inMilliseconds ~/ 2),
      );
      expect(glass(tester).width, lessThan(open.width * 0.8));
      await _condensed(tester);
      expect(find.byType(VanaSheet), findsNothing);
      expect(h.location, '/food');
      expect(find.byKey(_launcher), findsOneWidget);
    });

    testWidgets('one message opens at the one height, and a send does not '
        'grow it', (tester) async {
      final repo = _FakeChatRepo();
      final h = await _pump(tester, repo: repo);
      await _open(tester);
      await _close(tester);
      // The opener has no offers here: one message, nothing to act on.
      repo.history = [
        VanaMessage(
          id: 'm1',
          conversationId: 'conv-server',
          role: VanaMessageRole.assistant,
          content: 'Morning. What is on your mind?',
          createdAt: DateTime(2026, 9, 10, 9),
        ),
      ];
      h.container.invalidate(
        vanaChatControllerProvider(
          kind: VanaConversationKind.general,
          conversationId: 'conv-server',
        ),
      );
      await _open(tester);
      await tester.pumpAndSettle();
      final one = glass(tester);
      expect(one.height, closeTo(844 * VanaSheet.heightFraction, 0.5));
      expect(one.bottom, closeTo(844, 0.5));

      await _send(tester, 'what about lunch');
      await tester.pump(VanaSheet.settleDuration);
      expect(glass(tester), one);
    });

    testWidgets('an empty conversation opens at the one height while the '
        'opener streams in', (tester) async {
      await _pump(tester);
      await _open(tester);
      expect(
        glass(tester).height,
        closeTo(844 * VanaSheet.heightFraction, 0.5),
      );
    });
  });

  group('hand-offs (mp-265 clause 4)', () {
    const planHandOff = VanaHandOffPart(
      target: VanaHandOffTarget.mealPlan,
      label: 'Plan my meals',
    );

    testWidgets('asked for a plan, Vana answers with a button, not a picker; '
        'a tap closes the sheet onto the meal-planning page', (tester) async {
      final repo = _FakeChatRepo()..replyParts = const [planHandOff];
      final h = await _pump(tester, repo: repo);
      await _open(tester);
      await _send(tester, 'make me a meal plan for the week');

      expect(find.byType(MealPickerCarousel), findsNothing);
      final button = find.byKey(const ValueKey('meal_planning.hand_off'));
      expect(button, findsOneWidget);
      expect(
        find.ancestor(of: button, matching: find.byType(VanaSheetVanaTurn)),
        findsOneWidget,
      );

      await tester.tap(button);
      await _condensed(tester);
      await tester.pumpAndSettle();
      expect(find.byType(VanaSheet), findsNothing);
      // The Food tab of the shell, on Plan: never a bare Food page with no
      // tab bar pushed over it.
      expect(h.location, '/main?tab=food&food=plan');
      expect(h.router.canPop(), isFalse);
    });

    testWidgets('an event hand-off with an id lands on that event', (
      tester,
    ) async {
      final repo = _FakeChatRepo()
        ..replyParts = const [
          VanaHandOffPart(
            target: VanaHandOffTarget.carbLoading,
            label: 'Set up carb loading',
            entityId: 'ev-1',
          ),
        ];
      final h = await _pump(tester, repo: repo);
      await _open(tester);
      await _send(tester, 'carb loading for my marathon');
      await tester.tap(find.byKey(const ValueKey('meal_planning.hand_off')));
      await _condensed(tester);
      await tester.pumpAndSettle();
      expect(h.location, '/events/ev-1');
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
      unawaited(h.router.push('/food'));
      await tester.pumpAndSettle();
      await _open(tester);
      await _send(tester, 'what should I eat before this');

      final sent = h.repo.calls.last;
      expect(sent['message'], 'what should I eat before this');
      expect(sent['situation'], {
        'route': '/food',
        'entityId': 'act-1',
        'date': '2026-09-12',
      });

      // The formula library has no scope: it speaks as its route, not as the
      // plan.
      await _close(tester);
      h.router.go(_formulas);
      await tester.pumpAndSettle();
      await _open(tester);
      await _send(tester, 'and now?');
      expect(h.repo.calls.last['situation'], {'route': _formulas});
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
      final repo = _FakeChatRepo()
        ..throwOnStream = const VanaOfflineException('offline');
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

    // Testing-wave 122-004: a 403 pro_required can never pass on a retry, so
    // the line shows without one; the router owns the paywall.
    testWidgets('pro_required: the line, and no Retry', (tester) async {
      final repo = _FakeChatRepo()
        ..throwOnStream = const ProRequiredException();
      await _pump(tester, repo: repo);
      await _open(tester);
      final line = loadDefaultContent()['meal_planning.pro_required']!;
      expect(find.text(line), findsOneWidget);
      expect(find.byKey(const ValueKey('vana_sheet.retry')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    // Testing-wave 129 (Finding 88-022): a message sent offline vanished;
    // only the offline line showed. The text stays where the athlete sent
    // it, and Retry sends that same text.
    testWidgets('a message sent offline stays on screen, and Retry sends it', (
      tester,
    ) async {
      final repo = _FakeChatRepo();
      await _pump(tester, repo: repo);
      await _open(tester);

      repo.throwOnStream = const VanaOfflineException('offline');
      await _send(tester, 'is rice ok tonight');

      final unsent = find.byKey(const ValueKey('vana_sheet.unsent'));
      expect(unsent, findsOneWidget);
      expect(
        find.descendant(of: unsent, matching: find.text('is rice ok tonight')),
        findsOneWidget,
      );
      final offline = loadDefaultContent()['meal_planning.vana_offline']!;
      expect(find.text(offline), findsOneWidget);

      repo.throwOnStream = null;
      await tester.tap(find.byKey(const ValueKey('vana_sheet.retry')));
      await tester.pump();
      await _settleTurn(tester);

      expect(repo.calls.last['message'], 'is rice ok tonight');
      expect(unsent, findsNothing);
      expect(find.text(offline), findsNothing);
      expect(find.text('is rice ok tonight'), findsOneWidget);
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
          .read(vanaChatControllerProvider(kind: VanaConversationKind.general))
          .value!;
      expect(state.isStreaming, isTrue);
      expect(tester.getRect(find.byType(VanaSheet)), before);

      repo.hold!.complete();
      await _settleTurn(tester);
    });
  });

  group('the conversation surface', () {
    const offers = VanaChoicesPart(
      options: ['What should I eat today?', 'Before tomorrow', 'Start a plan'],
    );

    testWidgets('quick replies: the opening\'s offers, at most two, the first '
        'filled and the second outline; a tap sends it', (tester) async {
      final repo = _FakeChatRepo()..openerParts = const [offers];
      await _pump(tester, repo: repo);
      await _open(tester);

      final replies = tester.widget<VanaSheetQuickReplies>(
        find.byType(VanaSheetQuickReplies),
      );
      expect(replies.labels, ['What should I eat today?', 'Before tomorrow']);
      expect(find.byKey(const ValueKey('vana_sheet.quick_reply_1')), findsOne);
      expect(find.text('Start a plan'), findsNothing);
      // The offers are the replies; they are not drawn inline as well.
      expect(find.byType(ChoiceChips), findsNothing);
      BoxDecoration face(int i) =>
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byKey(ValueKey('vana_sheet.quick_reply_$i')),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(face(0).color, AppColors.orange);
      expect(face(1).color, isNull);
      expect(face(1).border, isNotNull);

      await tester.tap(find.byKey(const ValueKey('vana_sheet.quick_reply_1')));
      await tester.pump();
      await _settleTurn(tester);
      expect(repo.calls.last['message'], 'Before tomorrow');
      expect(find.byType(VanaSheetAthleteTurn), findsOneWidget);
      expect(find.byType(VanaSheetQuickReplies), findsNothing);
    });

    testWidgets('quick replies retire on the first thread entry and stay '
        'retired, even when that turn fails', (tester) async {
      final repo = _FakeChatRepo()..openerParts = const [offers];
      await _pump(tester, repo: repo);
      await _open(tester);
      expect(find.byType(VanaSheetQuickReplies), findsOneWidget);

      repo.throwOnStream = const VanaOfflineException('offline');
      await tester.tap(find.byKey(const ValueKey('vana_sheet.quick_reply_0')));
      await tester.pump();
      await _settleTurn(tester);
      // The failed turn left the transcript, its text kept as unsent
      // (88-022); the replies did not come back.
      expect(find.byType(VanaSheetAthleteTurn), findsOneWidget);
      expect(find.byKey(const ValueKey('vana_sheet.unsent')), findsOneWidget);
      expect(find.byKey(const ValueKey('vana_sheet.error')), findsOneWidget);
      expect(find.byType(VanaSheetQuickReplies), findsNothing);
      expect(find.byType(ChoiceChips), findsNothing);
    });

    testWidgets('a conversation with a thread reopens without quick replies', (
      tester,
    ) async {
      final repo = _FakeChatRepo()..openerParts = const [offers];
      final h = await _pump(tester, repo: repo);
      await _open(tester);
      await _send(tester, 'hi');
      await _close(tester);
      repo.history = h.container
          .read(vanaChatControllerProvider(kind: VanaConversationKind.general))
          .value!
          .messages;
      await _open(tester);
      expect(find.byType(VanaSheetQuickReplies), findsNothing);
      expect(find.byType(ChoiceChips), findsNothing);
    });

    testWidgets('the typing indicator shows only while a turn is in flight, '
        'and never alongside quick replies', (tester) async {
      final repo = _FakeChatRepo()
        ..openerParts = const [offers]
        ..holdFirst = Completer<void>();
      await _pump(tester, repo: repo);
      await _open(tester);
      // The opener is in flight with nothing said yet.
      expect(find.byKey(const ValueKey('vana_sheet.typing')), findsOneWidget);
      expect(find.byType(VanaSheetQuickReplies), findsNothing);

      repo.holdFirst!.complete();
      await _settleTurn(tester);
      expect(find.byKey(const ValueKey('vana_sheet.typing')), findsNothing);
      expect(find.byType(VanaSheetQuickReplies), findsOneWidget);

      repo
        ..holdFirst = Completer<void>()
        ..openerParts = const [];
      await tester.tap(find.byKey(const ValueKey('vana_sheet.quick_reply_0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('vana_sheet.typing')), findsOneWidget);
      expect(find.byType(VanaSheetQuickReplies), findsNothing);

      repo.holdFirst!.complete();
      await _settleTurn(tester);
      expect(find.byKey(const ValueKey('vana_sheet.typing')), findsNothing);
    });

    testWidgets('an opener whose offers land before its prose shows the '
        'typing indicator, not the replies', (tester) async {
      final gate = Completer<void>();
      final repo = _FakeChatRepo()..leadParts = (const [offers], gate);
      await _pump(tester, repo: repo);
      await _open(tester);
      expect(find.byKey(const ValueKey('vana_sheet.typing')), findsOneWidget);
      expect(find.byType(VanaSheetQuickReplies), findsNothing);

      gate.complete();
      await _settleTurn(tester);
      expect(find.byKey(const ValueKey('vana_sheet.typing')), findsNothing);
      expect(find.byType(VanaSheetQuickReplies), findsOneWidget);
    });

    testWidgets('send is inert with an empty draft and orange with one', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _open(tester);
      final calls = h.repo.calls.length;
      Color sendColor() =>
          (tester
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: find.byKey(const ValueKey('vana_sheet.send')),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;

      expect(sendColor(), isNot(AppColors.orange));
      await tester.tap(find.byKey(const ValueKey('vana_sheet.send')));
      await tester.pump();
      expect(h.repo.calls, hasLength(calls));

      await tester.enterText(
        find.byKey(const ValueKey('vana_sheet.composer')),
        '   ',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(sendColor(), isNot(AppColors.orange));

      await tester.enterText(
        find.byKey(const ValueKey('vana_sheet.composer')),
        'hello',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(sendColor(), AppColors.orange);
    });

    testWidgets('a meal picker renders inside Vana\'s message column', (
      tester,
    ) async {
      final repo = _FakeChatRepo()..replyParts = [_picker];
      await _pump(tester, repo: repo);
      await _open(tester);
      await _send(tester, 'dinner ideas');

      final picker = find.byType(MealPickerCarousel);
      expect(picker, findsOneWidget);
      final turn = find.ancestor(
        of: picker,
        matching: find.byType(VanaSheetVanaTurn),
      );
      expect(turn, findsOneWidget);
      // Vana's turn is drawn with her one avatar, the "V" disc.
      expect(
        find.descendant(of: turn, matching: find.byType(VanaAvatar)),
        findsOneWidget,
      );
      // It starts where the prose starts, right of the avatar.
      final prose = tester.getTopLeft(find.text('Sure.')).dx;
      expect(tester.getTopLeft(picker).dx, closeTo(prose, 0.5));
    });

    for (final (name, scale) in [('default text', 1.0), ('large text', 2.0)]) {
      testWidgets('iPhone SE width, $name: the treatments lay out without '
          'overflow', (tester) async {
        final repo = _FakeChatRepo()..openerParts = const [offers];
        final h = await _pump(tester, repo: repo);
        tester.view.physicalSize = const Size(320, 568);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        expect(h.location, '/main');

        await _open(tester);
        expect(find.byType(VanaSheetQuickReplies), findsOneWidget);
        await _send(
          tester,
          'What should I eat before my long run tomorrow morning?',
        );
        expect(tester.takeException(), isNull);

        final bubble = tester.getRect(find.byType(VanaSheetAthleteTurn));
        final column = 320 - 2 * kVanaSheetColumnInset;
        // Right-aligned to the column, and no wider than 82 % of it.
        expect(bubble.right, closeTo(320 - kVanaSheetColumnInset, 0.5));
        final face = tester.getRect(
          find.descendant(
            of: find.byType(VanaSheetAthleteTurn),
            matching: find.byType(Container),
          ),
        );
        expect(face.width, lessThanOrEqualTo(column * 0.82 + 0.5));
        // Vana's prose starts right of the avatar, with no bubble.
        expect(
          tester.getTopLeft(find.text('Sure.')).dx,
          closeTo(kVanaSheetColumnInset + kVanaSheetProseInset, 0.5),
        );
      });
    }
  });
}

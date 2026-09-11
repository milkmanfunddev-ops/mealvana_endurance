/// The companion that speaks first (vana-moment spec, Conformance L2), over a
/// real GoRouter, the real host, the real moment controller and the home
/// shell's real chrome: RING → PILL → TINTED on a to-do, the tab bar stepping
/// aside while the pill shows, VM-1 to VM-3 through [VanaCompanionHost], and
/// reduced motion; and the recovery moment after a finished session.
///
/// Tonight's run is seeded the way the Supabase row carries it: 17:30 wall
/// clock with a 60 min window, and the clock stands at 16:45 with nothing
/// eaten since 16:30.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/activities/data/activity_mapper.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/calendar/presentation/providers/calendar_selected_date_provider.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/home_shell/presentation/home_shell_chrome.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_ambient_conversation_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_chat_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_companion.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/kyle_tab_bar.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/vana_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/container.dart';
import '../../helpers/vana_moment_inputs.dart';
import '../helpers/test_content.dart';

const _launcher = ValueKey('vana_sheet.launcher');
const _tonight = "Fuel tonight's run?";
const _walk = 'Walk me through it';
const _handle = "I'll handle it";

final _run = ActivityMapper(logger: NoopAppLogger()).fromJson({
  'id': 'act-run',
  'user_id': 'user-1',
  'activity_type': 'running',
  'title': 'Tempo run',
  'scheduled_date_time': '2026-09-11T17:30:00',
  'status': 'planned',
  'duration_minutes': 60,
  'time_before_minutes': 60,
  'created_at': '2026-09-01T12:00:00+00:00',
  'updated_at': '2026-09-01T12:00:00+00:00',
});

/// This morning's run, marked done: 06:30 for 60 min, so it ended at 07:30.
final _finished = ActivityMapper(logger: NoopAppLogger()).fromJson({
  'id': 'act-am',
  'user_id': 'user-1',
  'activity_type': 'running',
  'title': 'Easy run',
  'scheduled_date_time': '2026-09-11T06:30:00',
  'planned_time': '2026-09-11T06:30:00',
  'actual_time': '2026-09-11T06:30:00',
  'completed_at': '2026-09-11T06:30:00',
  'status': 'completed',
  'duration_minutes': 60,
  'created_at': '2026-09-01T12:00:00+00:00',
  'updated_at': '2026-09-01T12:00:00+00:00',
});

MealLog _snack() => MealLog.fromSupabaseJson({
  'id': 'log-snack',
  'user_id': 'user-1',
  'log_date': '2026-09-11',
  'slot': 'snack',
  'name': 'Bagel and honey',
  'source': 'manual',
  'items': <Object?>[],
  'eaten_at': DateTime(2026, 9, 11, 16, 50).toUtc().toIso8601String(),
  'created_at': DateTime(2026, 9, 11, 16, 50).toUtc().toIso8601String(),
  'updated_at': DateTime(2026, 9, 11, 16, 50).toUtc().toIso8601String(),
  'is_deleted': false,
})!;

VanaMessage _message(String id, VanaMessageRole role, String text) =>
    VanaMessage(
      id: id,
      conversationId: 'conv-today',
      role: role,
      content: text,
      createdAt: DateTime(2026, 9, 11, 9),
    );

/// Answers the way the server does: an opener with a moment names the run
/// and asks with two replies; what a turn streams is stored, so a second
/// sheet reads it back.
class _FakeChatRepo extends Fake implements VanaChatRepository {
  final List<Map<String, Object?>> calls = [];
  List<VanaMessage> history = [];

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
  }) async {
    calls.add({
      'message': message,
      'conversationId': conversationId,
      'opener': opener,
      'moment': moment?.toWire(),
    });
    final id = conversationId ?? 'conv-server';
    final text = moment != null
        ? 'Your tempo run is at 5:30 and the window opened at 4:30.'
        : opener
        ? 'Morning.'
        : 'A bagel with honey.';
    const offers = VanaChoicesPart(options: [_walk, _handle]);
    history = [
      ...history,
      if (message != null)
        _message('u${history.length}', VanaMessageRole.user, message),
      VanaMessage(
        id: 'v${history.length}',
        conversationId: id,
        role: VanaMessageRole.assistant,
        content: text,
        parts: moment != null ? const [offers] : const [],
        createdAt: DateTime(2026, 9, 11, 16, 45),
      ),
    ];
    Stream<VanaStreamEvent> events() async* {
      yield VanaTextEvent(text);
      if (moment != null) yield const VanaUiEvent(offers);
      yield const VanaDoneEvent();
    }

    return VanaChatResponse(conversationId: id, kind: kind, events: events());
  }

  @override
  Future<List<VanaMessage>> fetchMessages(String conversationId) async =>
      history;
}

class _FakeActionClient extends Fake implements VanaActionClient {
  @override
  Future<VanaActionResult> run(UiAction action) async =>
      const VanaActionResult(parts: [], extras: {});
}

class _FixedDay extends CalendarSelectedDate {
  @override
  DateTime build() => DateTime(2026, 9, 11);
}

/// `/main` as the shell composes it: the home chrome with its tab bar.
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: HomeShellChrome(
      showDateHeader: false,
      body: ListView(
        children: [
          for (var i = 0; i < 30; i++)
            SizedBox(height: 60, child: Text('row $i')),
        ],
      ),
      destinations: [
        KyleTabBarDestination(
          id: 'timeline',
          icon: FontAwesomeIcons.solidHouse.data,
          label: 'Timeline',
        ),
        KyleTabBarDestination(
          id: 'events',
          icon: FontAwesomeIcons.trophy.data,
          label: 'Events',
        ),
        KyleTabBarDestination(
          id: 'food',
          icon: FontAwesomeIcons.utensils.data,
          label: 'Food',
        ),
      ],
      activeTabId: 'timeline',
      onSelectTab: (_) {},
    ),
  );
}

/// Stands in for the full-screen chat: it sends on the same conversation's
/// notifier, as the chat route does.
class _ChatRoute extends ConsumerWidget {
  const _ChatRoute({this.conversationId});

  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('chat_route.send'),
        onPressed: () => ref
            .read(
              vanaChatControllerProvider(
                kind: VanaConversationKind.general,
                conversationId: conversationId,
              ).notifier,
            )
            .send('What should I eat?'),
        child: const Text('send'),
      ),
    ),
  );
}

class _Harness {
  _Harness(this.repo, this.container, this.logs);
  final _FakeChatRepo repo;
  final ProviderContainer container;
  final StreamController<List<MealLog>> logs;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool reducedMotion = false,
  String? ambient,
  List<VanaMessage> history = const [],
  List<Activity>? activities,
  DateTime? now,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    if (ambient != null)
      'vana.ambient_conversation.user-1': '2026-09-11|$ambient',
  });
  final prefs = await SharedPreferences.getInstance();
  final repo = _FakeChatRepo()..history = [...history];
  final logs = StreamController<List<MealLog>>.broadcast();
  final observer = VanaCompanionObserver();
  final router = GoRouter(
    initialLocation: '/main',
    observers: [observer],
    routes: [
      GoRoute(path: '/main', builder: (_, _) => const _Home()),
      GoRoute(
        path: '/vana',
        builder: (_, state) =>
            _ChatRoute(conversationId: state.uri.queryParameters['c']),
      ),
    ],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [
      ...baseOverrides(),
      ...vanaMomentInputs(
        activities: activities ?? [_run],
        logs: () async* {
          yield const <MealLog>[];
          yield* logs.stream;
        },
        reducedMotion: reducedMotion,
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
      contentServiceProvider.overrideWith(testContentService),
      proUnlockedProvider.overrideWithValue(true),
      vanaChatRepositoryProvider.overrideWithValue(repo),
      vanaActionClientProvider.overrideWithValue(_FakeActionClient()),
      vanaClockProvider.overrideWithValue(
        () => now ?? DateTime(2026, 9, 11, 16, 45),
      ),
      calendarSelectedDateProvider.overrideWith(_FixedDay.new),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: reducedMotion),
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => VanaCompanionHost(
            router: router,
            observer: observer,
            child: child!,
          ),
        ),
      ),
    ),
  );
  // The moment resolves, and the launcher on screen asks it to ring.
  await tester.pump();
  await tester.pump();
  await tester.pump();
  return _Harness(repo, container, logs);
}

/// The moment's controller keeps a resolve timer while a workout is ahead:
/// take the tree down and dispose it before the test ends.
Future<void> _finish(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  h.container.dispose();
  await h.logs.close();
}

/// The chip reads `Fuel plan · to do`, in the to-do's orange.
void _expectToDo(WidgetTester tester) {
  final chip = tester.widget<VanaSheetStatusChip>(
    find.byType(VanaSheetStatusChip),
  );
  expect(chip.label, 'Fuel plan · to do');
  expect(chip.tone, VanaSheetStatusTone.toDo);
}

VanaLauncherState _state(WidgetTester tester) =>
    tester.widget<VanaLauncher>(find.byType(VanaLauncher)).state;

bool _barCollapsed(WidgetTester tester) =>
    tester.widget<KyleTabBar>(find.byType(KyleTabBar)).collapsed;

/// Past the ring and the pill: the launcher at rest, tinted.
Future<void> _untilTinted(WidgetTester tester) async {
  await tester.pump(vanaMomentRingDuration);
  await tester.pump(vanaMomentPillDuration);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_launcher));
  await tester.pump();
  await tester.pump(VanaSheet.riseDuration);
  await _settle(tester);
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('vana_sheet.close')));
  await tester.pump();
  await tester.pump(
    VanaSheet.condenseDuration + const Duration(milliseconds: 50),
  );
  await tester.pump();
}

void main() {
  group('the launcher speaks first', () {
    testWidgets('RING → PILL → TINTED, the tab bar stepping aside for the '
        'pill', (tester) async {
      final h = await _pump(tester);
      expect(_state(tester), VanaLauncherState.ring);
      expect(find.text(_tonight), findsNothing);
      expect(_barCollapsed(tester), isFalse);

      await tester.pump(vanaMomentRingDuration);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_state(tester), VanaLauncherState.pill);
      expect(find.text(_tonight), findsOneWidget);
      expect(_barCollapsed(tester), isTrue);

      await tester.pump(vanaMomentPillDuration);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_state(tester), VanaLauncherState.tinted);
      expect(find.text(_tonight), findsNothing);
      expect(_barCollapsed(tester), isFalse);
      await _finish(tester, h);
    });

    testWidgets('the pill and the collapsed bar do not overlap at iPhone-SE '
        'width', (tester) async {
      final h = await _pump(tester, size: const Size(320, 568));
      await tester.pump(vanaMomentRingDuration);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_state(tester), VanaLauncherState.pill);
      final bar = tester.getRect(find.byType(KyleTabBar));
      final pill = tester.getRect(find.byKey(_launcher));
      expect(pill.left, greaterThan(bar.right));
      expect(pill.right, lessThanOrEqualTo(320));
      await _finish(tester, h);
    });

    testWidgets('its label says what Vana has to say', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await _pump(tester);
      expect(
        tester.getSemantics(find.byKey(_launcher)).label,
        'Ask Vana: $_tonight',
      );
      handle.dispose();
      await _finish(tester, h);
    });

    testWidgets('reduced motion: no ring, straight to tinted, and the pill '
        'still shows', (tester) async {
      final h = await _pump(tester, reducedMotion: true);
      expect(_state(tester), VanaLauncherState.pill);
      expect(find.text(_tonight), findsOneWidget);
      await tester.pump(vanaMomentPillDuration);
      await tester.pump();
      expect(_state(tester), VanaLauncherState.tinted);
      await _finish(tester, h);
    });

    testWidgets('something logged in the window retires it', (tester) async {
      final h = await _pump(tester);
      await _untilTinted(tester);
      h.logs.add([_snack()]);
      await tester.pump();
      await tester.pump();
      expect(_state(tester), VanaLauncherState.quiet);
      await _finish(tester, h);
    });
  });

  group('M-2: the recovery moment', () {
    testWidgets('a finished session with nothing logged: the pill asks '
        '"Recovery fuel?", and the sheet opens on the session', (tester) async {
      final h = await _pump(
        tester,
        activities: [_finished],
        now: DateTime(2026, 9, 11, 7, 45),
      );
      await tester.pump(vanaMomentRingDuration);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_state(tester), VanaLauncherState.pill);
      expect(find.text('Recovery fuel?'), findsOneWidget);
      await tester.pump(vanaMomentPillDuration);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_state(tester), VanaLauncherState.tinted);

      await _open(tester);
      final call = h.repo.calls.single;
      expect(call['opener'], isTrue);
      expect(call['moment'], {
        'kind': 'recovery',
        'activity_id': 'act-am',
        'window_minutes': 120,
        'branch': 'relaxed',
      });
      _expectToDo(tester);
      await _finish(tester, h);
    });
  });

  group('VM-1 to VM-3: the sheet opens on the moment', () {
    testWidgets('VM-1 mid-thread: the opener lands in the day\'s '
        'conversation with two quick replies and the orange to-do', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        ambient: 'conv-today',
        history: [
          _message('m1', VanaMessageRole.user, 'What should I eat today?'),
          _message('m2', VanaMessageRole.assistant, 'Oats at breakfast.'),
        ],
      );
      await _untilTinted(tester);
      await _open(tester);

      final call = h.repo.calls.single;
      expect(call['opener'], isTrue);
      expect(call['conversationId'], 'conv-today');
      expect(call['moment'], {
        'kind': 'pre_workout',
        'activity_id': 'act-run',
        'window_minutes': 60,
      });
      // The thread is still there, and the moment starts a new exchange.
      expect(find.text('Oats at breakfast.'), findsOneWidget);
      expect(find.text(_walk), findsOneWidget);
      expect(find.text(_handle), findsOneWidget);
      _expectToDo(tester);
      await _finish(tester, h);
    });

    testWidgets('VM-2: a dismiss keeps it tinted with no second ring, and '
        'the next sheet opens on the same opener', (tester) async {
      final h = await _pump(tester, ambient: 'conv-today');
      await _untilTinted(tester);
      await _open(tester);
      await _close(tester);

      expect(_state(tester), VanaLauncherState.tinted);
      await tester.pump(vanaMomentRingDuration);
      expect(_state(tester), VanaLauncherState.tinted);

      await _open(tester);
      expect(h.repo.calls, hasLength(1), reason: 'the opener was sent twice');
      expect(find.text(_walk), findsOneWidget);
      _expectToDo(tester);
      await _finish(tester, h);
    });

    testWidgets('VM-3: answering retires it', (tester) async {
      final h = await _pump(tester, ambient: 'conv-today');
      await _untilTinted(tester);
      await _open(tester);
      await tester.tap(find.text(_walk));
      await tester.pump();
      await _settle(tester);
      expect(h.repo.calls.last['message'], _walk);
      await _close(tester);

      expect(_state(tester), VanaLauncherState.quiet);
      await _open(tester);
      // The moment has gone: no second opener.
      expect(h.repo.calls.where((c) => c['moment'] != null), hasLength(1));
      await _finish(tester, h);
    });

    testWidgets('VM-3 from the full-screen chat: a turn sent there, in the '
        'moment\'s exchange, answers it too', (tester) async {
      final h = await _pump(tester, ambient: 'conv-today');
      await _untilTinted(tester);
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('vana_sheet.full_screen')));
      await tester.pump();
      await tester.pump(
        VanaSheet.condenseDuration + const Duration(milliseconds: 50),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat_route.send')));
      await _settle(tester);
      expect(h.repo.calls.last['message'], 'What should I eat?');
      final router = GoRouter.of(tester.element(find.byType(_ChatRoute)));
      router.pop();
      await tester.pumpAndSettle();
      expect(_state(tester), VanaLauncherState.quiet);
      await _finish(tester, h);
    });

    testWidgets('the day\'s first sheet opens a new conversation on the '
        'moment', (tester) async {
      final h = await _pump(tester);
      await _untilTinted(tester);
      await _open(tester);
      expect(h.repo.calls.single['conversationId'], isNull);
      expect(h.repo.calls.single['moment'], isNotNull);
      expect(find.text(_walk), findsOneWidget);
      _expectToDo(tester);
      await _finish(tester, h);
    });
  });
}

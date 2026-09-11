// Golden conformance — the Vana sheet (vana-sheet spec, Conformance L1):
// CLOSED (the launcher over a populated screen), OPEN and STREAMING, each
// light and dark, at iPhone-SE width, over mock shell content and the real
// tab bar, so the glass composes against real content rather than a flat fill
// and the launcher is seen in the tab bar's utility slot. The sheet's inside
// is dark in both modes (glass-sheet is dark-first; tokens.md defers the light
// variant); light mode changes the page behind it.
//
// The sheet is the real composed one — host, route, conversation — driven by
// a fake repository, so a golden that moves means the sheet moved.
//
// The inside of the sheet (ticket 07, "Inside the sheet"): OPEN is the
// opening — Vana's prose with the sparkle avatar and her offers as the two
// quick replies, under the electrolyte Update chip (offers are a menu, not a
// to-do); STREAMING is the athlete's turn and the typing indicator; THREAD is
// the athlete's turn answered with a follow-up question, which is a to-do on
// the Fuel Timeline, so the chip is the orange "Fuel plan · to do" and the
// question's chips compose in Vana's column; THREAD at large text is the same
// at iPhone-SE width with the text scaled to 200 %.
//
// OPEN and STREAMING were regenerated for ticket 07 without a spec change:
// ticket 06 drew a placeholder interior, knowingly short of the spec's
// "Inside the sheet", and these are the first goldens of the spec's own.
//
// The launcher when Vana speaks first (vana-moment spec, Conformance L1):
// PILL — the to-do's line out beside the tinted launcher, the tab bar
// retracted to its button — and TINTED orange at rest, each light and dark.
// The bar's retract is the home chrome's rule (home_shell_chrome.dart), which
// the mock ground mirrors; the widget test holds it on the real chrome.
//
// The ERROR state and the suppression rule are held by widget tests
// (vana_companion_test.dart): the suppression is "no node", which a picture
// cannot show.
//
// Regenerate with:
//   flutter test test/features/meal_planning/presentation/widgets/vana_companion_goldens_test.dart --update-goldens
// RULE: a golden may only be regenerated AFTER the spec changes — never to
// make a red test pass.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/activities/data/activity_mapper.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_ambient_conversation_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_moment_controller.dart';
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
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../home_shell/home_shell_test_fonts.dart';
import '../../helpers/container.dart';
import '../../helpers/vana_moment_inputs.dart';
import '../helpers/test_content.dart';

/// iPhone SE (1st gen) — the narrowest layout the app supports.
const _size = Size(320, 568);

class _FakeChatRepo extends Fake implements VanaChatRepository {
  /// Holds the athlete's turn before any prose arrives — STREAMING.
  Completer<void>? hold;

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
    final hold = this.hold;
    Stream<VanaStreamEvent> events() async* {
      if (hold != null && !opener) await hold.future;
      yield VanaTextEvent(
        opener
            ? "That's your fuel timeline behind me. Tonight's run is at 5:30 — "
                  'want me to walk you through fueling it?'
            : 'Have a banana and a slice of toast about an hour before.',
      );
      yield VanaUiEvent(
        opener
            ? const VanaChoicesPart(
                options: ['Walk me through it', "I'll explore on my own"],
              )
            : const VanaChoicesPart(
                question: 'Is it a hard session?',
                options: ['Easy run', 'Intervals'],
              ),
      );
      yield const VanaDoneEvent();
    }

    return VanaChatResponse(
      conversationId: conversationId ?? 'conv-server',
      kind: kind,
      events: events(),
    );
  }

  @override
  Future<List<VanaMessage>> fetchMessages(String conversationId) async =>
      const [];
}

class _FakeActionClient extends Fake implements VanaActionClient {
  @override
  Future<VanaActionResult> run(UiAction action) async =>
      const VanaActionResult(parts: [], extras: {});
}

/// Mock shell content: timeline and fuel-window blocks, so the glass has
/// something recognizable behind it.
class _Ground extends ConsumerWidget {
  const _Ground({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = dark ? AppColors.cream : AppColors.blackberry;
    return Scaffold(
      backgroundColor: dark ? AppColors.blackberry : AppColors.cream,
      body: Stack(
        children: [
          Positioned.fill(child: _cards(ink)),
          // The tab bar where the shell anchors it, so the launcher is seen
          // in the utility slot it fills.
          Positioned(
            left: 14,
            bottom: 28,
            child: KyleTabBar(
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
              activeId: 'timeline',
              // The chrome's rule: the bar retracts while the pill shows.
              collapsed:
                  ref.watch(vanaMomentControllerProvider).value?.pillShows ??
                  false,
              maxWidth:
                  _size.width -
                  14 -
                  KyleTabBar.utilitySlotGap -
                  KyleTabBar.utilitySlotSize -
                  14,
              onSelect: (_) {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _cards(Color ink) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(14, 40, 14, 0),
    children: [
      for (var i = 0; i < 8; i++) ...[
        Container(
          height: 76,
          decoration: BoxDecoration(
            color: i.isEven
                ? (dark ? AppColors.blackberryLight : AppColors.creamDark)
                : AppColors.orange.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.all(14),
          alignment: Alignment.topLeft,
          child: Text(
            i.isEven ? 'Timeline card ${i + 1}' : 'Fuel window ${i + 1}',
            style: TextStyle(
              fontFamily: AppTextStyles.apercu,
              fontSize: 14,
              color: ink.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ],
  );
}

/// Tonight's run, its window open since 16:30, as the Supabase row has it.
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

/// The last pump's container, for a test that must dispose it before it ends
/// (a moment keeps a resolve timer while its workout is ahead).
late ProviderContainer _container;

Future<_FakeChatRepo> _pump(
  WidgetTester tester, {
  required bool dark,
  double textScale = 1,
  bool moment = false,
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _FakeChatRepo();
  final observer = VanaCompanionObserver();
  final router = GoRouter(
    initialLocation: '/main',
    observers: [observer],
    routes: [
      GoRoute(
        path: '/main',
        builder: (_, _) => _Ground(dark: dark),
      ),
    ],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [
      ...baseOverrides(),
      ...vanaMomentInputs(activities: moment ? [_run] : const []),
      sharedPreferencesProvider.overrideWithValue(prefs),
      contentServiceProvider.overrideWith(testContentService),
      proUnlockedProvider.overrideWithValue(true),
      vanaChatRepositoryProvider.overrideWithValue(repo),
      vanaActionClientProvider.overrideWithValue(_FakeActionClient()),
      vanaClockProvider.overrideWithValue(
        moment
            ? () => DateTime(2026, 9, 11, 16, 45)
            : () => DateTime(2026, 9, 10, 9),
      ),
    ],
  );
  _container = container;
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
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
  return repo;
}

/// Frames long enough for a streamed turn to land and its text to reveal.
Future<void> _frames(WidgetTester tester, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('vana_sheet.launcher')));
  await tester.pump();
  await tester.pump(VanaSheet.riseDuration);
  await _frames(tester);
}

Future<void> _golden(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('../goldens/vana_sheet_$name.png'),
);

void main() {
  setUpAll(loadHomeShellFonts);

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('CLOSED — the launcher over a populated screen ($mode)', (
      tester,
    ) async {
      await _pump(tester, dark: dark);
      await _golden(tester, 'closed_$mode');
    });

    testWidgets('OPEN — the opener at rest height ($mode)', (tester) async {
      await _pump(tester, dark: dark);
      await _open(tester);
      await _golden(tester, 'open_$mode');
    });

    testWidgets('STREAMING — the athlete has asked; the answer is in flight '
        '($mode)', (tester) async {
      final repo = await _pump(tester, dark: dark);
      await _open(tester);
      repo.hold = Completer<void>();
      await tester.enterText(
        find.byKey(const ValueKey('vana_sheet.composer')),
        'What should I eat before it?',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('vana_sheet.send')));
      await tester.pump();
      // Unfocus so the golden is not of a blinking cursor.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 400));
      await _golden(tester, 'streaming_$mode');
      repo.hold!.complete();
      await _frames(tester, 10);
    });

    testWidgets("THREAD — the athlete's turn answered with a question, under "
        'the to-do chip ($mode)', (tester) async {
      await _pump(tester, dark: dark);
      await _open(tester);
      await _sendAndLand(tester);
      await _golden(tester, 'thread_$mode');
    });
  }

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('PILL — the to-do\'s line beside the tinted launcher, the '
        'tab bar retracted ($mode)', (tester) async {
      await _pump(tester, dark: dark, moment: true);
      await tester.pump(vanaMomentRingDuration);
      await tester.pump(const Duration(milliseconds: 600));
      await _golden(tester, 'moment_pill_$mode');
      await _dispose(tester);
    });

    testWidgets('TINTED — orange, the mark in blackberry ($mode)', (
      tester,
    ) async {
      await _pump(tester, dark: dark, moment: true);
      await tester.pump(vanaMomentRingDuration);
      await tester.pump(vanaMomentPillDuration);
      await tester.pump(const Duration(milliseconds: 600));
      await _golden(tester, 'moment_tinted_$mode');
      await _dispose(tester);
    });
  }

  testWidgets('THREAD at large text — iPhone-SE width, text at 200 %', (
    tester,
  ) async {
    await _pump(tester, dark: true, textScale: 2);
    await _open(tester);
    await _sendAndLand(tester);
    await _golden(tester, 'thread_large_text_dark');
  });
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  _container.dispose();
}

Future<void> _sendAndLand(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('vana_sheet.composer')),
    'What should I eat before it?',
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('vana_sheet.send')));
  await tester.pump();
  FocusManager.instance.primaryFocus?.unfocus();
  await _frames(tester);
}

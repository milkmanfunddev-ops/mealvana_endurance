// Golden conformance — the Vana sheet (vana-sheet spec, Conformance L1):
// CLOSED (the launcher over a populated screen), OPEN and STREAMING, each
// light and dark, at iPhone-SE width, over mock shell content so the glass
// composes against real content rather than a flat fill. The sheet's inside
// is dark in both modes (glass-sheet is dark-first; tokens.md defers the light
// variant); light mode changes the page behind it.
//
// The sheet is the real composed one — host, route, conversation — driven by
// a fake repository, so a golden that moves means the sheet moved.
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
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_ambient_conversation_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_companion.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/vana_sheet.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../home_shell/home_shell_test_fonts.dart';
import '../../helpers/container.dart';
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
class _Ground extends StatelessWidget {
  const _Ground({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? AppColors.cream : AppColors.blackberry;
    return Scaffold(
      backgroundColor: dark ? AppColors.blackberry : AppColors.cream,
      body: ListView(
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
      ),
    );
  }
}

Future<_FakeChatRepo> _pump(WidgetTester tester, {required bool dark}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _FakeChatRepo();
  final observer = VanaCompanionObserver();
  final router = GoRouter(
    initialLocation: '/main',
    observers: [observer],
    routes: [
      GoRoute(path: '/main', builder: (_, _) => _Ground(dark: dark)),
    ],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [
      ...baseOverrides(),
      sharedPreferencesProvider.overrideWithValue(prefs),
      contentServiceProvider.overrideWith(testContentService),
      proUnlockedProvider.overrideWithValue(true),
      vanaChatRepositoryProvider.overrideWithValue(repo),
      vanaActionClientProvider.overrideWithValue(_FakeActionClient()),
      vanaClockProvider.overrideWithValue(() => DateTime(2026, 9, 10, 9)),
    ],
  );
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
        builder: (context, child) =>
            VanaCompanionHost(router: router, observer: observer, child: child!),
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
  }
}

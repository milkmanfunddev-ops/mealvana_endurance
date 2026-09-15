// Golden: the general Vana chat's empty state (ticket 28, mp-268 clause 1).
// Vana's avatar, "Ask me anything" and the line about what she can reach
// for, with no example chips under them: the general conversation opens on
// the screen underneath, so a canned question has nothing to add. Light and
// dark, at iPhone-SE width, through the REAL VanaChatController with the
// transport faked to an empty conversation.
//
// Regenerate with:
//   flutter test test/features/meal_planning/presentation/screens/vana_chat_screen_empty_goldens_test.dart --update-goldens
// RULE: a golden may only be regenerated AFTER the spec changes — never to
// make a red test pass.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_chat_screen.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/choice_chip_button.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_theme.dart';

import '../../../home_shell/home_shell_test_fonts.dart';
import '../../helpers/container.dart';
import '../helpers/test_content.dart';

/// iPhone SE (1st gen) — the narrowest layout the app supports.
const _size = Size(320, 568);

/// A conversation with no turns yet.
class _EmptyRepo extends Fake implements VanaChatRepository {
  @override
  Future<List<VanaMessage>> fetchMessages(String conversationId) async =>
      const [];
}

class _NoPlan extends MealPlanController {
  @override
  Future<MealPlan?> build() async => null;
}

class _Credits extends CreditsController {
  @override
  Future<CreditWallet> build() async => CreditWallet.fromMap(const {
    'balance': 300,
    'allowance': 300,
    'allowance_monthly': 300,
    'allowance_expires_at': '2026-10-15T12:00:00+00:00',
  });
}

void main() {
  setUpAll(loadHomeShellFonts);

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('EMPTY — no example chips under the empty state ($mode)', (
      tester,
    ) async {
      tester.view.physicalSize = _size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(),
            contentServiceProvider.overrideWith(testContentService),
            vanaChatRepositoryProvider.overrideWithValue(_EmptyRepo()),
            mealPlanControllerProvider.overrideWith(() => _NoPlan()),
            creditsControllerProvider.overrideWith(() => _Credits()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: const VanaChatScreen(
              kind: VanaConversationKind.general,
              conversationId: 'conv-1',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final content = loadDefaultContent();
      expect(find.text(content['meal_planning.empty_title']!), findsOneWidget);
      expect(find.byType(ChoiceChipButton), findsNothing);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../goldens/vana_chat_empty_$mode.png'),
      );
    });
  }
}

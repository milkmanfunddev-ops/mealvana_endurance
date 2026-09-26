// Ticket 141 (Finding 118-005): Vana's round header and composer buttons and
// Browse meals' Search and Filters read as static text to a screen reader.
// They are buttons named by their tooltip, and the filter menu's items are
// 48 pt tall.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_catalog_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_catalog_browser.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_round_button.dart';

import '../helpers/test_content.dart';

class _FixedCatalogController extends MealCatalogController {
  _FixedCatalogController(this.fixed);

  final MealCatalogState fixed;

  @override
  FutureOr<MealCatalogState> build(CatalogSurface surface) => fixed;
}

MealRef _recipe(String id, String name) => MealRef(
  source: MealSource.library,
  id: id,
  name: name,
  mealType: MealType.dinner,
  kind: MealKind.recipe,
  kcal: 600,
  carbsG: 70,
  proteinG: 35,
  fatG: 15,
);

void main() {
  final content = loadDefaultContent();

  testWidgets('a round button is a button named by its tooltip', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Row(
              children: [
                VanaRoundButton.back(
                  key: const ValueKey('back'),
                  context: context,
                  onTap: () => taps++,
                ),
                VanaRoundButton(
                  key: const ValueKey('new'),
                  icon: FontAwesomeIcons.plus,
                  tooltip: 'New conversation',
                  onTap: () {},
                ),
                VanaRoundButton(
                  key: const ValueKey('mic'),
                  icon: FontAwesomeIcons.microphone,
                  tooltip: 'Dictate',
                  onTap: () {},
                  size: 36,
                  flat: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(const ValueKey('back'))),
      isSemantics(label: 'Back', isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('new'))),
      isSemantics(
        label: 'New conversation',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('mic'))),
      isSemantics(label: 'Dictate', isButton: true, hasTapAction: true),
    );
    await tester.tap(find.byKey(const ValueKey('back')));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('Browse meals: Search and Filters are named buttons, and the '
      'filter items are 48 pt tall', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          mealCatalogControllerProvider.overrideWith(
            () => _FixedCatalogController(
              MealCatalogState(
                recipes: [_recipe('D-1', 'Salmon quinoa bowl')],
                railsFromServer: true,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MealCatalogBrowser(
              onOpenMeal: (_) {},
              surface: CatalogSurface.browse,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final search = find.byKey(const ValueKey('meal_planning.search_button'));
    final filters = find.byKey(const ValueKey('meal_planning.filter_button'));
    expect(
      tester.getSemantics(search),
      isSemantics(
        label: content['meal_planning.meals_search_hint'],
        isButton: true,
        hasTapAction: true,
        hasToggledState: true,
        isToggled: false,
      ),
    );
    expect(
      tester.getSemantics(filters),
      isSemantics(
        label: content['meal_planning.filter_title'],
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(filters);
    await tester.pumpAndSettle();
    final items = find.byType(PopupMenuItem<String>);
    expect(items, findsWidgets);
    for (final item in tester.widgetList<PopupMenuItem<String>>(items)) {
      expect(item.height, greaterThanOrEqualTo(48));
    }
    for (final element in items.evaluate()) {
      expect(
        (element.renderObject! as RenderBox).size.height,
        greaterThanOrEqualTo(48),
      );
    }
    handle.dispose();
  });
}

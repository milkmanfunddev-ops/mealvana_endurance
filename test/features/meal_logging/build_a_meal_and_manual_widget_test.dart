// Ticket 136 (testing-wave; Findings 113-001, 113-004, 113-005, 113-007):
// the widget contracts around Build a Meal, the Manual tab and the Timeline
// meal card. The write paths behind them are covered in
// saved_meals_favorites_and_edit_seam_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/meal_card.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/quick_assembly.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/draft_meal_controller.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/build_meal_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/manual_log_form.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/meal_component_editor.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';
import '../meal_planning/presentation/helpers/test_content.dart';

const _logDate = '2026-09-26';

void main() {
  late Map<String, String> content;
  setUpAll(() => content = loadDefaultContent());

  group('113-001: the same combo added twice', () {
    testWidgets('shows four editable rows instead of throwing', (tester) async {
      // A Quick add hands the editor the same const instances each time.
      final combo = kQuickAssemblies.first.components;
      expect(combo, hasLength(2));
      final twice = [...combo, ...combo];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealComponentEditor(
                initialComponents: twice,
                onComponentsChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Dismissible), findsNWidgets(4));
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(4));
      expect(find.text(combo.first.name), findsNWidgets(2));
    });

    testWidgets('removing one of the pair leaves the other in place', (
      tester,
    ) async {
      const item = MealComponent(name: 'Banana', portion: '1 medium');
      List<MealComponent>? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealComponentEditor(
              initialComponents: const [item, item],
              onComponentsChanged: (c) => changed = c,
            ),
          ),
        ),
      );
      await tester.drag(find.text('Banana').first, const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(changed, hasLength(1));
      expect(find.text('Banana'), findsOneWidget);
    });
  });

  group('113-007: Back from Build a Meal', () {
    late ProviderContainer container;

    Future<void> openBuilder(WidgetTester tester) async {
      container = ProviderContainer(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          contentServiceProvider.overrideWith(testContentService),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      openBuildMealScreen(context, logDate: _logDate),
                  child: const Text('open builder'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open builder'));
      await tester.pumpAndSettle();
      expect(find.text('Build a Meal'), findsOneWidget);
    }

    testWidgets('a non-empty draft asks Discard / Keep building', (
      tester,
    ) async {
      await openBuilder(tester);
      container
          .read(draftMealControllerProvider(_logDate).notifier)
          .addComponent(const MealComponent(name: 'Banana', portion: '1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('build_meal.back_button')));
      await tester.pumpAndSettle();

      expect(find.text(content['build_meal.discard_title']!), findsOneWidget);
      expect(find.text(content['build_meal.keep_building']!), findsOneWidget);
      expect(find.text(content['build_meal.discard']!), findsOneWidget);

      // Keep building stays, with the draft intact.
      await tester.tap(find.byKey(const ValueKey('build_meal.keep_building')));
      await tester.pumpAndSettle();
      expect(find.text('Build a Meal'), findsOneWidget);
      expect(
        container.read(draftMealControllerProvider(_logDate)).components,
        hasLength(1),
      );

      // Discard leaves.
      await tester.tap(find.byKey(const ValueKey('build_meal.back_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('build_meal.discard')));
      await tester.pumpAndSettle();
      expect(find.text('Build a Meal'), findsNothing);
      expect(find.text('open builder'), findsOneWidget);
    });

    testWidgets('the system back (swipe) is guarded the same way', (
      tester,
    ) async {
      await openBuilder(tester);
      container
          .read(draftMealControllerProvider(_logDate).notifier)
          .addComponent(const MealComponent(name: 'Banana', portion: '1'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(content['build_meal.discard_title']!), findsOneWidget);
    });

    testWidgets('an empty draft leaves without asking', (tester) async {
      await openBuilder(tester);

      await tester.tap(find.byKey(const ValueKey('build_meal.back_button')));
      await tester.pumpAndSettle();

      expect(find.text(content['build_meal.discard_title']!), findsNothing);
      expect(find.text('Build a Meal'), findsNothing);
      expect(find.text('open builder'), findsOneWidget);
    });

    testWidgets('the total reads a dash for a macro no item carries', (
      tester,
    ) async {
      await openBuilder(tester);
      container
          .read(draftMealControllerProvider(_logDate).notifier)
          .addComponent(
            const MealComponent(name: 'Mystery bar', portion: '1 bar'),
          );
      await tester.pumpAndSettle();

      final totals = tester.widget<Text>(
        find.byKey(const ValueKey('build_meal.totals')),
      );
      expect(totals.data, '— kcal  ·  C —g  P —g  F —g');
      expect(totals.data, isNot(contains('0 kcal')));
    });
  });

  group('113-004: the Timeline meal card', () {
    testWidgets('shows a dash, not 0, for a null-macro log', (tester) async {
      const item = MealItemData(
        id: 'm1',
        name: 'Soup',
        kcal: null,
        carbsG: null,
        proteinG: null,
        fatG: null,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MealCard(item: item, expanded: false, showMacros: true),
          ),
        ),
      );
      final rich = tester.widget<Text>(find.textContaining('kcal'));
      final line = rich.textSpan!.toPlainText();
      expect(line, '— kcal · —C · —P · —F');
      expect(line, isNot(contains('0')));
    });

    testWidgets('a known number still reads as before', (tester) async {
      const item = MealItemData(
        id: 'm1',
        name: 'Bagel',
        kcal: 312,
        carbsG: 41.4,
        proteinG: 18,
        fatG: 7,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MealCard(item: item, expanded: false, showMacros: true),
          ),
        ),
      );
      final rich = tester.widget<Text>(find.textContaining('kcal'));
      expect(rich.textSpan!.toPlainText(), '312 kcal · 41C · 18P · 7F');
    });

    testWidgets('the expanded ⋯ offers Save as favorite when wired', (
      tester,
    ) async {
      const item = MealItemData(
        id: 'm1',
        name: 'Bagel',
        kcal: 312,
        carbsG: 41,
        proteinG: 18,
        fatG: 7,
      );
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MealCard(
              item: item,
              expanded: true,
              showMacros: true,
              onSaveAsFavorite: () => saves++,
              saveAsFavoriteLabel: 'Save as favorite',
            ),
          ),
        ),
      );
      expect(find.text('Edit food'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      await tester.tap(find.text('Save as favorite'));
      expect(saves, 1);
    });
  });

  group('113-005: Manual tab, Save with an empty name', () {
    testWidgets('brings the name field and its error into view, focused', (
      tester,
    ) async {
      // A short phone: Save sits well below the name field.
      tester.view.physicalSize = const Size(393, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockAppExternalDeps(),
            appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ManualLogForm(
                logDate: _logDate,
                onLogged: () {},
                onLogError: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final save = find.byKey(const ValueKey('manual_log.save_button'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      // The name field has scrolled off the top.
      final nameField = find.byKey(const ValueKey('manual_log.name_field'));
      expect(tester.getRect(nameField).bottom, lessThan(0));

      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
      final error = tester.getRect(find.text('Name is required'));
      expect(error.top, greaterThanOrEqualTo(0));
      expect(error.bottom, lessThanOrEqualTo(500));
      final editable = tester.widget<EditableText>(
        find.descendant(of: nameField, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);
    });
  });
}

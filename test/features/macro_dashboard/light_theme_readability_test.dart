// Finding 119-003: in the Light theme the Timeline drew meal names, kcal
// figures and workout labels in cream on the cream Scaffold, and the workout
// cards kept their dark plum fill. The surface's ground/ink pair now comes
// from the theme (MeSurfaceTokens): light inverts it, dark keeps the
// ratified blackberry/cream, and a bare MaterialApp falls back to dark so
// the goldens hold.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/me_tokens.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/meal_card.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/workout_card.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_theme.dart';

const _meal = MealItemData(
  id: 'm1',
  name: 'Greek yogurt + honey',
  kcal: 312,
  carbsG: 41,
  proteinG: 18,
  fatG: 7,
);

WorkoutCardData _swim(WorkoutCardState state) => WorkoutCardData(
  activityId: 'w1',
  name: 'Swim',
  timeLabel: '8:00 AM',
  metaLabel: '2,000 yd · 40 min',
  kcal: 229,
  state: state,
  sport: 'swimming',
);

Widget _host(ThemeData? theme, Widget child) => MaterialApp(
  theme: theme,
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    body: Center(child: SizedBox(width: 380, child: child)),
  ),
);

Color _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

/// The kcal figure is the first span of the meal card's rich macro line.
Color _mealKcalColor(WidgetTester tester) {
  final rich = tester.widget<Text>(find.textContaining('kcal'));
  final span = (rich.textSpan as TextSpan).children!.first as TextSpan;
  return span.style!.color!;
}

/// Dimmed labels are the ink at reduced alpha; compare the opaque base.
Color _opaque(Color c) => c.withValues(alpha: 1);

void main() {
  group('MeTokens.of', () {
    testWidgets('light theme inverts ground and ink', (tester) async {
      late MeSurfaceTokens me;
      await tester.pumpWidget(
        _host(
          AppTheme.lightTheme,
          Builder(
            builder: (context) {
              me = MeTokens.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(me.ground, AppColors.cream);
      expect(me.ink, AppColors.blackberry);
    });

    testWidgets('dark theme keeps the ratified blackberry / cream', (
      tester,
    ) async {
      late MeSurfaceTokens me;
      await tester.pumpWidget(
        _host(
          AppTheme.darkTheme,
          Builder(
            builder: (context) {
              me = MeTokens.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(me.ground, const Color.fromRGBO(56, 22, 51, 1));
      expect(me.ink, const Color.fromRGBO(248, 246, 235, 1));
    });

    testWidgets('a bare MaterialApp falls back to the dark values', (
      tester,
    ) async {
      late MeSurfaceTokens me;
      await tester.pumpWidget(
        _host(
          null,
          Builder(
            builder: (context) {
              me = MeTokens.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(me, same(MeSurfaceTokens.dark));
    });
  });

  group('MealCard', () {
    testWidgets('light: name and kcal are blackberry on the cream ground', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AppTheme.lightTheme,
          const MealCard(item: _meal, expanded: false, showMacros: true),
        ),
      );
      final ground = Theme.of(
        tester.element(find.byType(MealCard)),
      ).scaffoldBackgroundColor;
      expect(ground, AppColors.cream);

      final name = _textColor(tester, _meal.name);
      expect(name, AppColors.blackberry);
      expect(name, isNot(ground));

      final kcal = _mealKcalColor(tester);
      expect(kcal, AppColors.blackberry);
      expect(kcal, isNot(ground));
    });

    testWidgets('dark: name and kcal stay cream', (tester) async {
      await tester.pumpWidget(
        _host(
          AppTheme.darkTheme,
          const MealCard(item: _meal, expanded: false, showMacros: true),
        ),
      );
      expect(_textColor(tester, _meal.name), AppColors.cream);
      expect(_mealKcalColor(tester), AppColors.cream);
    });
  });

  group('WorkoutCard', () {
    testWidgets('light: name and meta read as blackberry, fill is not plum', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AppTheme.lightTheme,
          WorkoutCard(data: _swim(WorkoutCardState.planned)),
        ),
      );
      expect(_textColor(tester, 'Swim'), AppColors.blackberry);
      expect(
        _opaque(_textColor(tester, '2,000 yd · 40 min')),
        AppColors.blackberry,
      );

      final card = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final fill = (card.decoration as BoxDecoration).color;
      expect(fill, MeSurfaceTokens.light.workoutPlannedFill);
      expect(fill, isNot(MeSurfaceTokens.dark.workoutPlannedFill));
    });

    testWidgets('dark: name and meta stay cream on the plum fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AppTheme.darkTheme,
          WorkoutCard(data: _swim(WorkoutCardState.planned)),
        ),
      );
      expect(_textColor(tester, 'Swim'), AppColors.cream);
      expect(_opaque(_textColor(tester, '2,000 yd · 40 min')), AppColors.cream);

      final card = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(
        (card.decoration as BoxDecoration).color,
        const Color.fromRGBO(55, 31, 57, 1),
      );
    });
  });
}

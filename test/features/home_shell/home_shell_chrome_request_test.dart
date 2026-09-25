// Ticket 131 (Finding 88-016, mp-235): a confirm lands on Food > Shopping
// "with the tab bar showing". The device run found the bar collapsed to the
// small bubble a scroll elsewhere had left. A navigation that names a tab
// (every `/main?tab=…` go carries a fresh `extra`) brings it back expanded.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:mealvana_endurance/features/home_shell/presentation/home_shell_chrome.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/food_screen.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/kyle_tab_bar.dart';

import '../../helpers/widget_test_harness.dart';

const _collapsed = ValueKey('kyle_tab_bar.collapsed_button');

final _destinations = [
  KyleTabBarDestination(
    id: 'timeline',
    icon: FontAwesomeIcons.solidHouse.data,
    label: 'Timeline',
  ),
  KyleTabBarDestination(
    id: 'food',
    icon: FontAwesomeIcons.bowlFood.data,
    label: 'Food',
  ),
  KyleTabBarDestination(
    id: 'learn',
    icon: FontAwesomeIcons.graduationCap.data,
    label: 'Learn',
  ),
];

void main() {
  testWidgets('a new navigation request brings a collapsed bar back expanded', (
    tester,
  ) async {
    final request = ValueNotifier<Object?>(null);
    addTearDown(request.dispose);

    await pumpSeeded(
      tester,
      Scaffold(
        body: ValueListenableBuilder<Object?>(
          valueListenable: request,
          builder: (_, r, _) => HomeShellChrome(
            destinations: _destinations,
            activeTabId: 'food',
            onSelectTab: (_) {},
            showDateHeader: false,
            request: r,
            body: ListView(
              key: const ValueKey('test.body'),
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 60, child: Text('row $i')),
              ],
            ),
          ),
        ),
      ),
    );

    // A scroll past the collapse threshold leaves the bubble.
    await tester.drag(
      find.byKey(const ValueKey('test.body')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_collapsed), findsOneWidget);

    // A confirm asks for Food > Shopping: the bar comes back whole.
    request.value = foodTabRequest();
    await tester.pumpAndSettle();
    expect(find.byKey(_collapsed), findsNothing);
    expect(find.text('Food'), findsWidgets);
  });
}

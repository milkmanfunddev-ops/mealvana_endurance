import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';

void main() {
  // Xuan's 2026-10-05 patch: a visible back control never dead-ends. With
  // nothing to pop (a stackless deep-link arrival) it goes home through the
  // app's GoRouter, so the test runs under one, the way the app does.
  testWidgets('goes home when the navigator cannot pop', (tester) async {
    final router = GoRouter(
      initialLocation: '/stranded',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Center(child: Text('Home'))),
        ),
        GoRoute(
          path: '/stranded',
          builder: (_, _) =>
              const Scaffold(body: Center(child: CustomAppBarBackButton())),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Home'), findsNothing);

    await tester.tap(find.byType(CustomAppBarBackButton));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(CustomAppBarBackButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pops when navigator can pop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          body: Center(child: CustomAppBarBackButton()),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open child'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomAppBarBackButton), findsOneWidget);

    await tester.tap(find.byType(CustomAppBarBackButton));
    await tester.pumpAndSettle();

    expect(find.text('Open child'), findsOneWidget);
  });
  // Ticket 83 (Finding 67-001): iOS read the arrow as "Back\nBack", the
  // Semantics label plus the Tooltip's message. The control has one name.
  testWidgets('is one button named Back, read once', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CustomAppBarBackButton())),
      ),
    );

    final node = tester.getSemantics(
      find.descendant(
        of: find.byType(CustomAppBarBackButton),
        matching: find.byType(Icon),
      ),
    );
    expect(
      node,
      isSemantics(label: 'Back', isButton: true, hasTapAction: true),
    );
    final data = node.getSemanticsData();
    expect(data.label, 'Back');
    // The tooltip is the part iOS appended as the second "Back".
    expect(data.tooltip, isEmpty);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    // The long-press tooltip itself still exists.
    expect(find.byTooltip('Back'), findsOneWidget);
    handle.dispose();
  });
}

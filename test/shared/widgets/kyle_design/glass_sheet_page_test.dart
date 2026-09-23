/// glass-sheet spec (PROPOSED v1, paywall ticket 17 — mp-493 §5, §6):
///   GS-1  rises from the bottom edge over the glass-sheet scrim
///   GS-2  full height below the status bar; the page under it stays
///   GS-3  closes by the content's pop, a scrim tap or a drag down, back to
///         the page under it
///   GS-4  dark-first: the content renders in the dark theme
///   GS-5  Reduce Motion: there on the next frame, no rise
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/shared/widgets/kyle_design/materials/glass.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/materials/glass_sheet.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_materials.dart';

const _content = ValueKey('sheet.content');
const _close = ValueKey('sheet.close');
const _size = Size(390, 844);
const _topInset = 47.0;

void main() {
  Future<GoRouter> pump(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/page',
      routes: [
        GoRoute(
          path: '/page',
          builder: (_, _) => const Scaffold(body: Center(child: Text('page'))),
        ),
        GoRoute(
          path: '/sheet',
          pageBuilder: (_, state) => GlassSheetPage<void>(
            key: state.pageKey,
            child: Builder(
              builder: (context) => Material(
                type: MaterialType.transparency,
                child: Column(
                  key: _content,
                  children: [
                    Text(
                      Theme.of(context).brightness.name,
                      key: const ValueKey('sheet.brightness'),
                    ),
                    TextButton(
                      key: _close,
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(brightness: Brightness.light),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: _topInset),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  double contentTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(GlassSheetSurface)).dy;

  testWidgets('GS-1, GS-2: rises over the scrim, full height below the '
      'status bar, the page still under it', (tester) async {
    final router = await pump(tester);

    router.push('/sheet');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Mid-rise: below where it comes to rest.
    expect(contentTop(tester), greaterThan(_topInset));

    await tester.pumpAndSettle();
    expect(contentTop(tester), _topInset);
    expect(
      tester.getBottomLeft(find.byType(GlassSheetSurface)).dy,
      _size.height,
    );
    expect(find.byKey(_content), findsOneWidget);
    expect(find.text('page'), findsOneWidget);

    final scrims = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
    expect(scrims.map((b) => b.color), contains(AppMaterials.sheetScrim));
  });

  testWidgets('GS-4: the content is dark in a light app', (tester) async {
    final router = await pump(tester);
    router.push('/sheet');
    await tester.pumpAndSettle();
    expect(find.text('dark'), findsOneWidget);
  });

  testWidgets('GS-5: Reduce Motion puts it at rest on the next frame', (
    tester,
  ) async {
    final router = await pump(tester, reduceMotion: true);
    router.push('/sheet');
    await tester.pump();
    await tester.pump();
    expect(contentTop(tester), _topInset);
  });

  group('GS-3: every close returns to the page under it', () {
    testWidgets('the content pops', (tester) async {
      final router = await pump(tester);
      router.push('/sheet');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_close));
      await tester.pumpAndSettle();
      expect(find.byKey(_content), findsNothing);
      expect(find.text('page'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/page');
    });

    testWidgets('a tap on the scrim', (tester) async {
      final router = await pump(tester);
      router.push('/sheet');
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(195, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(_content), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/page');
    });

    testWidgets('a drag down', (tester) async {
      final router = await pump(tester);
      router.push('/sheet');
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(const ValueKey('sheet.brightness')),
        const Offset(0, 500),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_content), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/page');
    });
  });
}

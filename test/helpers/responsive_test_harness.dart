// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/src/internals.dart' show Override;

const Size smallPhoneSize = Size(320, 568);
const Size standardPhoneSize = Size(390, 844);
const Size tabletPortraitSize = Size(834, 1194);
const Size desktopSize = Size(1440, 900);

Future<void> pumpResponsiveScreen(
  WidgetTester tester, {
  required Widget screen,
  required Size surfaceSize,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void expectNoRenderOverflow(WidgetTester tester) {
  dynamic exception;
  final exceptions = <String>[];
  while ((exception = tester.takeException()) != null) {
    exceptions.add(exception.toString());
  }

  final overflow = exceptions.where(
    (e) =>
        e.contains('A RenderFlex overflowed') ||
        e.contains('was given an infinite size during layout'),
  );

  expect(
    overflow,
    isEmpty,
    reason: 'Responsive overflow exceptions found: ${overflow.join('\n\n')}',
  );
}

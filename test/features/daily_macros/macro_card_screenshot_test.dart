// Screenshot harness for the redesigned Daily Total card (planned vs. eaten
// comparison). Loads the real app fonts and writes PNGs via golden files:
//
//   flutter test test/features/daily_macros/macro_card_screenshot_test.dart \
//     --update-goldens
//
// Output: test/features/daily_macros/goldens/daily_total_card_{light,dark}.png
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/widgets/daily_summary_card.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
  }
  await loader.load();
}

DailyMacroTargets _targets() {
  final now = DateTime(2026, 6, 13);
  return DailyMacroTargets(
    id: 'test',
    userId: 'u1',
    targetDate: now,
    carbG: 305,
    protG: 107,
    fatG: 98,
    tdee: 2530,
    rmr: 1600,
    sessionKcal: 400,
    neatKcal: 530,
    mode: 'standard',
    algorithmVersion: 'v1',
    createdAt: now,
    updatedAt: now,
  );
}

Widget _harness({required bool dark}) {
  return ProviderScope(
    overrides: [
      consumedTotalsForDateProvider.overrideWith(
        (ref, date) => Stream.value(const ConsumedTotals(
          calories: 1480,
          carbsG: 188,
          proteinG: 71,
          fatG: 52,
          sodiumMg: 1200,
        )),
      ),
      currentUserProvider.overrideWith((ref) async => null),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.orange,
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
      ),
      home: Scaffold(
        backgroundColor: dark ? AppColors.blackberry : AppColors.cream,
        body: Center(
          child: SizedBox(
            width: 380,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                child: DailySummaryCard(macros: _targets()),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Golden comparisons are font/AA/platform-sensitive, so this suite is opt-in:
// it stays skipped in normal `flutter test` / CI runs and only executes when
// you're deliberately (re)capturing the card art:
//
//   CAPTURE_SCREENSHOTS=1 flutter test \
//     test/features/daily_macros/macro_card_screenshot_test.dart --update-goldens
final bool _captureMode = Platform.environment['CAPTURE_SCREENSHOTS'] == '1';

void main() {
  setUpAll(() async {
    await _loadFont('Apercu', [
      'assets/fonts/Apercu/Apercu Regular.otf',
      'assets/fonts/Apercu/Apercu-Medium.otf',
      'assets/fonts/Apercu/Apercu-Bold.otf',
      'assets/fonts/Apercu/Apercu-Light.otf',
    ]);
    await _loadFont('Sansita', [
      'assets/fonts/Sansita/Sansita-Regular.otf',
      'assets/fonts/Sansita/Sansita-Medium.otf',
      'assets/fonts/Sansita/Sansita-Bold.ttf',
    ]);
  });

  testWidgets('daily total card — light', (tester) async {
    tester.view.physicalSize = const Size(1260, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(dark: false));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DailySummaryCard),
      matchesGoldenFile('goldens/daily_total_card_light.png'),
    );
  }, skip: !_captureMode);

  testWidgets('daily total card — dark', (tester) async {
    tester.view.physicalSize = const Size(1260, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(dark: true));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DailySummaryCard),
      matchesGoldenFile('goldens/daily_total_card_dark.png'),
    );
  }, skip: !_captureMode);
}

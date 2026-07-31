// Opt-in screenshot harness for the meal log rows (brand-aligned slot colors).
// Skipped unless CAPTURE_SCREENSHOTS=1; run with:
//   CAPTURE_SCREENSHOTS=1 flutter test \
//     test/features/meal_logging/meal_rows_screenshot_test.dart --update-goldens
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/meal_log_row.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

final bool _captureMode = Platform.environment['CAPTURE_SCREENSHOTS'] == '1';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(
      Future.value(
        ByteData.view(Uint8List.fromList(File(path).readAsBytesSync()).buffer),
      ),
    );
  }
  await loader.load();
}

MealLog _log(
  MealSlot slot,
  String name,
  int kcal,
  double c,
  double p,
  double f,
) {
  final now = DateTime(2026, 6, 13);
  return MealLog(
    id: '$slot',
    userId: 'u1',
    logDate: '2026-06-13',
    slot: slot,
    name: name,
    source: MealLogSource.manual,
    components: const [],
    calories: kcal,
    carbsG: c,
    proteinG: p,
    fatG: f,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(() async {
    await _loadFont('Apercu', [
      'assets/fonts/Apercu/Apercu Regular.otf',
      'assets/fonts/Apercu/Apercu-Medium.otf',
      'assets/fonts/Apercu/Apercu-Bold.otf',
    ]);
    await _loadFont('Sansita', [
      'assets/fonts/Sansita/Sansita-Regular.otf',
      'assets/fonts/Sansita/Sansita-Bold.ttf',
    ]);
  });

  testWidgets('meal log rows — slot colors', (tester) async {
    tester.view.physicalSize = const Size(1140, 1200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, fontFamily: 'Apercu'),
          home: Scaffold(
            backgroundColor: AppColors.cream,
            body: Center(
              child: SizedBox(
                width: 360,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final r in [
                        _log(
                          MealSlot.breakfast,
                          'Oatmeal & berries',
                          420,
                          68,
                          14,
                          9,
                        ),
                        _log(
                          MealSlot.lunch,
                          'Chicken rice bowl',
                          640,
                          72,
                          45,
                          18,
                        ),
                        _log(
                          MealSlot.dinner,
                          'Salmon & sweet potato',
                          580,
                          48,
                          42,
                          22,
                        ),
                        _log(MealSlot.snack, 'Greek yogurt', 180, 12, 18, 4),
                      ])
                        MealLogRow(log: r, onDelete: () {}, onEdit: () {}),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/meal_log_rows.png'),
    );
  }, skip: !_captureMode);
}

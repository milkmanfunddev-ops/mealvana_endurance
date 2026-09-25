// Ticket 97 (testing-wave; Finding 24-007): Review & Log shows a thumbnail
// of the analyzed photo for a photo log, so the athlete sees which picture
// the numbers came from before "Log this meal". A describe log, which has
// no photo, shows none.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_analysis_result.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/meal_review_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/meal_photo_thumbnail.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

const _photoPath = 'u1/2026-09-24/lunch.jpg';

/// The `describe-meal` / photo answer (`MealAnalysisSchema`).
Map<String, dynamic> _analysis() => {
  'name': 'Eggs on toast',
  'suggested_slot': 'lunch',
  'confidence': 'medium',
  'items': [
    {
      'name': 'Scrambled eggs',
      'portion': '2 large',
      'calories': 180,
      'carb_g': 1,
      'protein_g': 12,
      'fat_g': 14,
      'sodium_mg': 190,
    },
  ],
  'totals': {
    'calories': 180,
    'carb_g': 1,
    'protein_g': 12,
    'fat_g': 14,
    'sodium_mg': 190,
  },
  'notes': null,
};

void main() {
  final signedFor = <String?>[];

  Future<void> pumpReview(
    WidgetTester tester, {
    required String source,
    required String? photoPath,
  }) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    signedFor.clear();

    final result = MealAnalysisResult.fromJson(_analysis());
    final router = GoRouter(
      initialLocation: '/main',
      routes: [
        GoRoute(
          path: '/main',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(
                '/meal-log/review',
                extra: {
                  'result': result,
                  'source': source,
                  'logDate': '2026-09-24',
                  'photoPath': photoPath,
                },
              ),
              child: const Text('open review'),
            ),
          ),
        ),
        GoRoute(
          path: '/meal-log/review',
          builder: (_, _) => const MealReviewScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          inMemoryDatabaseOverride(),
          // The bucket's signed URL, recorded: the screen asks for the
          // photo it was handed and nothing else.
          mealPhotoSignedUrlProvider.overrideWith((ref, photoPath) async {
            signedFor.add(photoPath);
            return 'https://photos.test/$photoPath';
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Review & Log'), findsOneWidget);
  }

  testWidgets('a photo log shows a thumbnail of the analyzed photo', (
    tester,
  ) async {
    await pumpReview(tester, source: 'photo', photoPath: _photoPath);

    final thumb = find.byKey(const ValueKey('meal_logging.review_photo'));
    expect(thumb, findsOneWidget);
    expect(tester.widget<MealPhotoThumbnail>(thumb).photoPath, _photoPath);
    expect(signedFor, [_photoPath]);
    // Shown as a picture, from the bucket's signed URL.
    final image = tester.widget<Image>(
      find.descendant(of: thumb, matching: find.byType(Image)),
    );
    expect(
      (image.image as NetworkImage).url,
      'https://photos.test/$_photoPath',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a described meal, with no photo, shows none', (tester) async {
    await pumpReview(tester, source: 'describe', photoPath: null);

    expect(
      find.byKey(const ValueKey('meal_logging.review_photo')),
      findsNothing,
    );
    expect(find.byType(MealPhotoThumbnail), findsNothing);
    expect(signedFor, isEmpty);
  });
}

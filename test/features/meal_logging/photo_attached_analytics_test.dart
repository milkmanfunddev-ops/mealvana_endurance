// Ticket 60 (testing-wave develop-2026-10), 49-006: `meal_ai_photo_attached`
// fires only when a photo came back. A cancelled picker (null) or one that
// throws (no camera, permission denied) sends nothing.
//
// Seam: `imagePickerProvider` answered by a mocktail [ImagePicker]; analytics
// recorded by [RecordingAnalyticsTracker]. Harness as
// `describe_not_food_test.dart`: LogMealScreen → Describe.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/image_picker_provider.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart';

const _event = 'meal_ai_photo_attached';

class _MockImagePicker extends Mock implements ImagePicker {}

void _answer(
  _MockImagePicker picker,
  ImageSource source,
  Answer<Future<XFile?>> answer,
) {
  when(
    () => picker.pickImage(
      source: source,
      imageQuality: any(named: 'imageQuality'),
      maxWidth: any(named: 'maxWidth'),
    ),
  ).thenAnswer(answer);
}

Future<RecordingAnalyticsTracker> _openDescribe(
  WidgetTester tester,
  ImagePicker picker,
) async {
  final analytics = RecordingAnalyticsTracker();
  await smokeScreen(
    tester,
    const LogMealScreen(logDate: '2026-10-08', source: 'test'),
    settle: false,
    withAppDeps: false,
    overrides: [
      appConfigProvider.overrideWithValue(AppConfig.forTesting()),
      mockSharedPreferences(),
      appExternalDepsProvider.overrideWithValue(
        AppExternalDeps(
          analytics: analytics,
          supabaseClient: fakeSupabaseClient(),
          sharedPreferences: MockSharedPreferences(),
        ),
      ),
      contentServiceProvider.overrideWith(testContentService),
      imagePickerProvider.overrideWithValue(picker),
    ],
  );
  addTearDown(tester.view.reset);
  await tester.tap(find.text('Describe'));
  await tester.pump();
  return analytics;
}

void main() {
  setUpAll(() {
    registerFallbackValue(ImageSource.camera);
  });

  testWidgets('Camera that returns no photo sends no event', (tester) async {
    final picker = _MockImagePicker();
    _answer(picker, ImageSource.camera, (_) async => null);
    final analytics = await _openDescribe(tester, picker);

    await tester.tap(find.text('Camera'));
    await tester.pump();

    expect(analytics.findEvents(_event), isEmpty);
    expect(find.text('Photo attached'), findsNothing);
  });

  testWidgets('Gallery that throws sends no event and shows the error', (
    tester,
  ) async {
    final picker = _MockImagePicker();
    _answer(
      picker,
      ImageSource.gallery,
      (_) async => throw PlatformException(code: 'photo_access_denied'),
    );
    final analytics = await _openDescribe(tester, picker);

    await tester.tap(find.text('Gallery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(analytics.findEvents(_event), isEmpty);
    expect(
      find.text('Could not access the camera or gallery.'),
      findsOneWidget,
    );
    // Let the snackbar's display timer run out before the test ends.
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a picked photo sends exactly one event and shows the card', (
    tester,
  ) async {
    final picker = _MockImagePicker();
    _answer(
      picker,
      ImageSource.gallery,
      (_) async => XFile('/tmp/ticket60-meal.jpg'),
    );
    final analytics = await _openDescribe(tester, picker);

    await tester.tap(find.text('Gallery'));
    await tester.pump();

    final events = analytics.findEvents(_event);
    expect(events, hasLength(1));
    expect(events.single.properties, {'method': 'photo_gallery'});
    expect(find.text('Photo attached'), findsOneWidget);
  });
}

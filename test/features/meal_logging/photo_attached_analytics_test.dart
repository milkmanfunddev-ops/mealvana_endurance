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
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/image_picker_provider.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';
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
  ImagePicker picker, {
  Report? report,
}) async {
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
      if (report != null) reportProvider.overrideWithValue(report),
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

  // Ticket 81, 68-003: camera access off is the athlete's own setting. A
  // note and one expected_failure, a line that says where to turn it on, no
  // degraded and no error_reported. The PlatformException is the one the
  // iOS picker threw in run 68 (`runs/68/console-redacted.log:482`).
  testWidgets('Camera with access off notes it and says where to turn it on', (
    tester,
  ) async {
    final picker = _MockImagePicker();
    _answer(
      picker,
      ImageSource.camera,
      (_) async => throw PlatformException(
        code: 'camera_access_denied',
        message: 'The user did not allow camera access.',
      ),
    );
    final report = RecordingReport();
    final analytics = await _openDescribe(tester, picker, report: report);

    await tester.tap(find.text('Camera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final line =
        loadDefaultContent()[ContentKeys.mealLogDescribeCameraAccessOff]!;
    expect(line, 'Camera access is off. Turn it on for Mealvana in Settings.');
    expect(find.text(line), findsOneWidget);
    expect(find.text('Could not access the camera or gallery.'), findsNothing);

    // The harness's food sections fault on the fake Supabase client
    // (area nutrition_plan); only this screen's area is asserted.
    bool ofScreen(RecordedReport r) => r.area == 'meal_logging';
    expect(report.degradeds.where(ofScreen), isEmpty);
    expect(report.faults.where(ofScreen), isEmpty);
    final notes = report.notes.where((n) => n.area == 'meal_logging');
    expect(notes, hasLength(1));
    expect(notes.single.data, {
      'expected_failure': 'camera_permission_denied',
      'method': 'photo_camera',
    });

    final counted = analytics.findEvents(expectedFailureEvent);
    expect(counted, hasLength(1));
    expect(counted.single.properties, {
      'area': 'meal_logging',
      'reason': 'camera_permission_denied',
    });
    expect(analytics.findEvents(errorReportedEvent), isEmpty);
    expect(analytics.findEvents(_event), isEmpty);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('Gallery with access off keeps the degraded and the old line', (
    tester,
  ) async {
    final picker = _MockImagePicker();
    _answer(
      picker,
      ImageSource.gallery,
      (_) async => throw PlatformException(code: 'photo_access_denied'),
    );
    final report = RecordingReport();
    final analytics = await _openDescribe(tester, picker, report: report);

    await tester.tap(find.text('Gallery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Could not access the camera or gallery.'),
      findsOneWidget,
    );
    final degraded = report.degradeds.where((r) => r.area == 'meal_logging');
    expect(degraded, hasLength(1));
    expect(degraded.single.message, 'log meal: image picker failed');
    expect(analytics.findEvents(expectedFailureEvent), isEmpty);
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

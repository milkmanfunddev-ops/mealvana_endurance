// Ticket 34 (Finding 22-001): a notification tapped while the app is
// backgrounded (not killed) is routed on the next resume.
//
// AppDelegate writes the tapped payload into UserDefaults natively
// (`flutter.ios_un_response_payload`, or `flutter.ios_legacy_resume_payload`
// on the legacy door) while Dart is suspended. The test does the same: the
// app "launches" with empty prefs, then the payload lands in the platform
// store behind the Dart cache, the way a native write does.
//
// Drives `collectResumeTaps`, the function the root widget's resume branch
// awaits. Pumping RootAppWidget itself would need the router, startup,
// Wiredash and the nudge coordinators; the resume branch adds nothing to
// the collection but the `app resumed` line.

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/launch_trail.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';
import 'package:mealvana_endurance/shared/widgets/root_app_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../helpers/fakes/recording_report.dart';

/// The payload `showActivityUploadedNotification` puts on a local
/// notification: type, activity id, copy variant.
const _activityId = '3a7e3fdb-754c-812c-85f2-eb86d213c863';
const _payload = 'activity:$_activityId:accuracy_hook_v2';

/// A fresh launch: empty native keys, the tape begun, the cache filled.
Future<void> _launch([Map<String, Object> native = const {}]) async {
  SharedPreferences.setMockInitialValues(native);
  await LaunchTrail.begin();
}

/// What AppDelegate does while the app is backgrounded: a write to
/// UserDefaults that the Dart prefs cache does not see.
Future<void> _nativeWrite(String key, String value) =>
    SharedPreferencesStorePlatform.instance.setValue(
      'String',
      'flutter.$key',
      value,
    );

Future<Map<String, Object>> _store() =>
    SharedPreferencesStorePlatform.instance.getAll();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<({String id, String? type})> routed;
  late RecordingReport report;

  setUp(() {
    NotificationService.debugReset();
    LaunchTrail.debugReset();
    routed = [];
    report = RecordingReport();
    NotificationService.debugSetReport(report);
    NotificationService.setNavigationHandler(
      (id, type) => routed.add((id: id, type: type)),
    );
  });

  tearDown(() {
    NotificationService.debugReset();
    LaunchTrail.debugReset();
  });

  test('a backgrounded tap routes once on resume and is consumed', () async {
    await _launch();
    await _nativeWrite('ios_un_response_payload', _payload);

    await collectResumeTaps(report);

    expect(routed, [(id: _activityId, type: 'activity')]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ios_un_response_payload'), isNull);
    expect(
      (await _store()).containsKey('flutter.ios_un_response_payload'),
      isFalse,
    );
    final tape = LaunchTrail.text;
    expect(
      tape,
      contains('ios_un_response_payload payload=$_payload (consumed)'),
    );
    // The native line is taped before the consume says what it did.
    expect(
      tape.indexOf('native ios_un_response_payload=$_payload'),
      lessThan(tape.indexOf('(consumed)')),
    );
    expect(
      tape,
      contains('dispatch id=$_activityId type=activity handlerSet=true'),
    );
    expect(report.faults, isEmpty);

    // A second resume with nothing new routes nothing.
    await collectResumeTaps(report);
    expect(routed, hasLength(1));
  });

  test('the legacy resume key is read when the UN key is absent', () async {
    await _launch();
    await _nativeWrite('ios_legacy_resume_payload', 'reminder:act_9');

    await collectResumeTaps(report);

    expect(routed, [(id: 'act_9', type: 'reminder')]);
    expect(
      (await _store()).containsKey('flutter.ios_legacy_resume_payload'),
      isFalse,
    );
    expect(
      LaunchTrail.text,
      contains('ios_legacy_resume_payload payload=reminder:act_9 (consumed)'),
    );
  });

  test('two resumes at once route the tap once', () async {
    await _launch();
    await _nativeWrite('ios_un_response_payload', _payload);

    await Future.wait([collectResumeTaps(report), collectResumeTaps(report)]);

    expect(routed, hasLength(1));
    expect(
      LaunchTrail.text,
      contains('resume tap collection joined: one already running'),
    );
    expect(report.calls.where((c) => c.severity == 'breadcrumb'), isNotEmpty);
  });

  test('a resume leaves the launch key to the launch path', () async {
    // The launch path reads `ios_legacy_launch_payload`; a resume must not
    // take it, or one tap could route on both paths.
    await _launch({'ios_legacy_launch_payload': 'reminder:act_launch'});

    await collectResumeTaps(report);

    expect(routed, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ios_legacy_launch_payload'), 'reminder:act_launch');
  });

  test('with no handler yet the tap is held as pending', () async {
    NotificationService.setNavigationHandler(null);
    await _launch();
    await _nativeWrite('ios_un_response_payload', _payload);

    await collectResumeTaps(report);

    expect(NotificationService.getPendingNavigationActivityId(), _activityId);
    expect(NotificationService.getPendingNavigationType(), 'activity');
  });
}

// Ticket 28 (Finding 08-007): the dev launch-trail dialog's guard counts only
// a real notification. Fed the tape lines the app writes.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/launch_trail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What an ordinary launch and resume tape, from notification_service.dart
/// and root_app_widget.dart.
void _ordinaryLaunch() {
  LaunchTrail.add('plugin.initialize() starting (handler not yet attached)');
  LaunchTrail.add('plugin.initialize() done (handler attached)');
  LaunchTrail.add('launchDetails didNotificationLaunchApp=false payload=null');
  LaunchTrail.add(
    'onesignal started; permission ask + heal wait for an athlete id',
  );
  LaunchTrail.add('app resumed');
}

Future<void> _launchWith(Map<String, Object> native) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues(native);
  await LaunchTrail.begin();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(LaunchTrail.debugReset);

  test('an ordinary launch and resume is not notification evidence', () async {
    await _launchWith({'ios_launch_options': '(none)'});
    _ordinaryLaunch();
    expect(LaunchTrail.hasNotificationEvidence, isFalse);
  });

  test('an empty tap payload is not evidence', () async {
    await _launchWith({});
    LaunchTrail.add(
      'onDidReceiveNotificationResponse payload=null actionId=null '
      'type=NotificationResponseType.selectedNotification',
    );
    LaunchTrail.add('onDidReceiveNotificationResponse payload= actionId=null');
    expect(LaunchTrail.hasNotificationEvidence, isFalse);
  });

  test('stale native values seeded at launch are not evidence', () async {
    // ios_un_willpresent is never removed, and the resume payload keys stay
    // until something consumes them: a later launch re-tapes them.
    await _launchWith({
      'ios_un_willpresent': '#3 payload=reminder:act_1 at=2026-10-05T19:00:00Z',
      'ios_un_response_payload': 'reminder:act_1',
      'ios_legacy_resume_payload': 'reminder:act_1',
    });
    _ordinaryLaunch();
    expect(LaunchTrail.text, contains('native ios_un_willpresent='));
    expect(LaunchTrail.hasNotificationEvidence, isFalse);
  });

  test('a tap payload is evidence', () async {
    await _launchWith({});
    _ordinaryLaunch();
    LaunchTrail.add(
      'onDidReceiveNotificationResponse payload=act_123 actionId=null '
      'type=NotificationResponseType.selectedNotification',
    );
    expect(LaunchTrail.hasNotificationEvidence, isTrue);
  });

  test('a consumed legacy launch payload is evidence', () async {
    await _launchWith({});
    _ordinaryLaunch();
    LaunchTrail.add('legacy_launch payload=reminder:act_123 (consumed)');
    expect(LaunchTrail.hasNotificationEvidence, isTrue);
  });

  test('routing a tap is evidence', () async {
    await _launchWith({});
    _ordinaryLaunch();
    LaunchTrail.add('routing id=act_123 type=reminder');
    expect(LaunchTrail.hasNotificationEvidence, isTrue);
  });

  test('a willpresent that pullNative finds new is evidence', () async {
    await _launchWith({'ios_un_willpresent': '#3 NOT-OURS (passed to chain)'});
    _ordinaryLaunch();
    LaunchTrail.pullNative();
    expect(LaunchTrail.hasNotificationEvidence, isFalse);

    // AppDelegate writes a fresh foreground delivery during the session.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ios_un_willpresent',
      '#4 payload=reminder:act_9 at=2026-10-07T19:00:00Z',
    );
    LaunchTrail.pullNative();
    expect(LaunchTrail.hasNotificationEvidence, isTrue);
  });

  test('the dialog flag is once per process', () {
    expect(LaunchTrail.dialogShown, isFalse);
    LaunchTrail.markDialogShown();
    expect(LaunchTrail.dialogShown, isTrue);
  });
}

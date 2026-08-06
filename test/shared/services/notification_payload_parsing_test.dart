import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';

/// Parsing guards for notification payload strings.
///
/// The activity id extracted here is what deep-links the tap to a screen, so
/// a parsing slip is a dead notification, not just a bad analytics row. The
/// third `copyVariant` segment was added to segment push click-through by
/// wording; two-segment payloads predate it and must keep working, since one
/// can sit in a notification tray across an app upgrade.
void main() {
  group('parseTypedNotificationPayload', () {
    test('parses a two-segment payload with no variant', () {
      final parsed = NotificationService.parseTypedNotificationPayload(
        'activity:abc-123',
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, 'activity');
      expect(parsed.activityId, 'abc-123');
      expect(parsed.copyVariant, isNull);
    });

    test(
      'parses a three-segment payload and strips the variant from the id',
      () {
        final parsed = NotificationService.parseTypedNotificationPayload(
          'activity:abc-123:accuracy_hook_v2',
        );

        expect(parsed, isNotNull);
        expect(parsed!.type, 'activity');
        expect(parsed.activityId, 'abc-123');
        expect(parsed.copyVariant, 'accuracy_hook_v2');
      },
    );

    test('parses a real UUID activity id', () {
      final parsed = NotificationService.parseTypedNotificationPayload(
        'activity:3a7e3fdb-754c-812c-85f2-eb86d213c863:accuracy_hook_v2',
      );

      expect(parsed!.activityId, '3a7e3fdb-754c-812c-85f2-eb86d213c863');
      expect(parsed.copyVariant, 'accuracy_hook_v2');
    });

    test('keeps the reminder type working', () {
      final parsed = NotificationService.parseTypedNotificationPayload(
        'reminder:abc-123',
      );

      expect(parsed!.type, 'reminder');
      expect(parsed.activityId, 'abc-123');
      expect(parsed.copyVariant, isNull);
    });

    test('treats a trailing colon as no variant rather than an empty one', () {
      final parsed = NotificationService.parseTypedNotificationPayload(
        'activity:abc-123:',
      );

      expect(parsed!.activityId, 'abc-123');
      expect(parsed.copyVariant, isNull);
    });

    test('returns null for a bare activity id (legacy reminder format)', () {
      expect(
        NotificationService.parseTypedNotificationPayload('abc-123'),
        isNull,
      );
    });

    test('returns null for an empty payload', () {
      expect(NotificationService.parseTypedNotificationPayload(''), isNull);
    });

    test('returns null when the type is missing', () {
      expect(
        NotificationService.parseTypedNotificationPayload(':abc-123'),
        isNull,
      );
    });

    test('returns null when the activity id is missing', () {
      expect(
        NotificationService.parseTypedNotificationPayload('activity:'),
        isNull,
      );
    });

    test(
      'returns null when the activity id is empty but a variant follows',
      () {
        expect(
          NotificationService.parseTypedNotificationPayload(
            'activity::accuracy_hook_v2',
          ),
          isNull,
        );
      },
    );
  });
}

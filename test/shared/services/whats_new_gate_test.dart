import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/whats_new_gate.dart';

void main() {
  group('shouldShowWhatsNew', () {
    test('fresh install at the announced version shows', () {
      expect(
        shouldShowWhatsNew(
          appVersion: '1.26.0',
          announcementVersion: '1.26.0',
          lastShownVersion: null,
        ),
        isTrue,
      );
    });

    test('update past the announced version shows once', () {
      expect(
        shouldShowWhatsNew(
          appVersion: '1.27.2',
          announcementVersion: '1.26.0',
          lastShownVersion: null,
        ),
        isTrue,
      );
      expect(
        shouldShowWhatsNew(
          appVersion: '1.27.2',
          announcementVersion: '1.26.0',
          lastShownVersion: '1.26.0',
        ),
        isFalse,
      );
    });

    test('an older binary than the announcement stays quiet', () {
      expect(
        shouldShowWhatsNew(
          appVersion: '1.25.0',
          announcementVersion: '1.26.0',
          lastShownVersion: null,
        ),
        isFalse,
      );
    });

    test('a new announcement re-shows after an earlier one', () {
      expect(
        shouldShowWhatsNew(
          appVersion: '1.30.0',
          announcementVersion: '1.30.0',
          lastShownVersion: '1.26.0',
        ),
        isTrue,
      );
    });

    test('empty announcement disables the sheet', () {
      expect(
        shouldShowWhatsNew(
          appVersion: '1.26.0',
          announcementVersion: '',
          lastShownVersion: null,
        ),
        isFalse,
      );
    });
  });

  group('compareVersions', () {
    test('numeric, build-suffix-blind, short forms', () {
      expect(compareVersions('1.26.0+42', '1.26.0'), 0);
      expect(compareVersions('1.26', '1.26.0'), 0);
      expect(compareVersions('1.9.0', '1.10.0'), lessThan(0));
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
    });
  });
}

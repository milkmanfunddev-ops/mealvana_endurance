/// Ticket 36: `isPrivateRelayEmail` decides whether the profile Email field
/// is an editable contact email, and whether a fresh login keeps one.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/support/support_identity.dart';

void main() {
  group('isPrivateRelayEmail', () {
    test('an Apple private-relay address is a relay', () {
      expect(isPrivateRelayEmail('x1y2@privaterelay.appleid.com'), isTrue);
    });

    test('case and surrounding space do not matter', () {
      expect(isPrivateRelayEmail(' X1Y2@PrivateRelay.AppleID.com '), isTrue);
    });

    test('a plain address is not a relay', () {
      expect(isPrivateRelayEmail('lee@example.com'), isFalse);
      expect(isPrivateRelayEmail('lee@icloud.com'), isFalse);
    });

    test('empty and null are not relays', () {
      expect(isPrivateRelayEmail(''), isFalse);
      expect(isPrivateRelayEmail(null), isFalse);
    });
  });

  group('resolveSupportEmail', () {
    test('prefers a real address over a relay one', () {
      expect(
        resolveSupportEmail(['x@privaterelay.appleid.com', 'lee@example.com']),
        'lee@example.com',
      );
    });

    test('falls back to the relay when it is all there is', () {
      expect(
        resolveSupportEmail([null, '', 'x@privaterelay.appleid.com']),
        'x@privaterelay.appleid.com',
      );
    });

    test('returns null with no usable address', () {
      expect(resolveSupportEmail([null, '  ']), isNull);
    });
  });
}

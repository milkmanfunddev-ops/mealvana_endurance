/// Domain models for sharing and barcode results.
///
/// Both shipped with no `test/features/` counterpart. These are the pieces
/// where a quiet mistake is expensive and invisible: a share result that
/// reports success while carrying an error, a barcode result whose
/// success/failure predicates disagree with its payload.
///
/// The SatisfactionLevel/AppFeedbackOption groups that used to live here were
/// removed on 2026-08-05 along with the unreachable survey UI they covered.
/// Testing deleted code is worse than not testing it — it reads as coverage.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/barcode_scanning/domain/api_food_product.dart';
import 'package:mealvana_endurance/features/barcode_scanning/domain/barcode_result.dart';
import 'package:mealvana_endurance/features/sharing/domain/share_form_data.dart';
import 'package:mealvana_endurance/features/sharing/domain/share_result.dart';

void main() {
  group('ShareResult', () {
    test('success carries no error', () {
      final r = ShareResult.success(message: 'Sent');
      expect(r.success, isTrue);
      expect(r.message, 'Sent');
      expect(r.error, isNull);
    });

    test('failure carries no success message', () {
      final r = ShareResult.failure(error: 'SMTP refused');
      expect(r.success, isFalse);
      expect(r.error, 'SMTP refused');
      expect(r.message, isNull);
    });

    test('the two factories never produce the same success flag', () {
      expect(
        ShareResult.success().success,
        isNot(ShareResult.failure(error: 'x').success),
      );
    });
  });

  group('ShareFormData', () {
    const base = ShareFormData(
      recipientEmail: 'coach@example.com',
      senderName: 'Lee',
      subject: 'Race plan',
      comments: 'See you Sunday',
    );

    test('round-trips through JSON', () {
      final restored = ShareFormData.fromJson(base.toJson());
      expect(restored.recipientEmail, base.recipientEmail);
      expect(restored.senderName, base.senderName);
      expect(restored.subject, base.subject);
      expect(restored.comments, base.comments);
    });

    test('omits null optionals from JSON rather than writing nulls', () {
      const minimal = ShareFormData(recipientEmail: 'a@b.com');
      final json = minimal.toJson();
      expect(json['recipientEmail'], 'a@b.com');
      expect(json.containsKey('senderName'), isFalse);
      expect(json.containsKey('subject'), isFalse);
      expect(json.containsKey('comments'), isFalse);
    });

    test('a minimal payload round-trips', () {
      const minimal = ShareFormData(recipientEmail: 'a@b.com');
      final restored = ShareFormData.fromJson(minimal.toJson());
      expect(restored.recipientEmail, 'a@b.com');
      expect(restored.senderName, isNull);
    });

    test('copyWith changes only what it is given', () {
      final updated = base.copyWith(recipientEmail: 'other@example.com');
      expect(updated.recipientEmail, 'other@example.com');
      expect(updated.senderName, base.senderName);
      expect(updated.subject, base.subject);
      expect(updated.comments, base.comments);
    });

    test('copyWith cannot silently blank the recipient', () {
      // The recipient is the address a nutrition plan gets emailed to, so a
      // no-arg copyWith must not turn it into an empty string.
      final untouched = base.copyWith();
      expect(untouched.recipientEmail, base.recipientEmail);
      expect(untouched.recipientEmail, isNotEmpty);
    });
  });

  group('BarcodeResult', () {
    const product = ApiFoodProduct(
      barcode: '5000112637922',
      productName: 'Test Drink',
      apiSource: 'open_food_facts',
      confidenceScore: 1.0,
    );

    test('success carries the product and no message', () {
      const r = BarcodeResult.success(
        barcode: '5000112637922',
        product: product,
      );
      expect(r.isSuccess, isTrue);
      expect(r.isNotFound, isFalse);
      expect(r.isError, isFalse);
      expect(r.product, isNotNull);
      expect(r.message, isNull);
    });

    test('notFound carries a message and no product', () {
      const r = BarcodeResult.notFound(
        barcode: '123',
        message: 'Not in any database',
      );
      expect(r.isNotFound, isTrue);
      expect(r.isSuccess, isFalse);
      expect(r.product, isNull);
      expect(r.message, 'Not in any database');
    });

    test('error carries a message and no product', () {
      const r = BarcodeResult.error(barcode: '123', message: 'Network down');
      expect(r.isError, isTrue);
      expect(r.isSuccess, isFalse);
      expect(r.product, isNull);
      expect(r.message, 'Network down');
    });

    test('exactly one predicate is true for any result', () {
      // A result that answers yes to two of these would let a caller take the
      // success path on a failure.
      final results = <BarcodeResult>[
        const BarcodeResult.success(barcode: '1', product: product),
        const BarcodeResult.notFound(barcode: '2', message: 'nope'),
        const BarcodeResult.error(barcode: '3', message: 'boom'),
      ];
      for (final r in results) {
        final flags = [r.isSuccess, r.isNotFound, r.isError];
        expect(
          flags.where((f) => f).length,
          1,
          reason: 'Ambiguous result state for barcode ${r.barcode}: $flags',
        );
      }
    });

    test('the scanned barcode survives on every branch', () {
      // Losing it means retries and error reporting cannot say what was
      // scanned.
      expect(
        const BarcodeResult.success(barcode: 'abc', product: product).barcode,
        'abc',
      );
      expect(
        const BarcodeResult.notFound(barcode: 'abc', message: 'm').barcode,
        'abc',
      );
      expect(
        const BarcodeResult.error(barcode: 'abc', message: 'm').barcode,
        'abc',
      );
    });
  });
}

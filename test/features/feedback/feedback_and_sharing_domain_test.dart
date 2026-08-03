/// Domain models for feedback, sharing and barcode results.
///
/// All three features shipped with no `test/features/` counterpart at all.
/// These are the pieces where a quiet mistake is expensive and invisible:
/// a satisfaction rating whose numeric value shifts meaning, a share result
/// that reports success while carrying an error, a barcode result whose
/// success/failure predicates disagree with its payload.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/barcode_scanning/domain/api_food_product.dart';
import 'package:mealvana_endurance/features/barcode_scanning/domain/barcode_result.dart';
import 'package:mealvana_endurance/features/feedback/domain/feedback_data.dart';
import 'package:mealvana_endurance/features/sharing/domain/share_form_data.dart';
import 'package:mealvana_endurance/features/sharing/domain/share_result.dart';

void main() {
  group('SatisfactionLevel — the numbers are persisted, so pin them', () {
    // `value` is what goes into storage and into the Google-Forms submission
    // (FeedbackResponse.toFormData writes satisfactionLevel.value). If these
    // ever shift, every historical rating silently changes meaning and no
    // migration would catch it, because the old rows are just integers.
    test('each level keeps its stored number', () {
      expect(SatisfactionLevel.tooMuch.value, 1);
      expect(SatisfactionLevel.justRight.value, 2);
      expect(SatisfactionLevel.tooLittle.value, 3);
    });

    test('values are unique', () {
      final values = SatisfactionLevel.values.map((l) => l.value).toList();
      expect(values.toSet().length, values.length);
    });

    test('fromValue round-trips every level', () {
      for (final level in SatisfactionLevel.values) {
        expect(SatisfactionLevel.fromValue(level.value), level);
      }
    });

    test('an unknown value silently becomes justRight', () {
      // Pinned as CURRENT behaviour, and flagged: `orElse` maps anything
      // unrecognised — a corrupt row, a value from a newer build, a 0 default
      // — onto a real, neutral-positive rating rather than surfacing as
      // unknown. Feedback analytics cannot tell a genuine "just right" from a
      // parse failure, which biases the distribution toward the middle.
      expect(SatisfactionLevel.fromValue(0), SatisfactionLevel.justRight);
      expect(SatisfactionLevel.fromValue(4), SatisfactionLevel.justRight);
      expect(SatisfactionLevel.fromValue(-1), SatisfactionLevel.justRight);
    });

    test('every level has a non-empty emoji and label', () {
      for (final level in SatisfactionLevel.values) {
        expect(level.emoji, isNotEmpty, reason: '${level.name} has no emoji');
        expect(level.label, isNotEmpty, reason: '${level.name} has no label');
      }
    });

    test('the two extremes do not share an emoji with each other', () {
      // Over- and under-fuelling are different mistakes; if they render the
      // same face the slider cannot communicate which way the athlete erred.
      expect(
        SatisfactionLevel.tooMuch.emoji,
        isNot(SatisfactionLevel.tooLittle.emoji),
      );
    });
  });

  group('AppFeedbackOption', () {
    test('every option carries a label', () {
      for (final o in AppFeedbackOption.values) {
        expect(o.label, isNotEmpty);
      }
    });

    test('labels are distinct — they are the radio-button text', () {
      final labels = AppFeedbackOption.values.map((o) => o.label).toList();
      expect(labels.toSet().length, labels.length);
    });
  });

  group('FeedbackResponse.toFormData', () {
    test('submits the numeric satisfaction value, not the enum name', () {
      const r = FeedbackResponse(
        satisfactionLevel: SatisfactionLevel.tooLittle,
      );
      expect(r.toFormData()['satisfaction'], 3);
    });
  });

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

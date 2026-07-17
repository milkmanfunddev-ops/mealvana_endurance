import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity_completion.dart';

void main() {
  ActivityCompletion buildCompletion({
    int? overallSatisfaction,
    int? nutritionRating,
    String? textNotes,
    bool hasVoiceRecording = false,
  }) {
    return ActivityCompletion(
      id: 1,
      activityId: 2,
      userId: 'user-1',
      completedAt: DateTime(2026, 7, 16, 8, 30),
      overallSatisfaction: overallSatisfaction,
      nutritionRating: nutritionRating,
      textNotes: textNotes,
      hasVoiceRecording: hasVoiceRecording,
    );
  }

  group('ActivityCompletion (post effort-rating removal)', () {
    test('toJson contains surviving rating keys and no effortRating key', () {
      final json = buildCompletion(
        overallSatisfaction: 4,
        nutritionRating: 3,
      ).toJson();

      expect(json['overallSatisfaction'], 4);
      expect(json['nutritionRating'], 3);
      expect(json.containsKey('effortRating'), isFalse);
    });

    test('copyWith round-trips overallSatisfaction and nutritionRating', () {
      final original = buildCompletion();
      final updated = original.copyWith(
        overallSatisfaction: 5,
        nutritionRating: 2,
      );

      expect(updated.overallSatisfaction, 5);
      expect(updated.nutritionRating, 2);
      // Unspecified fields are preserved.
      expect(updated.id, original.id);
      expect(updated.activityId, original.activityId);
      expect(updated.userId, original.userId);
      expect(updated.completedAt, original.completedAt);

      // copyWith with no args preserves the ratings.
      final unchanged = updated.copyWith();
      expect(unchanged.overallSatisfaction, 5);
      expect(unchanged.nutritionRating, 2);
    });

    test('equality and hashCode respect surviving rating fields', () {
      final a = buildCompletion(overallSatisfaction: 4, nutritionRating: 3);
      final b = buildCompletion(overallSatisfaction: 4, nutritionRating: 3);
      final c = buildCompletion(overallSatisfaction: 5, nutritionRating: 3);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    group('hasUserFeedback', () {
      test('true when only overallSatisfaction is set', () {
        expect(buildCompletion(overallSatisfaction: 4).hasUserFeedback, isTrue);
      });

      test('true when only nutritionRating is set', () {
        expect(buildCompletion(nutritionRating: 2).hasUserFeedback, isTrue);
      });

      test('true when only text notes are present', () {
        expect(buildCompletion(textNotes: 'Felt great').hasUserFeedback, isTrue);
      });

      test('false when no feedback at all', () {
        expect(buildCompletion().hasUserFeedback, isFalse);
      });

      test('false when text notes are empty', () {
        expect(buildCompletion(textNotes: '').hasUserFeedback, isFalse);
      });
    });
  });
}

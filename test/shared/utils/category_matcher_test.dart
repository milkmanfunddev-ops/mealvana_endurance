import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/utils/category_matcher.dart';

void main() {
  group('CategoryMatcher', () {
    test('during_swim only matches swim during section', () {
      expect(
        CategoryMatcher.matches(
          'during_swim',
          'during_segment_1',
          'During Swim',
        ),
        isTrue,
      );
      expect(
        CategoryMatcher.matches(
          'during_swim',
          'during_segment_2',
          'During Bike',
        ),
        isFalse,
      );
      expect(
        CategoryMatcher.matches(
          'during_swim',
          'during_segment_3',
          'During Run',
        ),
        isFalse,
      );
    });

    test('during_cycling only matches bike/cycle/ride during section', () {
      expect(
        CategoryMatcher.matches(
          'during_cycling',
          'during_segment_2',
          'During Bike',
        ),
        isTrue,
      );
      expect(
        CategoryMatcher.matches(
          'during_cycling',
          'during_segment_1',
          'During Swim',
        ),
        isFalse,
      );
      expect(
        CategoryMatcher.matches(
          'during_cycling',
          'during_segment_3',
          'During Run',
        ),
        isFalse,
      );
    });

    test('during_run matches run and generic during sections only', () {
      expect(
        CategoryMatcher.matches('during_run', 'during_segment_3', 'During Run'),
        isTrue,
      );
      expect(
        CategoryMatcher.matches('during_run', 'during_1', 'During'),
        isTrue,
      );
      expect(
        CategoryMatcher.matches(
          'during_run',
          'during_segment_1',
          'During Swim',
        ),
        isFalse,
      );
      expect(
        CategoryMatcher.matches(
          'during_run',
          'during_segment_2',
          'During Bike',
        ),
        isFalse,
      );
      expect(
        CategoryMatcher.matches(
          'during_run',
          'during_segment_1',
          'During Segment 1',
        ),
        isFalse,
      );
    });

    test('generic during category still matches all during sections', () {
      expect(
        CategoryMatcher.matches('during', 'during_segment_1', 'During Swim'),
        isTrue,
      );
      expect(
        CategoryMatcher.matches('during', 'during_segment_2', 'During Bike'),
        isTrue,
      );
      expect(
        CategoryMatcher.matches('during', 'during_segment_3', 'During Run'),
        isTrue,
      );
    });
  });
}

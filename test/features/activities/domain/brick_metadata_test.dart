import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';

void main() {
  group('BrickMetadata.fromJson', () {
    test('parses segments when numeric values are integers', () {
      final metadata = BrickMetadata.fromJson({
        'segment_order': ['swimming', 'running'],
        'segments': [
          {
            'sport': 'swimming',
            'order': 1,
            'duration_minutes': 30,
            'intensity': 'moderate',
            'distance_meters': 1500,
            'pace_per_100m_seconds': 110,
          },
          {
            'sport': 'running',
            'order': 2,
            'duration_minutes': 27,
            'intensity': 'easy',
            'distance_miles': 3,
            'pace_minutes_per_mile': 9,
          },
        ],
        'created_from_existing': false,
        'total_duration_minutes': 57,
      });

      expect(metadata.segmentOrder, ['swimming', 'running']);
      expect(metadata.segments, hasLength(2));
      expect(metadata.segments.first.distanceMeters, 1500.0);
      expect(metadata.segments.last.distanceMiles, 3.0);
      expect(metadata.segments.last.paceMinutesPerMile, 9.0);
    });

    test('supports camelCase fallback keys', () {
      final metadata = BrickMetadata.fromJson({
        'segmentOrder': ['cycling', 'running'],
        'segments': [
          {
            'sport': 'cycling',
            'order': 1,
            'durationMinutes': 45,
            'intensity': 'hard',
            'distanceMiles': 15,
            'speedMph': 20,
          },
        ],
        'createdFromExisting': true,
        'totalDurationMinutes': 45,
      });

      expect(metadata.segmentOrder, ['cycling', 'running']);
      expect(metadata.createdFromExisting, isTrue);
      expect(metadata.segments.single.durationMinutes, 45);
      expect(metadata.segments.single.speedMph, 20.0);
    });
  });
}

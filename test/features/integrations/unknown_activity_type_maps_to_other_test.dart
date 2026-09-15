// Claudia bug (2026-09-10): a strength session showed as "Run" in the coach
// portal. Two mappers defaulted an unrecognized activity/event type to
// ActivityType.running instead of .other — false data on the surface a coach
// coaches from. Both now map unknown → other (imported for visibility, never
// misclassified as a run), matching the enum's own documented rule.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/athlete_detail_controller.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  group('Site 1 — coach portal AthleteDetailController.parseActivityType', () {
    test('unrecognized / null / empty → other, never running', () {
      expect(
        AthleteDetailController.parseActivityType('strength'),
        ActivityType.other,
      );
      expect(
        AthleteDetailController.parseActivityType('yoga'),
        ActivityType.other,
      );
      expect(
        AthleteDetailController.parseActivityType(null),
        ActivityType.other,
      );
      expect(AthleteDetailController.parseActivityType(''), ActivityType.other);
      expect(
        AthleteDetailController.parseActivityType('strength'),
        isNot(ActivityType.running),
      );
    });
    test('recognized values still parse correctly', () {
      expect(
        AthleteDetailController.parseActivityType('running'),
        ActivityType.running,
      );
      expect(
        AthleteDetailController.parseActivityType('cycling'),
        ActivityType.cycling,
      );
    });
  });

  group('Site 2 — TrainingPeaksEventResult.activityType (event mapper)', () {
    TrainingPeaksEventResult ev(String type) => TrainingPeaksEventResult(
      eventId: 'e',
      eventDate: DateTime(2026, 1, 1),
      eventType: type,
      eventName: 'x',
    );
    test('unknown event type → other, never running', () {
      expect(ev('strength').activityType, ActivityType.other);
      expect(ev('crossfit').activityType, ActivityType.other);
      expect(ev('strength').activityType, isNot(ActivityType.running));
    });
    test('recognized event types still map correctly', () {
      expect(ev('marathon').activityType, ActivityType.running);
      expect(ev('triathlon').activityType, ActivityType.triathlon);
    });
  });
}

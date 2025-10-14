import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';

class RecordedAnalyticsEvent {
  const RecordedAnalyticsEvent(this.name, this.properties);

  final String name;
  final Map<String, dynamic>? properties;
}

class RecordingAnalyticsTracker implements AnalyticsTracker {
  bool initialized = false;
  final List<RecordedAnalyticsEvent> events = [];
  final List<String> timedEvents = [];
  bool flushed = false;
  String? lastIdentifiedUser;
  Map<String, dynamic>? lastIdentifyProperties;

  @override
  Future<void> flush() async {
    flushed = true;
  }

  @override
  Future<void> identifyUser(
    String userId, {
    Map<String, dynamic>? properties,
    String? gender,
    int? age,
    double? weightPounds,
    bool? runsWithWaterBottle,
    String? gutTrainingLevel,
  }) async {
    lastIdentifiedUser = userId;
    lastIdentifyProperties = {
      ...?properties,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (weightPounds != null) 'weight_lbs': weightPounds,
      if (runsWithWaterBottle != null)
        'runs_with_water_bottle': runsWithWaterBottle,
      if (gutTrainingLevel != null) 'gut_training_level': gutTrainingLevel,
    };
  }

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> resetUser() async {
    lastIdentifiedUser = null;
    lastIdentifyProperties = null;
  }

  @override
  Future<void> timeEvent(String eventName) async {
    timedEvents.add(eventName);
  }

  @override
  Future<void> track(String eventName, {Map<String, dynamic>? properties}) async {
    events.add(RecordedAnalyticsEvent(eventName, properties));
  }
}

import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';

/// Recording implementation of AnalyticsTracker for testing
/// Records all analytics calls for verification without hitting real services
class RecordingAnalyticsTracker implements AnalyticsTracker {
  RecordingAnalyticsTracker();

  // Recorded calls storage
  final List<TrackCall> trackedEvents = [];
  final List<IdentifyCall> identifyCalls = [];
  final List<String> resetCalls = [];
  final List<String> timedEvents = [];
  final List<String> flushCalls = [];
  bool _initialized = false;

  // Getters for test assertions
  bool get isInitialized => _initialized;
  int get trackCount => trackedEvents.length;
  int get identifyCount => identifyCalls.length;
  int get resetCount => resetCalls.length;

  @override
  Future<void> initialize() async {
    _initialized = true;
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
    identifyCalls.add(IdentifyCall(
      userId: userId,
      properties: properties,
      gender: gender,
      age: age,
      weightPounds: weightPounds,
      runsWithWaterBottle: runsWithWaterBottle,
      gutTrainingLevel: gutTrainingLevel,
    ));
  }

  @override
  Future<void> resetUser() async {
    resetCalls.add(DateTime.now().toIso8601String());
  }

  @override
  Future<void> track(String eventName, {Map<String, dynamic>? properties}) async {
    trackedEvents.add(TrackCall(
      eventName: eventName,
      properties: properties,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> timeEvent(String eventName) async {
    timedEvents.add(eventName);
  }

  @override
  Future<void> flush() async {
    flushCalls.add(DateTime.now().toIso8601String());
  }

  // Helper methods for test assertions
  bool hasEvent(String eventName) {
    return trackedEvents.any((call) => call.eventName == eventName);
  }

  TrackCall? getEvent(String eventName) {
    try {
      return trackedEvents.firstWhere(
        (call) => call.eventName == eventName,
      );
    } catch (e) {
      return null;
    }
  }

  List<TrackCall> getEvents(String eventName) {
    return trackedEvents.where((call) => call.eventName == eventName).toList();
  }

  void clear() {
    trackedEvents.clear();
    identifyCalls.clear();
    resetCalls.clear();
    timedEvents.clear();
    flushCalls.clear();
  }
}

/// Data class for recorded track calls
class TrackCall {
  const TrackCall({
    required this.eventName,
    this.properties,
    required this.timestamp,
  });

  final String eventName;
  final Map<String, dynamic>? properties;
  final DateTime timestamp;
}

/// Data class for recorded identify calls
class IdentifyCall {
  const IdentifyCall({
    required this.userId,
    this.properties,
    this.gender,
    this.age,
    this.weightPounds,
    this.runsWithWaterBottle,
    this.gutTrainingLevel,
  });

  final String userId;
  final Map<String, dynamic>? properties;
  final String? gender;
  final int? age;
  final double? weightPounds;
  final bool? runsWithWaterBottle;
  final String? gutTrainingLevel;
}

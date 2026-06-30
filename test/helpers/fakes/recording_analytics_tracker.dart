/// Recording analytics tracker for testing
/// Captures all analytics calls for verification in tests
library;

import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';

/// Analytics event record
class AnalyticsEvent {
  const AnalyticsEvent({
    required this.name,
    this.properties,
  });

  final String name;
  final Map<String, dynamic>? properties;

  @override
  String toString() => 'AnalyticsEvent($name, $properties)';
}

/// User identification record
class UserIdentification {
  const UserIdentification({
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

  @override
  String toString() => 'UserIdentification($userId)';
}

/// Recording implementation of AnalyticsTracker for testing
class RecordingAnalyticsTracker implements AnalyticsTracker {
  final List<AnalyticsEvent> events = [];
  final List<UserIdentification> identifications = [];
  final List<String> timedEvents = [];

  bool _initialized = false;
  bool _userReset = false;
  int _flushCount = 0;

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
    identifications.add(UserIdentification(
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
    _userReset = true;
  }

  @override
  Future<void> track(String eventName, {Map<String, dynamic>? properties}) async {
    events.add(AnalyticsEvent(name: eventName, properties: properties));
  }

  @override
  Future<void> timeEvent(String eventName) async {
    timedEvents.add(eventName);
  }

  @override
  Future<void> flush() async {
    _flushCount++;
  }

  @override
  Future<void> markInternal() async {}


  // Test helpers
  bool get isInitialized => _initialized;
  bool get wasUserReset => _userReset;
  int get flushCount => _flushCount;

  UserIdentification? get lastIdentifiedUser =>
      identifications.isNotEmpty ? identifications.last : null;

  AnalyticsEvent? get lastEvent =>
      events.isNotEmpty ? events.last : null;

  /// Find events by name
  List<AnalyticsEvent> findEvents(String name) {
    return events.where((e) => e.name == name).toList();
  }

  /// Check if an event was tracked
  bool hasEvent(String name) {
    return events.any((e) => e.name == name);
  }

  /// Clear all recorded data (for test cleanup)
  void clear() {
    events.clear();
    identifications.clear();
    timedEvents.clear();
    _initialized = false;
    _userReset = false;
    _flushCount = 0;
  }
}

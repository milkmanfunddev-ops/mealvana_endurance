import '../../../shared/domain/activity_type.dart';

/// Represents an event search result from Active.com API
/// Used for autocomplete functionality when creating events
class ActiveComEvent {
  final String eventName;
  final String? location;
  final DateTime? eventDate;
  final DateTime? startTime;
  final ActivityType? sportType;
  final String? eventSubtype;
  final String? registrationUrl;

  const ActiveComEvent({
    required this.eventName,
    this.location,
    this.eventDate,
    this.startTime,
    this.sportType,
    this.eventSubtype,
    this.registrationUrl,
  });

  /// Parse from JSON response from edge function
  factory ActiveComEvent.fromJson(Map<String, dynamic> json) {
    return ActiveComEvent(
      eventName: json['eventName'] as String,
      location: json['location'] as String?,
      eventDate: json['eventDate'] != null
          ? DateTime.tryParse(json['eventDate'] as String)
          : null,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String)
          : null,
      sportType: json['sportType'] != null
          ? _parseEventType(json['sportType'] as String)
          : null,
      eventSubtype: json['eventSubtype'] as String?,
      registrationUrl: json['registrationUrl'] as String?,
    );
  }

  /// Parse sport type string to ActivityType enum
  static ActivityType? _parseEventType(String sportTypeString) {
    switch (sportTypeString.toLowerCase()) {
      case 'running':
        return ActivityType.running;
      case 'cycling':
        return ActivityType.cycling;
      case 'swimming':
        return ActivityType.swimming;
      default:
        return null;
    }
  }

  @override
  String toString() {
    return 'ActiveComEvent(eventName: $eventName, location: $location, '
        'eventDate: $eventDate, sportType: $sportType)';
  }
}

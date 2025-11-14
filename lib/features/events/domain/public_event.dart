import '../../../shared/domain/activity_type.dart';

/// Public Event domain model
///
/// Represents a publicly available race event from the public_events table.
/// Used for autocomplete in event creation.
class PublicEvent {
  final int id;
  final String eventName;
  final ActivityType eventType;
  final String? eventSubtype;
  final String? location;
  final String? city;
  final String? state;
  final DateTime? eventDate;
  final String? startTime; // Time as string (HH:MM:SS)
  final String? registrationUrl;
  final String? websiteUrl;
  final String? description;
  final String? organizerName;

  const PublicEvent({
    required this.id,
    required this.eventName,
    required this.eventType,
    this.eventSubtype,
    this.location,
    this.city,
    this.state,
    this.eventDate,
    this.startTime,
    this.registrationUrl,
    this.websiteUrl,
    this.description,
    this.organizerName,
  });

  /// Create from JSON (from Supabase Edge Function response)
  factory PublicEvent.fromJson(Map<String, dynamic> json) {
    return PublicEvent(
      id: json['id'] as int,
      eventName: json['event_name'] as String,
      eventType: ActivityType.fromDbValue(json['event_type'] as String),
      eventSubtype: json['event_subtype'] as String?,
      location: json['location'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'] as String)
          : null,
      startTime: json['start_time'] as String?,
      registrationUrl: json['registration_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      description: json['description'] as String?,
      organizerName: json['organizer_name'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_name': eventName,
      'event_type': eventType.dbValue,
      'event_subtype': eventSubtype,
      'location': location,
      'city': city,
      'state': state,
      'event_date': eventDate?.toIso8601String(),
      'start_time': startTime,
      'registration_url': registrationUrl,
      'website_url': websiteUrl,
      'description': description,
      'organizer_name': organizerName,
    };
  }

  /// Get formatted location for display (e.g., "San Francisco, CA")
  String get formattedLocation {
    if (city != null && state != null) {
      return '$city, ${state!.toUpperCase()}';
    } else if (city != null) {
      return city!;
    } else if (location != null) {
      return location!;
    }
    return 'Unknown Location';
  }
}

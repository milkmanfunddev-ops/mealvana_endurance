/// Location data model
/// Represents a geographic location with coordinates and optional address
class Location {
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? country;

  const Location({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.country,
  });

  /// Create from JSON
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'country': country,
    };
  }

  /// Get display name for location
  String get displayName {
    if (city != null && country != null) {
      return '$city, $country';
    } else if (city != null) {
      return city!;
    } else if (address != null) {
      return address!;
    } else {
      // Return a simple description instead of coordinates
      return 'Current location';
    }
  }

  /// Get short display name (city only if available)
  String get shortDisplayName {
    return city ??
        '${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)}';
  }

  Location copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? country,
  }) {
    return Location(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Location &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

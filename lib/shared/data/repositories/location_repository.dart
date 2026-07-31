import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:location_iq/location_iq.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_repository.g.dart';

/// Repository for location-based operations using LocationIQ API.
///
/// Provides geocoding and address autocomplete functionality for finding
/// event locations, venues, and addresses.
///
/// **Data Layer (FOA)**: Handles external API calls to LocationIQ.
@riverpod
LocationRepository locationRepository(Ref ref) {
  return LocationRepository();
}

class LocationRepository {
  LocationIQClient? _client;

  LocationIQClient get client {
    if (_client != null) return _client!;

    // Lazy-load the client when first accessed
    final apiKey = dotenv.env['LOCATIONIQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'LOCATIONIQ_API_KEY not found in environment variables. '
        'Make sure .env file is loaded and contains LOCATIONIQ_API_KEY.',
      );
    }
    _client = LocationIQClient(apiKey: apiKey);
    return _client!;
  }

  /// Searches for locations based on a query string (autocomplete).
  ///
  /// Returns a list of location suggestions with addresses, coordinates,
  /// and other metadata.
  ///
  /// Example:
  /// ```dart
  /// final results = await repository.searchLocations('Boston, MA');
  /// ```
  Future<List<LocationIQAutocompleteResult>> searchLocations(
    String query, {
    int limit = 5,
  }) async {
    try {
      final results = await client.autocomplete.suggest(
        query: query,
        limit: limit,
      );
      return results;
    } catch (e) {
      throw Exception('Failed to search locations: $e');
    }
  }

  /// Performs forward geocoding to convert an address to coordinates.
  ///
  /// Returns a list of possible location matches.
  Future<List<ForwardGeocodingResult>> geocode(String address) async {
    try {
      final results = await client.forwardFreeform.search(query: address);
      return results;
    } catch (e) {
      throw Exception('Failed to geocode address: $e');
    }
  }

  /// Performs reverse geocoding to convert coordinates to an address.
  ///
  /// Returns the address information for the given latitude and longitude.
  Future<LocationIQReverseResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final result = await client.reverse.reverseGeocode(
        lat: latitude.toString(),
        lon: longitude.toString(),
      );
      return result;
    } catch (e) {
      throw Exception('Failed to reverse geocode coordinates: $e');
    }
  }
}

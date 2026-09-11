import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:location_iq/location_iq.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/reverse_place.dart';

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
  LocationRepository({http.Client? httpClient, String? apiKey})
    : _http = httpClient ?? http.Client(),
      _apiKeyOverride = apiKey;

  final http.Client _http;
  final String? _apiKeyOverride;
  LocationIQClient? _client;

  String get _apiKey {
    final apiKey = _apiKeyOverride ?? dotenv.env['LOCATIONIQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'LOCATIONIQ_API_KEY not found in environment variables. '
        'Make sure .env file is loaded and contains LOCATIONIQ_API_KEY.',
      );
    }
    return apiKey;
  }

  // Lazy-load the client when first accessed
  LocationIQClient get client => _client ??= LocationIQClient(apiKey: _apiKey);

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
  /// Decoded here rather than by `location_iq`: its reverse model declares
  /// `osm_type` and `osm_id` non-null, and LocationIQ sends them null (or
  /// not at all) whenever the match is one of its own address points, which
  /// is most of the US. The package also asks for no address details, and
  /// the postcode lives in them.
  Future<ReversePlace> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('us1.locationiq.com', '/v1/reverse', {
      'key': _apiKey,
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'json',
      'addressdetails': '1',
      'accept-language': 'en',
    });
    final http.Response response;
    try {
      response = await _http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
    } on http.ClientException catch (e) {
      // Its message carries the request URI: the shopper's coordinates and
      // the API key. The caller logs what this throws.
      throw Exception('Failed to reverse geocode coordinates: ${e.message}');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to reverse geocode coordinates: '
        'LocationIQ answered ${response.statusCode}',
      );
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Reverse result is not an object');
    }
    final address = json['address'];
    return ReversePlace(
      postcode: address is Map<String, dynamic>
          ? address['postcode'] as String?
          : null,
    );
  }
}

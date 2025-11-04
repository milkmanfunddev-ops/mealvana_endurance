import 'package:location_iq/location_iq.dart';

/// Utility class for formatting location strings
class LocationFormatter {
  /// Formats a LocationIQ autocomplete result to show only city and state
  ///
  /// Examples:
  /// - "Chicago, Illinois" (from "Chicago, Cook County, Illinois")
  /// - "Birmingham, Alabama" (from "Birmingham, Jefferson County, Alabama")
  /// - Falls back to displayName if address components not available
  static String formatCityState(LocationIQAutocompleteResult result) {
    final address = result.address;

    if (address == null) {
      return result.displayName;
    }

    // Try to build "City, State" format
    final city = address.city ?? address.suburb ?? address.neighbourhood;
    final state = address.state;

    if (city != null && state != null) {
      return '$city, $state';
    }

    // Fallback to just city or state if only one is available
    if (city != null) {
      return city;
    }

    if (state != null) {
      return state;
    }

    // Last resort: use display name
    return result.displayName;
  }

  /// Parses a stored location string to extract just city and state
  ///
  /// This is useful for displaying locations that were already saved in the full format.
  ///
  /// Examples:
  /// - "Chicago, Cook County, Illinois" -> "Chicago, Illinois"
  /// - "Birmingham, Jefferson County, Alabama" -> "Birmingham, Alabama"
  /// - "New York, NY" -> "New York, NY" (already short)
  static String parseAndFormatCityState(String? locationString) {
    if (locationString == null || locationString.isEmpty) {
      return '';
    }

    // Split by comma
    final parts = locationString.split(',').map((e) => e.trim()).toList();

    if (parts.isEmpty) {
      return locationString;
    }

    // If we have 3+ parts, assume format is: City, County, State
    // Return City, State (skip county)
    if (parts.length >= 3) {
      // Take first part (city) and last part (state)
      return '${parts[0]}, ${parts[parts.length - 1]}';
    }

    // If we have exactly 2 parts, assume it's already City, State
    if (parts.length == 2) {
      return locationString;
    }

    // Single part, return as-is
    return locationString;
  }
}

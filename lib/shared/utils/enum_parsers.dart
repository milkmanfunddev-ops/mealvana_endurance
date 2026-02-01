/// Enum parsing utilities for sync operations.
///
/// Handles parsing of enum values from Supabase string representations
/// to local database format.
class EnumParsers {
  EnumParsers._(); // Private constructor - static methods only

  /// Parse gender string to database value.
  /// Returns 'male' as default if unrecognized.
  static String parseGender(String? gender) {
    switch (gender?.toLowerCase()) {
      case 'male':
        return 'male';
      case 'female':
        return 'female';
      default:
        return 'male';
    }
  }

  /// Parse gut training level string to database value.
  /// Note: GutTraining enum has: low, moderate, high (no 'none').
  /// Maps 'none' to 'low' since enum doesn't have 'none'.
  static String parseGutTrainingLevel(String? level) {
    switch (level?.toLowerCase()) {
      case 'none':
        return 'low'; // Map 'none' to 'low' since enum doesn't have 'none'
      case 'low':
        return 'low';
      case 'moderate':
        return 'moderate';
      case 'high':
        return 'high';
      default:
        return 'moderate';
    }
  }

  /// Parse activity status string with default fallback.
  static String parseActivityStatus(String? status) {
    if (status == null || status.isEmpty) return 'planned';
    return status;
  }

  /// Parse coach application status with default fallback.
  static String parseCoachApplicationStatus(String? status) {
    if (status == null || status.isEmpty) return 'pending';
    return status;
  }

  /// Parse relationship status with default fallback.
  static String parseRelationshipStatus(String? status) {
    if (status == null || status.isEmpty) return 'pending';
    return status;
  }
}

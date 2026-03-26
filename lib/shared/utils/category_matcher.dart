/// Utility class for matching nutrition plan categories to section IDs.
///
/// Supports all activity types: running, cycling, swimming, brick workouts.
/// Handles flexible prefix matching for before/during/after phases and
/// sport-specific during sections (e.g., during_swim, during_bike, during_run).
class CategoryMatcher {
  /// Check if a category matches a section by ID or title using flexible prefix matching.
  ///
  /// Supports:
  /// - Direct matches: category='during_run', sectionId='during_run'
  /// - Transition sections: category='transition', sectionId='T1' or 'T2'
  /// - Sport-specific during: category='during_swim' matches "During Swim" section
  /// - Phase prefix matching: category='before_run' matches sectionId containing 'before'
  ///
  /// Examples:
  /// ```dart
  /// CategoryMatcher.matches('before_run', 'before_run', 'Before Run') // true
  /// CategoryMatcher.matches('during_run', 'during_1', 'During Run') // true
  /// CategoryMatcher.matches('during_swim', 'during_swim', 'During Swim') // true
  /// CategoryMatcher.matches('transition', 'T1', 'T1') // true
  /// ```
  static bool matches(String category, String sectionId, String sectionTitle) {
    final categoryLower = category.toLowerCase();
    final sectionIdLower = sectionId.toLowerCase();
    final titleLower = sectionTitle.toLowerCase();

    // Direct section ID match (e.g., category='during_run', sectionId='during_run')
    if (sectionIdLower == categoryLower) return true;

    // Handle transition category (brick-specific)
    if (categoryLower == 'transition') {
      return sectionIdLower.startsWith('t') &&
          sectionIdLower.length <= 2; // T1, T2
    }

    // Handle sport-specific during categories (brick workouts)
    if (categoryLower.startsWith('during_')) {
      final sportSuffix = categoryLower.replaceFirst('during_', '');

      // Must be a during section
      if (!sectionIdLower.contains('during') &&
          !titleLower.startsWith('during')) {
        return false;
      }

      final hasSwimToken =
          sectionIdLower.contains('swim') || titleLower.contains('swim');
      final hasBikeToken =
          sectionIdLower.contains('bike') ||
          sectionIdLower.contains('cycle') ||
          sectionIdLower.contains('ride') ||
          titleLower.contains('bike') ||
          titleLower.contains('cycle') ||
          titleLower.contains('ride');
      final hasRunToken =
          sectionIdLower.contains('run') || titleLower.contains('run');

      // IMPORTANT: Do not fall back to generic "during" matching for swim/bike.
      // Brick plans can have multiple during sections; broad fallback causes
      // edits in one leg to apply to all legs.
      if (sportSuffix == 'swim' || sportSuffix == 'swimming') {
        return hasSwimToken;
      }
      if (sportSuffix == 'cycling' ||
          sportSuffix == 'bike' ||
          sportSuffix == 'ride') {
        return hasBikeToken;
      }
      if (sportSuffix == 'run' || sportSuffix == 'running') {
        if (hasRunToken) return true;
        // Single-sport compatibility: allow truly generic legacy "during"
        // section identifiers/titles that don't explicitly declare swim/bike.
        if (!hasSwimToken && !hasBikeToken) {
          return sectionIdLower == 'during' ||
              sectionIdLower == 'during_run' ||
              titleLower == 'during' ||
              titleLower == 'during run';
        }
        return false;
      }

      // Unknown during_* suffixes should only match generic during sections.
      return !hasSwimToken && !hasBikeToken && !hasRunToken;
    }

    // Extract phase prefix (e.g., 'before' from 'before_run')
    final phasePrefix = categoryLower.split('_').first;

    // Flexible prefix matching for before/after
    if (phasePrefix == 'before') {
      return sectionIdLower.contains('before') ||
          titleLower.startsWith('before');
    }
    if (phasePrefix == 'after') {
      return sectionIdLower.contains('after') || titleLower.startsWith('after');
    }
    // Generic "during" category (no sport suffix) matches any during section.
    if (phasePrefix == 'during' && categoryLower == 'during') {
      return sectionIdLower.contains('during') ||
          titleLower.startsWith('during');
    }

    return false;
  }
}

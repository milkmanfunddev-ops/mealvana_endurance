import 'dart:async';

/// Search strategy helper for managing local vs OpenFoodFacts search
///
/// Implements three-tiered search strategy:
/// - 4+ local results: Don't search OpenFoodFacts (good local coverage)
/// - 1-3 local results: Show optional search button (user decides)
/// - 0 local results: Auto-search OpenFoodFacts after debounce
///
/// This keeps the search logic DRY across controllers and screens.
class SearchStrategy {
  Timer? _debounceTimer;

  /// Default debounce duration for auto-search
  static const defaultDebounceDuration = Duration(milliseconds: 800);

  /// Threshold for "good local results" - no external search needed
  static const goodLocalResultsThreshold = 4;

  /// Maximum for showing optional search button
  static const optionalSearchThreshold = 3;

  /// Whether to auto-search OpenFoodFacts based on local result count
  ///
  /// Returns true if we should trigger automatic OpenFoodFacts search.
  /// This happens when there are 0 local results.
  bool shouldAutoSearch(int localResultCount) {
    return localResultCount == 0;
  }

  /// Whether to show the optional "Search OpenFoodFacts" button
  ///
  /// Returns true when we have 1-3 local results - enough to be useful,
  /// but the user might want more options from OpenFoodFacts.
  bool shouldShowSearchButton(int localResultCount) {
    return localResultCount > 0 && localResultCount <= optionalSearchThreshold;
  }

  /// Schedule an auto-search with debounce
  ///
  /// Cancels any existing timer and schedules a new one.
  /// The callback is only executed if the query still matches after the delay.
  ///
  /// Parameters:
  /// - [query]: The search query to execute
  /// - [getCurrentQuery]: Function to get the current query (for validation)
  /// - [onSearch]: Callback to execute the search
  /// - [debounceDuration]: How long to wait before searching
  void scheduleAutoSearch({
    required String query,
    required String Function() getCurrentQuery,
    required Function(String) onSearch,
    Duration debounceDuration = defaultDebounceDuration,
  }) {
    cancelAutoSearch();

    if (query.trim().isEmpty) return;

    _debounceTimer = Timer(debounceDuration, () {
      // Only search if query hasn't changed
      if (getCurrentQuery() == query) {
        onSearch(query);
      }
    });
  }

  /// Cancel any pending auto-search
  void cancelAutoSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Dispose of the timer
  void dispose() {
    cancelAutoSearch();
  }
}

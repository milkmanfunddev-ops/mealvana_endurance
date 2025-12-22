/// Screen mode enum for screens that can be used in multiple contexts
///
/// Used to determine the visual style and navigation behavior of shared screens.
enum ScreenMode {
  /// Onboarding mode - shows progress bar, navigates forward in onboarding flow
  onboarding,

  /// Settings mode - shows app bar with back button, pops when saving
  settings,
}

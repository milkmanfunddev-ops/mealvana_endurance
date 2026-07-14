/// Analytics support for the onboarding funnel.
///
/// The activation report shows ~46% of onboarded users never plan a workout,
/// and we are blind to *which* step they abandon. `onboarding_step_completed`
/// (fired per Continue tap) plus `step_index` on the existing `screen_viewed`
/// events turn that into a step-by-step drop-off funnel: `screen_viewed` says
/// they reached step N, `onboarding_step_completed` says they got past it.
library;

/// Wall-clock start of the onboarding run, stamped when Get Started is tapped
/// on the welcome screen and read once at the final step to derive
/// `duration_sec` on `onboarding_completed`.
///
/// Deliberately not Mixpanel's `timeEvent()`: that produces a `$duration`
/// property rather than the `duration_sec` the funnel spec asks for, and its
/// timer lives on the SDK instance — if consent is off when onboarding starts
/// the timer is never armed, so a later grant would report no duration at all.
///
/// A plain static rather than a provider: onboarding is a single, global,
/// non-reentrant flow, and this keeps the helper free of any Riverpod version
/// coupling so it ports cleanly to the older release branch.
class OnboardingAnalytics {
  const OnboardingAnalytics._();

  static DateTime? _startedAt;

  /// Marks the beginning of the onboarding funnel.
  static void markStarted() => _startedAt = DateTime.now();

  /// Seconds elapsed since [markStarted], or null if onboarding was not
  /// entered through the welcome screen (a resumed session, or a deep link
  /// straight into a step).
  ///
  /// Callers must omit the property when this is null rather than sending a
  /// zero — a bogus 0 would drag the median completion time down.
  static int? durationSec() {
    final startedAt = _startedAt;
    if (startedAt == null) return null;
    return DateTime.now().difference(startedAt).inSeconds;
  }

  /// Clears the stored start time. Exposed for tests.
  static void reset() => _startedAt = null;
}

/// Stable analytics names for the onboarding steps, index-aligned with the
/// pages built in `OnboardingPageViewScreen._buildPages`.
///
/// These are the *analytics* contract — Mixpanel funnels and saved reports key
/// off these strings, so renaming one silently breaks every historical report
/// built on it. Keep this list in step with `_buildPages`; [onboardingStepName]
/// falls back to a positional name if the two ever drift, so a mismatch
/// degrades to a usable event rather than crashing.
const List<String> kOnboardingStepNames = <String>[
  'connect_training',
  'user_profile',
  'sports_selection',
  'dietary_preference',
  'allergies',
];

/// Analytics name for the onboarding step at [index].
String onboardingStepName(int index) =>
    index >= 0 && index < kOnboardingStepNames.length
    ? kOnboardingStepNames[index]
    : 'step_$index';

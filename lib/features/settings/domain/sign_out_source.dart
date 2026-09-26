/// Where the athlete tapped Sign out. Settings and the paywall share one
/// sign-out path; the `settings_sign_out_tapped` event carries the entry as
/// `source`, so a paywall sign-out reads apart from one in Settings
/// (testing-wave 120-007).
enum SignOutSource {
  settings('settings'),
  paywall('paywall');

  const SignOutSource(this.analyticsValue);

  /// The event's `source` property.
  final String analyticsValue;
}

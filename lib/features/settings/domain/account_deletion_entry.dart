/// Where the athlete asked to delete their account. Settings and the
/// paywall's menu share one delete path; the analytics event names the
/// entry, so a new account deleting itself on the paywall reads apart from
/// a delete in Settings (testing-wave 04-001).
enum AccountDeletionEntry {
  settings('settings_delete_account_tapped'),
  paywall('paywall_delete_account_tapped');

  const AccountDeletionEntry(this.analyticsEvent);

  /// The event tracked when the delete starts.
  final String analyticsEvent;
}

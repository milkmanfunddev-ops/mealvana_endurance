/// Where the paywall lives in the router, as the gate and the write guard
/// know it. Application-level so a controller can open the paywall without
/// importing presentation; `pro_gate_redirect.dart` re-exports it for the
/// router and the screens.
library;

/// Where a closed account is sent, and stays: the full-screen paywall with
/// no close (mp-280, mp-611).
const String kPaywallPath = '/paywall';

/// The paywall as onboarding's last step. Same route, same full screen; the
/// query only records that onboarding opened it. Its ⋯ menu carries the same
/// entries as everywhere else (mp-494 §2, which replaced mp-417 §3's
/// "Restore only"). The gate's redirect still moves an open account on to
/// `/main`.
const String kOnboardingPaywallQuery = 'onboarding';
const String kOnboardingPaywallLocation =
    '$kPaywallPath?$kOnboardingPaywallQuery=1';

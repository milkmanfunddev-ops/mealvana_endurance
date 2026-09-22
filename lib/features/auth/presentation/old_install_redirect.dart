/// GoRouter redirect rule for an install left anonymous from before the
/// paywall (mp-455 §4, mp-417 §1).
///
/// The app never starts an anonymous session any more, so an anonymous
/// session on a signed-in route can only be an old install. It goes to the
/// account screen, where sign-up links onto that anonymous user (its data
/// survives) and the grace month is claimed. Pure, so it is unit-testable
/// without a router: `app_router.dart` asks it before the subscription gate.
library;

import '../../subscription/presentation/pro_gate_redirect.dart';

/// The account screen in its sign-up shape.
const String kOldInstallAccountLocation = '/auth/post-onboarding?mode=signup';

/// Where an [anonymous] session on [path] goes: the account screen from any
/// signed-in route; null (no redirect) otherwise. The open routes (welcome,
/// onboarding, auth, consent, force-upgrade) are left alone.
String? oldAnonymousInstallRedirect({
  required String path,
  required bool anonymous,
}) {
  if (!anonymous || isUngatedPath(path)) return null;
  return kOldInstallAccountLocation;
}

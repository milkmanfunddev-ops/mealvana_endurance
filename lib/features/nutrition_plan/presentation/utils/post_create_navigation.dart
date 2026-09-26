import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Post-success navigation for the athlete activity-creation flow.
///
/// After Create Plan succeeds, the creation flow must NOT stay on the back
/// stack: backing out of the new plan used to land on the still-armed
/// "Create New Activity Plan" form, and re-firing Generate -> Create inserted
/// a second identical activity (ops bug report
/// 2026-08-20-duplicate-activity-via-armed-back-stack.md). Two identical rows
/// at the same start also sit inside the +/-15-min platform-sync match window,
/// so a later sync upgrades an arbitrary one.
///
/// This helper unwinds the spent creation flow by resetting the stack to the
/// dashboard and pushing the new plan on top:
///
///   dashboard -> plan detail
///
/// so back (button or hardware) from the plan lands on the dashboard, never on
/// a re-fireable form. This mirrors the repo's existing post-success
/// conventions: the coach path already uses `context.go('/plan', ...)` and
/// Save Workout uses `context.go('/main')`.
///
/// The push waits for the `go` to land (Finding 116-011). The production
/// router's top-level `redirect` is `async`, so `go('/main')` applies on a
/// later microtask; a `push` issued in the same tick based itself on the
/// STALE stack and the form and Adjust Macros survived beneath the new plan.
/// The helper now pushes only once the router reports the dashboard as its
/// configuration, and gives up (leaving the athlete on the dashboard) if the
/// redirect sends them somewhere else.
///
/// Athlete flow only — the coach path keeps its own `go('/plan')` handling.
void showPlanAfterSuccessfulCreate(
  BuildContext context, {
  required String activityId,
  bool fromTemplate = false,
}) {
  final router = GoRouter.of(context);
  final delegate = router.routerDelegate;

  void pushPlan() {
    router.push(
      '/current-plan',
      extra: {
        'activityId': activityId,
        'isNewActivity': true,
        if (fromTemplate) 'fromTemplate': true,
      },
    );
  }

  bool onDashboard() =>
      delegate.currentConfiguration.uri.path == _dashboardLocation;

  // Reset the stack to the dashboard: this clears every pushed creation-flow
  // route (new-activity form, sport input screens, adjust-macros) in one
  // deterministic step, regardless of how deep the flow was or where it was
  // entered from.
  router.go(_dashboardLocation);

  // A synchronous parse (no async redirect) has already applied the go.
  if (onDashboard()) {
    pushPlan();
    return;
  }

  // Otherwise wait for the router to land on the dashboard, then push the
  // plan on top of the fresh stack. Runs at most once.
  late final VoidCallback listener;
  Timer? giveUp;
  var done = false;
  void finish({required bool push}) {
    if (done) return;
    done = true;
    delegate.removeListener(listener);
    giveUp?.cancel();
    if (push) pushPlan();
  }

  listener = () {
    if (onDashboard()) finish(push: true);
  };
  delegate.addListener(listener);
  giveUp = Timer(_landingTimeout, () => finish(push: false));
}

const _dashboardLocation = '/main';

/// How long the push waits for `go('/main')` to land before giving up. A
/// redirect that sends the athlete elsewhere (paywall, sign-in) never lands
/// on the dashboard, and the plan must not then be pushed over that screen.
const _landingTimeout = Duration(seconds: 5);

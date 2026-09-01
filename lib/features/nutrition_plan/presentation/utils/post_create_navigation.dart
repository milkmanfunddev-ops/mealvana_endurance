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
/// Athlete flow only — the coach path keeps its own `go('/plan')` handling.
void showPlanAfterSuccessfulCreate(
  BuildContext context, {
  required String activityId,
  bool fromTemplate = false,
}) {
  final router = GoRouter.of(context);
  // Reset the stack to the dashboard: this clears every imperatively pushed
  // creation-flow route (new-activity form, sport input screens,
  // adjust-macros) in one deterministic step, regardless of how deep the
  // flow was or where it was entered from.
  router.go('/main');
  // Then show the freshly created plan on top, so back pops to the dashboard.
  router.push(
    '/current-plan',
    extra: {
      'activityId': activityId,
      'isNewActivity': true,
      if (fromTemplate) 'fromTemplate': true,
    },
  );
}

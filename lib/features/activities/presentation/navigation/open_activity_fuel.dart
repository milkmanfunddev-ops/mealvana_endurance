import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../domain/activity.dart';

/// Opens the **Activity Detail** screen for [activity] (Lee, 2026-06-29 — a
/// workout tap should always land on Detail, not the New Activity screen). The
/// detail screen handles the no-plan case itself.
void openActivityFuel(BuildContext context, Activity activity) {
  context.push('/plan', extra: {'mode': 'view', 'activityId': activity.id});
}

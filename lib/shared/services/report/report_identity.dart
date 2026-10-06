/// Who the next Sentry event is about (ticket 02 of `.scratch/sentry/`).
///
/// Identity is the Supabase user id, a `role` tag (`athlete` or `coach`) and a
/// `device_id` tag; never an email. Called from the startup flow once the
/// deferred services are up and again on every sign-in; cleared on sign-out.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/coach_mode/data/coach_repository.dart';
import '../device_info_service.dart';
import '../supabase/supabase_client_provider.dart';
import 'report.dart';

/// Puts the signed-in user on every following event, or clears the user when
/// nobody is signed in. The coach lookup is best-effort: a failure leaves the
/// role unset and is reported as Degraded, never thrown.
Future<void> syncReportIdentity(Ref ref) async {
  final report = ref.read(reportProvider);
  final user = ref.read(supabaseClientProvider).auth.currentUser;
  if (user == null) {
    await report.clearUser();
    return;
  }

  String? role;
  try {
    final isCoach = await ref
        .read(coachRepositoryProvider)
        .isUserApprovedCoach(user.id);
    role = isCoach ? 'coach' : 'athlete';
  } catch (error, stackTrace) {
    await report.degraded(
      error,
      stackTrace: stackTrace,
      area: 'startup',
      message: 'Report identity: coach lookup failed; role left unset',
    );
  }

  // Device info is initialised by deferred startup; before that the tag
  // waits for the next sync rather than tripping the Android plugin deadlock.
  final deviceInfo = DeviceInfoService.instance;
  final deviceId = deviceInfo.isInitialized ? deviceInfo.deviceId : null;
  if (deviceId == null) {
    // Rule D9: the skipped tag is on the trail of the next event.
    report.breadcrumb(
      'Report identity: device info not ready; device_id tag deferred',
      category: 'startup',
    );
  }

  await report.setUser(user.id, role: role, deviceId: deviceId);
}

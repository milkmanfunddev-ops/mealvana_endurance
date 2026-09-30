import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The marketing version this build is actually running, e.g. `1.27.1`.
///
/// WHY THIS EXISTS. `users.app_version` was written once, at account creation,
/// from a hardcoded `'1.0.0'`. Every athlete on prod therefore reported
/// `1.0.0` — 330 of 330 — so the column could not answer the one question it
/// exists for: has this athlete taken the update? That blocked reading any
/// rollout, and in particular blocked closing a Critical, because a
/// client-side fix whose predicate fails cannot be told apart from an athlete
/// who simply has not updated (ops blueprint D7, standing precondition).
///
/// The BUILD NUMBER is deliberately left out. Fleet segmentation asks
/// "who is on >= 1.27.1", which wants an orderable marketing version;
/// TestFlight build numbers make that comparison awkward for no gain, and
/// Sentry already carries `version+buildNumber` for crash triage.
///
/// Overridden in tests — reading the platform channel in a unit test would
/// either hang or return the harness's own package.
final runningAppVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

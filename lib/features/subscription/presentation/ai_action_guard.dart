/// The AI-action check for screens the router never sees (mp-457 §3).
///
/// The router sends a closed account to the full-screen paywall, but a
/// screen reached by a plain page push, such as meal logging, calls AI from
/// a button. Each such button asks here first: true runs the action; false
/// has sent the app to the full-screen paywall instead (mp-611).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/pro_gate.dart';
import 'open_paywall.dart';

Future<bool> aiActionAllowed(BuildContext context, WidgetRef ref) async {
  if (await ref.read(writeAccessProvider.future)) return true;
  if (!context.mounted) return false;
  final router = GoRouter.maybeOf(context);
  if (router != null) openPaywall(router);
  return false;
}

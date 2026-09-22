/// The AI-action check for screens the router never sees (mp-457 §3).
///
/// The router sends a lapsed account's AI routes to the paywall
/// (`kAiRoutePrefixes`), but a screen reached by a plain page push, such as
/// meal logging, calls AI from a button. Each such button asks here first:
/// true runs the action; false has opened the paywall over the screen
/// instead, so the account can subscribe and come back.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/pro_gate.dart';
import 'pro_gate_redirect.dart';

Future<bool> aiActionAllowed(BuildContext context, WidgetRef ref) async {
  if (await ref.read(writeAccessProvider.future)) return true;
  if (context.mounted) unawaited(GoRouter.of(context).push(kPaywallPath));
  return false;
}

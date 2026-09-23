/// The host that sits above the router's Navigator (composed in
/// `MaterialApp.builder`, root_app_widget.dart) and opens the paywall
/// whenever a controller's refused write asks for it (mp-491).
///
/// It no longer shows the plan-ended bar: the gate answers open or closed,
/// and closed is the full-screen paywall with nothing behind it (mp-457,
/// mp-611), so there is no read-only screen to put a bar over. Ticket 20
/// deletes this host with the write guard it serves.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/write_guard.dart';
import 'open_paywall.dart';

class PlanEndedHost extends ConsumerWidget {
  const PlanEndedHost({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(paywallRequestsProvider, (_, _) => openPaywall(router));
    return child;
  }
}

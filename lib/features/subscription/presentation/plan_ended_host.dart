/// The read-only shell's one visible sign (mp-457 §3): while the gate
/// answers lapsed, every signed-in screen carries the plan-ended bar at the
/// top, and its Subscribe button opens the paywall over the screen. It also
/// opens the paywall whenever a controller's refused write asks for it.
///
/// Sits above the router's Navigator (composed in `MaterialApp.builder`,
/// root_app_widget.dart), so one bar covers every route — pushed pages,
/// sheets and dialogs included — without each screen placing it. The
/// widget is `PlanEndedBar` (kyle_design, spec
/// `docs/ssot/spec/design/components/plan-ended-bar.md`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/kyle_design/feedback/plan_ended_bar.dart';
import '../../content/application/content_service.dart';
import '../../content/domain/content_keys.dart';
import '../application/pro_gate.dart';
import '../application/write_guard.dart';
import '../domain/entitlement.dart';
import 'open_paywall.dart';
import 'pro_gate_redirect.dart';

class PlanEndedHost extends ConsumerStatefulWidget {
  const PlanEndedHost({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<PlanEndedHost> createState() => _PlanEndedHostState();
}

class _PlanEndedHostState extends ConsumerState<PlanEndedHost> {
  String _path = '';

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRoute);
    _path = topPathOf(widget.router.routerDelegate.currentConfiguration);
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  /// The router reports during its own build; this widget is above it, so
  /// it rebuilds after that frame instead of inside it.
  void _onRoute() {
    final next = topPathOf(widget.router.routerDelegate.currentConfiguration);
    if (next == _path || !mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _path = next);
      });
    } else {
      setState(() => _path = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A refused write in a controller asks for the paywall here, since this
    // is the one widget that always sits over the router (mp-491).
    ref.listen(paywallRequestsProvider, (_, _) => openPaywall(widget.router));
    final access = ref.watch(appGateProvider).value;
    final shown = access == AppAccess.lapsed && planEndedBarShownOn(_path);
    final media = MediaQuery.of(context);
    final content = ref.read(contentServiceProvider);
    // The page keeps one place in the tree whether or not the bar shows, so
    // an expiry or a resubscribe mid-session never remounts it.
    return Column(
      children: [
        if (shown)
          PlanEndedBar(
            topInset: media.padding.top,
            message: content.getValue(ContentKeys.planEndedMessage),
            subscribeLabel: content.getValue(
              ContentKeys.planEndedSubscribeButton,
            ),
            onSubscribe: () => openPaywall(widget.router),
          ),
        Expanded(
          key: const ValueKey('plan_ended_host.page'),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: shown,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

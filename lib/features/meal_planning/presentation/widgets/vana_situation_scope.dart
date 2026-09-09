import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/vana_situation_controller.dart';
import '../../domain/vana_situation.dart';

/// Tells Vana what this screen has in view.
///
/// Wrap a screen's body in one of these and Vana's next message carries the
/// route, the entity id, and the date, so "what should I eat before this" means
/// the session on screen. Ids only — never a name, never free text.
///
/// Reporting happens after the frame, so a screen can build its Situation from
/// state it resolved during build without a provider write inside build.
class VanaSituationScope extends ConsumerStatefulWidget {
  const VanaSituationScope({
    required this.situation,
    required this.child,
    super.key,
  });

  /// What this screen has in view. Null while the screen is still loading —
  /// nothing is reported until there is something to report.
  final VanaSituation? situation;

  final Widget child;

  @override
  ConsumerState<VanaSituationScope> createState() => _VanaSituationScopeState();
}

class _VanaSituationScopeState extends ConsumerState<VanaSituationScope> {
  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(covariant VanaSituationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.situation != widget.situation) _report();
  }

  void _report() {
    final s = widget.situation;
    if (s == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(vanaSituationControllerProvider.notifier).report(s);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

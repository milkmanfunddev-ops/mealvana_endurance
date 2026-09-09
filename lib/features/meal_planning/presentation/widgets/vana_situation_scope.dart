import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/vana_situation_controller.dart';
import '../../domain/vana_situation.dart';

/// Marks a subtree as on screen or not, for the benefit of any
/// [VanaSituationScope] inside it.
///
/// A tab shell builds every tab (an `IndexedStack` mounts all of its children
/// and paints one), so without this the offscreen tabs report their Situation
/// too and the last one to build wins. Wrap each tab child in one of these.
/// A scope with no ancestor is visible — a plain route is on screen by being
/// mounted at all.
class VanaSituationVisibility extends InheritedWidget {
  const VanaSituationVisibility({
    required this.visible,
    required super.child,
    super.key,
  });

  final bool visible;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<VanaSituationVisibility>()
          ?.visible ??
      true;

  @override
  bool updateShouldNotify(VanaSituationVisibility oldWidget) =>
      oldWidget.visible != visible;
}

/// Tells Vana what this screen has in view.
///
/// Wrap a screen's body in one of these and Vana's next message carries the
/// route, the entity id, and the date, so "what should I eat before this" means
/// the session on screen. Ids only — never a name, never free text.
///
/// Reporting happens after the frame, so a screen can build its Situation from
/// state it resolved during build without a provider write inside build. It
/// happens only while the subtree is visible ([VanaSituationVisibility]) and
/// only when there is something to report.
class VanaSituationScope extends ConsumerStatefulWidget {
  const VanaSituationScope({
    required this.situation,
    required this.child,
    super.key,
  });

  /// What this screen has in view. Null while the screen is still loading, or
  /// when it has nothing to say — nothing is reported either way.
  final VanaSituation? situation;

  final Widget child;

  @override
  ConsumerState<VanaSituationScope> createState() => _VanaSituationScopeState();
}

class _VanaSituationScopeState extends ConsumerState<VanaSituationScope> {
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = VanaSituationVisibility.of(context);
    final becameVisible = visible && !_visible;
    _visible = visible;
    // First build, or this subtree just came on screen.
    if (becameVisible || !_reportedOnce) _report();
  }

  bool _reportedOnce = false;

  @override
  void didUpdateWidget(covariant VanaSituationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.situation != widget.situation) _report();
  }

  void _report() {
    final s = widget.situation;
    if (s == null || !_visible) return;
    _reportedOnce = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_visible) return;
      ref.read(vanaSituationControllerProvider.notifier).report(s);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

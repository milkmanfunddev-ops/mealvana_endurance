/// The dev flavor's testing tools: the blue wrench (text scale, bold text,
/// colour-blindness simulation, locale, semantics debugger) and, in debug,
/// the red issue checker. Mounted by the app shell (`root_app_widget.dart`)
/// when the tester's Settings switch is on; prod never mounts it.
///
/// Where the button sits (finding 12-002, ticket 68): the package parks its
/// buttons in the bottom-right corner, which is Ask Vana's slot — a tap on
/// the launcher's centre opened the tools. The buttons now sit in the same
/// column, just above the launcher, so the corner keeps its control and no
/// other corner (date header, tab bar, back buttons) gains a stray one.
///
/// How, without a fork of the package: the overlay positions its buttons
/// with `SafeArea`, so this widget raises the bottom safe-area padding it
/// sees to [DevTestingTools.floor] and hands the app underneath its real
/// padding back. The tools panel shares the raised padding (a taller bottom
/// margin on a dev-only sheet) — the one cosmetic cost.
library;

import 'dart:math' as math;

import 'package:accessibility_tools/accessibility_tools.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/testing_tools/test_environment.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/testing_tools/testing_tools_panel.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/testing_tools/testing_tools_wrapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'kyle_design/navigation/vana_launcher.dart';

/// Tree order:
///
///     DevTestingTools (raised bottom padding)
///       └ AccessibilityTools / _ReleaseTestingTools
///           ├ TestingToolsWrapper(env override)
///           │   └ real padding restored → child
///           └ Overlay(panel + buttons)  ← reads the raised padding
///
/// Which button appears where:
///
/// | build              | blue wrench | red checker |
/// |--------------------|-------------|-------------|
/// | dev + debug        | yes         | yes         |
/// | dev + release      | yes         | no          |
///
/// The red checker is debug-only for a reason outside our control: its
/// checkers read `RenderObject.debugSemantics` and `debugCreator`, which
/// Flutter nulls out in release builds; `AccessibilityTools` itself
/// short-circuits to `child` when `!kDebugMode`. So the release path mounts
/// the half of the package that does work outside debug — the wrapper and
/// the wrench panel — behind a button drawn to match the package's own.
class DevTestingTools extends StatelessWidget {
  const DevTestingTools({
    super.key,
    required this.child,
    this.withIssueChecker = kDebugMode,
  });

  final Widget child;

  /// Mount the package's own overlay (wrench + red checker). Only renders in
  /// debug builds; tests pass false to exercise the release overlay.
  final bool withIssueChecker;

  /// The bottom safe-area padding the tools overlay is shown: the launcher's
  /// top edge (vana_companion.dart places it at [VanaLauncher.bottomInset]).
  /// The overlay's own spacing above `SafeArea` is the gap.
  static const double floor = VanaLauncher.bottomInset + VanaLauncher.size;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final raised = mq.copyWith(
      padding: mq.padding.copyWith(
        bottom: math.max(mq.padding.bottom, floor),
      ),
      viewPadding: mq.viewPadding.copyWith(
        bottom: math.max(mq.viewPadding.bottom, floor),
      ),
    );
    // The wrapper's MediaQuery (text scale, bold text) sits between the
    // overlay and the app, so the app's real padding goes back on top of it.
    final app = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: mq.padding, viewPadding: mq.viewPadding),
        child: child,
      ),
    );
    return MediaQuery(
      data: raised,
      child: withIssueChecker
          ? _DebugAccessibilityTools(child: app)
          : _ReleaseTestingTools(child: app),
    );
  }
}

/// Debug-only wrapper around [AccessibilityTools] that **resets the panel's
/// state on every hot reload** by re-keying the widget.
///
/// Why: the package keeps its `TestEnvironment` (text scale, color mode,
/// locale override, etc.) in `_AccessibilityToolsState`. Plain `setState`
/// changes survive hot reload, which made the app stick at e.g. 3.1× text
/// scale or grayscale between iterations with no obvious way to reset.
///
/// `reassemble` fires on every hot reload; bumping a counter and using it
/// as the child's key forces Flutter to dispose the old `AccessibilityTools`
/// and create a fresh one — wiping any panel overrides. Cold launches are
/// also fresh because widget state starts empty. The re-key remounts the
/// subtree down to the router's Navigator, whose GlobalKey keeps its routes.
class _DebugAccessibilityTools extends StatefulWidget {
  const _DebugAccessibilityTools({required this.child});

  final Widget child;

  @override
  State<_DebugAccessibilityTools> createState() =>
      _DebugAccessibilityToolsState();
}

class _DebugAccessibilityToolsState extends State<_DebugAccessibilityTools> {
  int _resetGeneration = 0;

  @override
  void reassemble() {
    super.reassemble();
    _resetGeneration++;
  }

  @override
  Widget build(BuildContext context) {
    return AccessibilityTools(
      key: ValueKey('accessibility-tools-$_resetGeneration'),
      // Silence the per-rebuild console report (it flooded the logs and buried
      // real errors). The on-screen overlay + testing panel still work.
      logLevel: LogLevel.none,
      child: widget.child,
    );
  }
}

/// The wrench panel for **release** builds (the installed dev app),
/// reproducing the package's own overlay structure so QA sees identical
/// chrome on device and in simulator.
class _ReleaseTestingTools extends StatefulWidget {
  const _ReleaseTestingTools({required this.child});

  final Widget child;

  @override
  State<_ReleaseTestingTools> createState() => _ReleaseTestingToolsState();
}

class _ReleaseTestingToolsState extends State<_ReleaseTestingTools> {
  TestEnvironment _environment = const TestEnvironment();
  bool _panelVisible = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // Inserts its own MediaQuery/Theme between the clamp and the app, so
        // panel overrides reach app content while panel chrome stays clamped.
        TestingToolsWrapper(environment: _environment, child: widget.child),
        Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => Positioned(
                right: 10,
                bottom: 10,
                child: SafeArea(
                  child: _TestingToolsButton(
                    onPressed: () =>
                        setState(() => _panelVisible = !_panelVisible),
                  ),
                ),
              ),
            ),
            OverlayEntry(
              builder: (context) {
                if (!_panelVisible) return const SizedBox();
                return TestingToolsPanel(
                  environment: _environment,
                  onClose: () => setState(() => _panelVisible = false),
                  onEnvironmentUpdate: (environment) =>
                      setState(() => _environment = environment),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Blue wrench button. Matches the package's own `AccessibilityToolsToggle`
/// (which lives in `src/` and isn't exported) so the two build modes look the
/// same; its blue is the package's, not a brand colour.
class _TestingToolsButton extends StatelessWidget {
  const _TestingToolsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const label = 'Open testing tools';
    return SizedBox.square(
      dimension: 48,
      child: Tooltip(
        message: label,
        child: FloatingActionButton(
          onPressed: onPressed,
          shape: const CircleBorder(),
          elevation: 10,
          hoverElevation: 10,
          backgroundColor: Colors.blue,
          child: const Icon(
            Icons.build,
            size: 24,
            color: Colors.white,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}

/// The dev flavor's testing tools: the wrench panel (text scale, bold text,
/// colour-blindness simulation, locale, semantics debugger) and, in debug,
/// the accessibility issue checker. Mounted by the app shell
/// (`root_app_widget.dart`) when the tester's Settings switch is on; prod
/// never mounts it.
///
/// One small pill at the top edge (testing-wave 100-001, 118-001, ticket
/// 141). The package's two 48pt buttons sat in the bottom-right column and
/// covered whatever a screen docked there: Ask Vana (12-002), then the right
/// end of every full-width bottom button and a sheet row's ⋮ menu. Every
/// corner at AppBar height belongs to a control (back buttons left, actions
/// and the date header's gear right, the date title in the middle), so the
/// pill hugs the very top edge: 18pt tall, straddling the status bar's empty
/// bottom strip and the first 10pt under it, which is above where the date
/// header's row (top padding 10) and an AppBar's title glyphs begin. A tap
/// offers both tools; in a release build, where the checker cannot run, it
/// opens the wrench panel straight away.
///
/// The pill is left out of the semantics tree on purpose: at 18pt it would
/// fail the checker's own tap-target rule on every screen, and a dev-only
/// control is not what VoiceOver testers are auditing. The menu it opens is
/// made of named 48pt buttons.
///
/// The package's overlay is not used at all any more (it draws its own two
/// buttons with no way to fold them); its checkers, wrapper and panel are
/// mounted from `src/` here, as the release path already did for the panel.
library;

import 'dart:math' as math;

import 'package:accessibility_tools/accessibility_tools.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/accessibility_issue.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/checker_manager.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/checkers/checker_base.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/checkers/image_label_checker.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/checkers/input_label_checker.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/checkers/minimum_tap_area_checker.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/checkers/mixin.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/checkers/semantic_label_checker.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/floating_action_buttons.dart'
    show toolsBoxMinSize;
// ignore: implementation_imports
import 'package:accessibility_tools/src/testing_tools/test_environment.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/testing_tools/testing_tools_panel.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/testing_tools/testing_tools_wrapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Tree order:
///
///     DevTestingTools
///       └ _DevToolsOverlay
///           ├ TestingToolsWrapper(env override) → child
///           └ Overlay
///               ├ _CheckerHost (debug: the issue rects)
///               ├ the pill, and its menu while open
///               └ TestingToolsPanel while open
///
/// Which tool the pill offers where:
///
/// | build              | wrench panel | issue checker |
/// |--------------------|--------------|---------------|
/// | dev + debug        | yes          | yes           |
/// | dev + release      | yes          | no            |
///
/// The checker is debug-only for a reason outside our control: its checkers
/// read `RenderObject.debugSemantics` and `debugCreator`, which Flutter
/// nulls out in release builds.
class DevTestingTools extends StatelessWidget {
  const DevTestingTools({
    super.key,
    required this.child,
    this.withIssueChecker = kDebugMode,
  });

  final Widget child;

  /// Run the accessibility checker and offer it from the pill. Only works in
  /// debug builds; tests pass it explicitly to exercise both shapes.
  final bool withIssueChecker;

  /// The pill's size and how far it reaches up into the status bar strip.
  static const double pillWidth = 48;
  static const double pillHeight = 18;
  static const double pillOverlap = 8;

  /// The pill's top edge for a screen with [topPadding] of status bar.
  static double pillTop(double topPadding) =>
      math.max(0, topPadding - pillOverlap);

  static const Key pillKey = ValueKey('dev_tools.pill');
  static const Key toolsMenuKey = ValueKey('dev_tools.menu_tools');
  static const Key issuesMenuKey = ValueKey('dev_tools.menu_issues');

  @override
  Widget build(BuildContext context) {
    return _DevToolsOverlay(withIssueChecker: withIssueChecker, child: child);
  }
}

class _DevToolsOverlay extends StatefulWidget {
  const _DevToolsOverlay({required this.withIssueChecker, required this.child});

  final bool withIssueChecker;
  final Widget child;

  @override
  State<_DevToolsOverlay> createState() => _DevToolsOverlayState();
}

class _DevToolsOverlayState extends State<_DevToolsOverlay> {
  TestEnvironment _environment = const TestEnvironment();
  bool _panelVisible = false;
  bool _menuOpen = false;
  bool _issuesVisible = false;

  /// Built once the theme is known (the tap-area rule is per platform).
  CheckerManager? _checker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.withIssueChecker || _checker != null) return;
    _checker = CheckerManager(
      checkers: [
        SemanticLabelChecker(),
        MinimumTapAreaChecker(
          minTapArea: MinimumTapAreas.material.forPlatform(
            Theme.of(context).platform,
          ),
        ),
        InputLabelChecker(),
        ImageLabelChecker(),
      ],
      // Silence the per-rebuild console report (it flooded the logs and
      // buried real errors). The on-screen rects still work.
      logLevel: LogLevel.none,
    );
  }

  /// Hot reload resets the panel's overrides. The package kept its
  /// `TestEnvironment` across reloads, which stuck the app at e.g. 3.1× text
  /// scale or grayscale between iterations with no obvious way back.
  @override
  void reassemble() {
    super.reassemble();
    _environment = const TestEnvironment();
    _panelVisible = false;
    _menuOpen = false;
  }

  @override
  void dispose() {
    _checker?.dispose();
    super.dispose();
  }

  void _onPillTap() {
    setState(() {
      if (_checker == null) {
        // One tool: straight to it.
        _panelVisible = !_panelVisible;
        _menuOpen = false;
      } else if (_panelVisible) {
        _panelVisible = false;
      } else {
        _menuOpen = !_menuOpen;
      }
    });
  }

  void _openPanel() => setState(() {
    _menuOpen = false;
    _issuesVisible = false;
    _panelVisible = true;
  });

  void _toggleIssues() => setState(() {
    _menuOpen = false;
    _panelVisible = false;
    _issuesVisible = !_issuesVisible;
  });

  @override
  Widget build(BuildContext context) {
    final checker = _checker;
    final topPadding = MediaQuery.paddingOf(context).top;
    final pillTop = DevTestingTools.pillTop(topPadding);
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // Inserts its own MediaQuery/Theme between the shell's clamp and the
        // app, so panel overrides reach app content while panel chrome stays
        // clamped.
        TestingToolsWrapper(environment: _environment, child: widget.child),
        Overlay(
          initialEntries: [
            if (checker != null)
              OverlayEntry(
                builder: (_) =>
                    _CheckerHost(checker: checker, showIssues: _issuesVisible),
              ),
            OverlayEntry(
              builder: (context) => Stack(
                children: [
                  Positioned(
                    top: pillTop,
                    left: 0,
                    right: 0,
                    child: Center(child: _DevToolsPill(onTap: _onPillTap)),
                  ),
                  if (_menuOpen)
                    Positioned(
                      top: pillTop + DevTestingTools.pillHeight + 6,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _DevToolsMenu(
                          checker: checker,
                          issuesVisible: _issuesVisible,
                          onTools: _openPanel,
                          onIssues: _toggleIssues,
                        ),
                      ),
                    ),
                ],
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

/// The one dev control: a 48×18 blue pill with the wrench. Out of the
/// semantics tree (see the library comment).
class _DevToolsPill extends StatelessWidget {
  const _DevToolsPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: GestureDetector(
        key: DevTestingTools.pillKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: DevTestingTools.pillWidth,
          height: DevTestingTools.pillHeight,
          decoration: BoxDecoration(
            // The package's own blue, not a brand colour.
            color: Colors.blue,
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: const Icon(Icons.build, size: 12, color: Colors.white),
        ),
      ),
    );
  }
}

/// The two tools, as named 48pt buttons stacked under the pill.
class _DevToolsMenu extends StatelessWidget {
  const _DevToolsMenu({
    required this.checker,
    required this.issuesVisible,
    required this.onTools,
    required this.onIssues,
  });

  final CheckerManager? checker;
  final bool issuesVisible;
  final VoidCallback onTools;
  final VoidCallback onIssues;

  @override
  Widget build(BuildContext context) {
    final checker = this.checker;
    // Stacked, not side by side: the labels are long and the row is a phone.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DevToolsMenuButton(
          key: DevTestingTools.toolsMenuKey,
          label: 'Open testing tools',
          icon: Icons.build,
          color: Colors.blue,
          onTap: onTools,
        ),
        if (checker != null) ...[
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: checker,
            builder: (context, _) {
              final count = checker.issues.length;
              final noun = count == 1 ? 'issue' : 'issues';
              return _DevToolsMenuButton(
                key: DevTestingTools.issuesMenuKey,
                label: issuesVisible
                    ? 'Hide accessibility issues'
                    : 'Show $count accessibility $noun',
                icon: Icons.accessibility_new,
                color: count == 0 ? Colors.green : Colors.red,
                onTap: onIssues,
              );
            },
          ),
        ],
      ],
    );
  }
}

class _DevToolsMenuButton extends StatelessWidget {
  const _DevToolsMenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: Material(
        color: color,
        elevation: 6,
        borderRadius: BorderRadius.circular(toolsBoxMinSize / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(toolsBoxMinSize / 2),
          onTap: onTap,
          child: ExcludeSemantics(
            child: Container(
              height: toolsBoxMinSize,
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Runs the checkers whenever the semantics tree changes and, when asked,
/// draws the package's warning box over every issue. The same scan the
/// package's `AccessibilityTools` ran, without its buttons.
class _CheckerHost extends StatefulWidget {
  const _CheckerHost({required this.checker, required this.showIssues});

  final CheckerManager checker;
  final bool showIssues;

  @override
  State<_CheckerHost> createState() => _CheckerHostState();
}

class _CheckerHostState extends State<_CheckerHost> with SemanticUpdateMixin {
  @override
  void didUpdateSemantics() {
    // Semantics are only available at the end of a frame; the next frame is
    // the first chance to paint them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.checker.update();
    });
  }

  static Rect _inflateToMinimumSize(Rect rect) {
    if (rect.shortestSide < toolsBoxMinSize) {
      return Rect.fromCenter(
        center: rect.center,
        width: math.max(toolsBoxMinSize, rect.width),
        height: math.max(toolsBoxMinSize, rect.height),
      );
    }
    return rect;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.checker,
      builder: (context, _) {
        if (!widget.showIssues) return const SizedBox.shrink();
        final rects = <Rect, List<AccessibilityIssue>>{};
        for (final issue in widget.checker.issues) {
          if (!issue.renderObject.attached) continue;
          rects.putIfAbsent(issue.renderObject.getGlobalRect(), () => []).add(
            issue,
          );
        }
        const errorBorderWidth = 5.0;
        return Stack(
          children: [
            for (final entry in rects.entries)
              Positioned.fromRect(
                rect: _inflateToMinimumSize(
                  entry.key,
                ).inflate(errorBorderWidth),
                child: WarningBox(
                  borderWidth: errorBorderWidth,
                  message: entry.value.map((e) => e.message).join('\n\n'),
                  size: Size(
                    math.max(5, entry.key.width) + errorBorderWidth,
                    math.max(5, entry.key.height) + errorBorderWidth,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

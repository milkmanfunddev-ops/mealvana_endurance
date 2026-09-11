import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shake/shake.dart';

import '../../features/content/application/content_service.dart';
import '../../features/content/domain/content_keys.dart';
import '../../theme/kyle_design/app_colors.dart';
import '../../theme/kyle_design/app_spacing.dart';
import '../../theme/kyle_design/app_text_styles.dart';
import 'kyle_design/buttons/primary_button.dart';
import 'kyle_design/buttons/secondary_button.dart';

/// Shake-the-phone entry point for the feedback tool.
///
/// Wraps the running app; on a device shake it asks "Report a problem?" in a
/// bottom sheet and, on confirm, invokes [onReport] (Wiredash in production).
/// The sheet is deliberate: athletes shake phones while running and riding,
/// so a bare shake must never open the feedback overlay by itself.
///
/// Guards, in order:
/// - app must be in the foreground (`AppLifecycleState.resumed`)
/// - nothing already open: neither our sheet nor [reportVisible]
/// - one trigger per [cooldown]
///
/// [shakeEvents] injects a shake source for tests; when null the widget
/// listens to the accelerometer via `package:shake`.
class ShakeToReport extends ConsumerStatefulWidget {
  const ShakeToReport({
    super.key,
    required this.navigatorKey,
    required this.onReport,
    required this.child,
    this.reportVisible,
    this.onShakeDetected,
    this.shakeEvents,
    this.cooldown = const Duration(seconds: 3),
    this.enabled = true,
  });

  /// Root navigator: the sheet needs a Navigator, and this widget mounts
  /// above the router's.
  final GlobalKey<NavigatorState> navigatorKey;

  /// Opens the feedback tool. Receives the navigator's context.
  final Future<void> Function(BuildContext context) onReport;

  /// True while the feedback tool is already showing; shakes are ignored.
  final ValueListenable<bool>? reportVisible;

  /// Analytics hook, fired once per handled shake.
  final void Function(String event)? onShakeDetected;

  final Stream<void>? shakeEvents;
  final Duration cooldown;
  final bool enabled;
  final Widget child;

  @override
  ConsumerState<ShakeToReport> createState() => _ShakeToReportState();
}

class _ShakeToReportState extends ConsumerState<ShakeToReport>
    with WidgetsBindingObserver {
  ShakeDetector? _detector;
  StreamSubscription<void>? _subscription;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  DateTime? _lastHandled;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    if (!widget.enabled) return;
    if (widget.shakeEvents != null) {
      _subscription = widget.shakeEvents!.listen((_) => _onShake());
    } else if (!kIsWeb) {
      _detector = ShakeDetector.autoStart(
        onPhoneShake: (_) => _onShake(),
        // Higher than the package default (2.7g) so a jog doesn't trigger it;
        // a deliberate shake comfortably exceeds 3g.
        shakeThresholdGravity: 3.2,
        minimumShakeCount: 2,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _detector?.stopListening();
    super.dispose();
  }

  void _onShake() {
    if (!mounted || _lifecycle != AppLifecycleState.resumed) return;
    if (_sheetOpen || (widget.reportVisible?.value ?? false)) return;
    final now = DateTime.now();
    if (_lastHandled != null &&
        now.difference(_lastHandled!) < widget.cooldown) {
      return;
    }
    _lastHandled = now;
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) return;
    widget.onShakeDetected?.call('shake_report_prompted');
    unawaited(_showSheet(navContext));
  }

  Future<void> _showSheet(BuildContext navContext) async {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(navContext).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    _sheetOpen = true;
    final confirmed = await showModalBottomSheet<bool>(
      context: navContext,
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.getValue(ContentKeys.shakeReportTitle),
                key: const ValueKey('shake_report.title'),
                style: AppTextStyles.sectionTitle.copyWith(
                  color: textColor,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                content.getValue(ContentKeys.shakeReportBody),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: textColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              KylePrimaryButton(
                key: const ValueKey('shake_report.confirm'),
                text: content.getValue(ContentKeys.shakeReportConfirm),
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: AppSpacing.xs),
              KyleSecondaryButton(
                key: const ValueKey('shake_report.dismiss'),
                text: content.getValue(ContentKeys.shakeReportDismiss),
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    _sheetOpen = false;
    if (!mounted) return;

    if (confirmed == true) {
      widget.onShakeDetected?.call('shake_report_confirmed');
      // The sheet has popped by now, so the feedback tool's screenshot shows
      // the screen the user was on, not our prompt.
      final ctx = widget.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) await widget.onReport(ctx);
    } else {
      widget.onShakeDetected?.call('shake_report_dismissed');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

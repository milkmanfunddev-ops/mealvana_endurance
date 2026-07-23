import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/pin_decision.dart';

/// One row in the expanded banner — represents a phase / sub-phase that had a
/// [PinDecision] attached during plan generation.
class PinStatusBannerRow {
  const PinStatusBannerRow({required this.label, required this.decision});

  /// Display label for the phase: "Meal", "Snack", "Top-Off", "During".
  final String label;

  /// The pin decision for this phase. Drives icon + colour per row.
  final PinDecision decision;
}

/// Activity-detail banner that surfaces Formula Kit pin honoring telemetry.
///
/// Visible only when the plan was generated with pins supplied (i.e. the
/// algorithm emitted at least one [PinDecision]). Collapsed by default with
/// a one-line summary; expanding reveals per-phase rows showing which
/// pinned formula was honored (or the fallback reason) plus a quick-link
/// CTA into the Formula Library.
///
/// Formula Kit PR 2 substep 9.
class PinStatusBanner extends StatefulWidget {
  const PinStatusBanner({
    super.key,
    required this.rows,
    this.isOnboarding = false,
    this.onExpanded,
    this.onFormulaLibraryTapped,
  });

  /// All phase rows with a non-null [PinDecision], in display order.
  /// Empty when [isOnboarding] is true; non-empty otherwise (caller filters
  /// the Hidden state before mounting).
  final List<PinStatusBannerRow> rows;

  /// When true, the banner renders the zero-pin onboarding state: a
  /// discovery prompt with a CTA into the Formula Library, no row list.
  /// Collapsible like Status mode (header only by default; tap to reveal
  /// subtext + CTA). [rows] is ignored (and expected empty).
  final bool isOnboarding;

  /// Fired the first time the user expands the banner. Owner emits the
  /// `pin_status_banner_expanded` analytics event. Fires in both Status
  /// and Onboarding modes.
  final VoidCallback? onExpanded;

  /// Fired when the user taps "Browse Formula Library →". Owner emits the
  /// `pin_status_banner_formula_library_tapped` analytics event and may
  /// override default navigation; if null, the banner navigates itself
  /// to `/settings/food-preferences/formula-library`.
  final VoidCallback? onFormulaLibraryTapped;

  @override
  State<PinStatusBanner> createState() => _PinStatusBannerState();
}

class _PinStatusBannerState extends State<PinStatusBanner>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _hasFiredExpandedAnalytics = false;
  late final AnimationController _chevronController;

  @override
  void initState() {
    super.initState();
    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _chevronController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _chevronController.forward();
        if (!_hasFiredExpandedAnalytics) {
          _hasFiredExpandedAnalytics = true;
          widget.onExpanded?.call();
        }
      } else {
        _chevronController.reverse();
      }
    });
  }

  void _handleFormulaLibraryTap() {
    widget.onFormulaLibraryTapped?.call();
    // If owner didn't override, navigate ourselves. Owner can also do both
    // — analytics emission + navigation — by passing a callback that calls
    // context.go itself; in that case the default below is harmless since
    // the owner's callback fires synchronously above.
    if (widget.onFormulaLibraryTapped == null) {
      // push (not go) so the AppBar back button pops back to the activity.
      context.push('/settings/food-preferences/formula-library');
    }
  }

  bool get _hasAnyFallthrough => widget.rows.any((r) => !r.decision.usedPin);

  bool get _hasAnyHonored => widget.rows.any((r) => r.decision.usedPin);

  /// Rows where the user authored a formula for the phase that didn't apply.
  /// Drives the "?" affordance — this is the case the banner was previously
  /// silent about (audit 2026-07-18).
  List<PinStatusBannerRow> get _skippedRows => widget.rows
      .where((r) => r.decision.hasSkippedFormulas)
      .toList(growable: false);

  bool get _hasSkippedFormulas => _skippedRows.isNotEmpty;

  /// Human sentence for one skipped formula. Falls back to a generic line for
  /// an unrecognised reason so a future server-side reason never renders blank.
  String _skipExplanation(SkippedPersonalFormula f) {
    switch (f.reason) {
      case SkippedFormulaReason.durationOutOfScope:
        final targets = f.formulaDurations.isEmpty
            ? 'a different workout length'
            : f.formulaDurations.join(', ');
        final bracket = f.workoutBracket;
        return bracket == null
            ? '“${f.name}” is set for $targets, which doesn\'t match this '
                  'workout\'s length.'
            : '“${f.name}” is set for $targets. This workout falls in '
                  '$bracket, so it wasn\'t used.';
      case SkippedFormulaReason.activityOutOfScope:
        return '“${f.name}” isn\'t set up for this activity type.';
      case null:
        return '“${f.name}” didn\'t match this workout.';
    }
  }

  void _showSkipDetails() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Why your formula wasn\'t used',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Theme.of(sheetContext).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final row in _skippedRows) ...[
                Text(
                  row.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                for (final f in row.decision.skippedPersonalFormulas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      _skipExplanation(f),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(
                          sheetContext,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                'You can widen the workout lengths or activities a formula '
                'covers by editing it in your Formula Library.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                key: const ValueKey('pin_status_banner.skip_details_cta'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _handleFormulaLibraryTap();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Edit in Formula Library',
                        style: AppTextStyles.buttonPrimary.copyWith(
                          color: Theme.of(sheetContext).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Theme.of(sheetContext).colorScheme.onSurface,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Accent colour drives the entire banner tone. All success → teal,
  /// otherwise orange (mixed states still read as "needs attention").
  /// A skipped personal formula counts as "needs attention" even when a
  /// system pin fired — the user did not get what they authored.
  Color get _accentColor => (_hasAnyFallthrough || _hasSkippedFormulas)
      ? AppColors.warning
      : AppColors.electrolyte;

  String get _headerTitle {
    // Checked FIRST: a skipped personal formula must never render as an
    // unqualified success, even when something else was honored. That
    // mismatch is exactly what made "my formula was ignored" invisible.
    if (_hasSkippedFormulas) return 'Your formula didn\'t apply here';
    if (!_hasAnyHonored) return 'Pin didn\'t apply to this workout';
    if (!_hasAnyFallthrough) return 'Using your pinned formulas';
    return 'Some pins honored, some skipped';
  }

  String get _headerSubtitle {
    if (_hasSkippedFormulas) {
      final count = _skippedRows
          .expand((r) => r.decision.skippedPersonalFormulas)
          .length;
      return count == 1
          ? '1 of your formulas was skipped — tap ? for why'
          : '$count of your formulas were skipped — tap ? for why';
    }
    final honoredCount = widget.rows.where((r) => r.decision.usedPin).length;
    final skippedCount = widget.rows.length - honoredCount;
    if (skippedCount == 0) {
      return honoredCount == 1 ? '1 pin honored' : '$honoredCount pins honored';
    }
    if (honoredCount == 0) {
      return 'No in-scope pin for this activity';
    }
    return '$honoredCount honored · $skippedCount skipped';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOnboarding) {
      return _buildOnboardingBanner(context);
    }
    return _buildStatusBanner(context);
  }

  /// Zero-pin onboarding variant: discovery prompt + CTA. Collapsible —
  /// default state shows just the header row to keep the activity-detail
  /// screen compact; expanding reveals the subtext + CTA.
  Widget _buildOnboardingBanner(BuildContext context) {
    // Use the neutral accent (electrolyte teal) — onboarding isn't a
    // warning state.
    const accent = AppColors.electrolyte;
    return Container(
      key: const ValueKey('pin_status_banner.onboarding'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (tappable to expand/collapse)
          InkWell(
            key: const ValueKey('pin_status_banner.onboarding_header'),
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.push_pin_outlined, color: accent, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Pin formulas you love',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: Tween<double>(
                      begin: 0.0,
                      end: 0.5,
                    ).animate(_chevronController),
                    child: Icon(
                      Icons.expand_more,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded body — subtext + CTA
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(
                          color: accent.withValues(alpha: 0.25),
                          height: 1,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          "We'll use them whenever they fit your activity.",
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildFormulaLibraryCta(),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Status variant (existing): collapsible header + per-phase row list + CTA.
  Widget _buildStatusBanner(BuildContext context) {
    final accent = _accentColor;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (tappable to expand/collapse)
          InkWell(
            key: const ValueKey('pin_status_banner.header'),
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    _hasAnyFallthrough && !_hasAnyHonored
                        ? Icons.push_pin_outlined
                        : Icons.push_pin,
                    color: accent,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _headerTitle,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          _headerSubtitle,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // "?" affordance — only when the user authored a formula
                  // for a phase that didn't apply. Without this the banner
                  // can read "pinned formula used" while the user's own
                  // formula was silently dropped (audit 2026-07-18).
                  if (_hasSkippedFormulas)
                    IconButton(
                      key: const ValueKey(
                        'pin_status_banner.skip_details_button',
                      ),
                      onPressed: _showSkipDetails,
                      icon: Icon(
                        Icons.help_outline,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      tooltip: 'Why your formula wasn\'t used',
                    ),
                  RotationTransition(
                    turns: Tween<double>(
                      begin: 0.0,
                      end: 0.5,
                    ).animate(_chevronController),
                    child: Icon(
                      Icons.expand_more,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded body
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(
                          color: accent.withValues(alpha: 0.25),
                          height: 1,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...widget.rows.map(_buildRow),
                        const SizedBox(height: AppSpacing.sm),
                        _buildFormulaLibraryCta(),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(PinStatusBannerRow row) {
    final honored = row.decision.usedPin;
    final rowColor = honored ? AppColors.electrolyte : AppColors.warning;
    // Non-honored row copy is a three-way:
    //   reason == pinnedTemplateUnrenderable → pin matched scope but a required
    //     ingredient was missing from the food pool (PR 3 #35 guard).
    //   pin_set_size  > 0                    → pins existed in scope, but the
    //     solver still picked a non-pinned candidate.
    //   pin_set_size == 0                    → user has no pins for this scope.
    final templateLabel = honored
        ? (row.decision.pinnedTemplateName ?? 'Pinned formula')
        : (row.decision.fallthroughReason ==
                  PinFallthroughReason.pinnedTemplateUnrenderable
              ? 'Pin ingredient unavailable'
              : row.decision.fallthroughReason ==
                    PinFallthroughReason.personalFormulaEmpty
              ? 'Pinned formula is empty'
              : row.decision.pinSetSize > 0
              ? 'Pins fell through'
              : 'No pin found');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            honored ? Icons.check_circle_outline : Icons.info_outline,
            color: rowColor,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 72,
            child: Text(
              row.label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              templateLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: honored
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaLibraryCta() {
    return GestureDetector(
      key: const ValueKey('pin_status_banner.formula_library_cta'),
      onTap: _handleFormulaLibraryTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _accentColor.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Pin your favorite formula',
              style: AppTextStyles.buttonPrimary.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.arrow_forward,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/pin_decision.dart';

/// One row in the expanded banner — represents a phase / sub-phase that had a
/// [PinDecision] attached during plan generation.
class PinStatusBannerRow {
  const PinStatusBannerRow({
    required this.label,
    required this.decision,
  });

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

  bool get _hasAnyFallthrough =>
      widget.rows.any((r) => !r.decision.usedPin);

  bool get _hasAnyHonored =>
      widget.rows.any((r) => r.decision.usedPin);

  /// Accent colour drives the entire banner tone. All success → teal,
  /// otherwise orange (mixed states still read as "needs attention").
  Color get _accentColor =>
      _hasAnyFallthrough ? AppColors.warning : AppColors.electrolyte;

  String get _headerTitle {
    if (!_hasAnyHonored) return 'Pin didn\'t apply to this workout';
    if (!_hasAnyFallthrough) return 'Using your pinned formulas';
    return 'Some pins honored, some skipped';
  }

  String get _headerSubtitle {
    final honoredCount =
        widget.rows.where((r) => r.decision.usedPin).length;
    final skippedCount = widget.rows.length - honoredCount;
    if (skippedCount == 0) {
      return honoredCount == 1
          ? '1 pin honored'
          : '$honoredCount pins honored';
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
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
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
                  const Icon(
                    Icons.push_pin_outlined,
                    color: accent,
                    size: 22,
                  ),
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
                    turns: Tween<double>(begin: 0.0, end: 0.5).animate(
                      _chevronController,
                    ),
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns:
                        Tween<double>(begin: 0.0, end: 0.5).animate(
                      _chevronController,
                    ),
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
    final rowColor =
        honored ? AppColors.electrolyte : AppColors.warning;
    // Two-state copy for non-honored rows:
    //   pin_set_size == 0 → user has no pins for this scope → "No pin found"
    //   pin_set_size  > 0 → pins existed but none selected → "Pins fell through"
    // In V1 the only fallthrough reason is `no_pin_for_scope`, so almost every
    // non-honored row renders as "No pin found"; the second branch is wired
    // forward-compat for future fallthrough reasons (allergen, season, etc.).
    final templateLabel = honored
        ? (row.decision.pinnedTemplateName ?? 'Pinned formula')
        : (row.decision.pinSetSize > 0
            ? 'Pins fell through'
            : 'No pin found');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            honored
                ? Icons.check_circle_outline
                : Icons.info_outline,
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

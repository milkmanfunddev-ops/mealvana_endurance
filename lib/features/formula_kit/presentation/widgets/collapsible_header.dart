import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

/// Animated wrapper that collapses (height → 0, opacity → 0) when
/// [collapsed] is true. Mirrors the design's `CollapsibleHeader`.
///
/// Wraps the Formula Library's phase tabs + per-phase chip rows so that
/// scrolling the list down hides them, freeing vertical real estate.
class CollapsibleHeader extends StatelessWidget {
  const CollapsibleHeader({
    super.key,
    required this.collapsed,
    required this.child,
  });

  final bool collapsed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        opacity: collapsed ? 0 : 1,
        child: collapsed
            ? const SizedBox(width: double.infinity, height: 0)
            : child,
      ),
    );
  }
}

/// Compact sticky strip shown when the [CollapsibleHeader] is collapsed.
///
/// Tapping it re-expands the header. Surfaces the active phase, any active
/// chip filters, and the visible row count so the user retains context after
/// the header retracts.
class CollapsedStrip extends StatelessWidget {
  const CollapsedStrip({
    super.key,
    required this.phaseLabel,
    required this.activeFilters,
    required this.visibleCount,
    required this.totalCount,
    required this.onExpand,
  });

  /// Short label for the active phase ("Before" / "During").
  final String phaseLabel;

  /// Human-readable filter labels currently applied to the list. Rendered as
  /// orange pills next to the phase badge.
  final List<String> activeFilters;

  final int visibleCount;
  final int totalCount;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: InkWell(
        onTap: onExpand,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: scheme.outlineVariant, width: 0.5),
              bottom: BorderSide(color: scheme.outlineVariant, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          child: Row(
            children: [
              _PhaseBadge(label: phaseLabel),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final f in activeFilters) _FilterPill(label: f),
                  ],
                ),
              ),
              Text(
                '$visibleCount / $totalCount',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: AppRadius.circularRadius,
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.blackberry,
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    // Pill lives inside an Expanded(Wrap(...)) in CollapsedStrip. Wrap passes
    // a finite maxWidth to its children, so a Container with `alignment` (or
    // any other property that forces it to fill bounded constraints) would
    // stretch to the full available width. Keep the pill intrinsic-sized.
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: AppRadius.circularRadius,
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.blackberry,
          ),
        ),
      ),
    );
  }
}

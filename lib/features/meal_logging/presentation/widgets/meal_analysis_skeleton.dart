import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../jade/presentation/widgets/jade_thinking_status.dart';

/// The waiting state for a Jade meal analysis: the shape of the answer,
/// shimmering, where the answer is about to be.
///
/// This deliberately mirrors [MealReviewScreen]'s layout — the "Items" heading,
/// a stack of [ListTile]-shaped cards (name line over a macro line, edit
/// affordance on the right), then the totals bar. Matching the real thing is
/// the whole point: the user reads the structure of the result while it loads,
/// so the review screen lands as a fill-in rather than a new screen. A skeleton
/// that doesn't match its content is just a fancier spinner.
///
/// Replaces a blocking scrim rather than sitting on top of one, so the wait
/// happens inside the page instead of over it.
class MealAnalysisSkeleton extends StatelessWidget {
  const MealAnalysisSkeleton({
    super.key,
    required this.phases,
    this.itemCount = 3,
  });

  /// Copy for [JadeThinkingStatus] — describe vs photo.
  final List<String> phases;

  /// How many item rows to fake. Three reads as "a meal" without implying a
  /// count the analysis hasn't produced yet.
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;

    // Shimmer needs a base/highlight pair with enough separation to read as
    // motion but not enough to look like real content.
    final base = onSurface.withValues(alpha: isDark ? 0.10 : 0.09);
    final highlight = onSurface.withValues(alpha: isDark ? 0.20 : 0.16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JadeThinkingStatus(
          phases: phases,
          style: AppTextStyles.bodyMedium.copyWith(
            color: onSurface.withValues(alpha: 0.75),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // One Shimmer for the whole block, so every placeholder sweeps on the
        // same pass. Nothing inside may carry its own background: the shimmer
        // gradient is masked over the entire subtree in a single tone, so a
        // filled card would swallow the bars sitting on it. Hence bars only —
        // the row rhythm carries the structure, not a card outline.
        Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          // Start-aligned, not stretched: stretch would force every bar to
          // full width and flatten the ragged edge that makes this read as
          // content. The full-width bars ask for it explicitly.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Items" heading.
              const _Bar(width: 54, height: 14),
              const SizedBox(height: 20),
              for (var i = 0; i < itemCount; i++) ...[
                // Rows must span the full width so the trailing block lands on
                // the right edge, as the real row's edit icon does.
                SizedBox(
                  width: double.infinity,
                  child: _ItemRowSkeleton(index: i),
                ),
                if (i < itemCount - 1) const SizedBox(height: 22),
              ],
              const SizedBox(height: 28),
              // Totals bar.
              const _Bar(width: double.infinity, height: 34),
            ],
          ),
        ),
      ],
    );
  }
}

/// One faked [MealComponentEditor] row: name line over a macro line, with the
/// trailing edit affordance blocked in.
///
/// Widths vary by [index] so three rows don't stack into a mechanical grid —
/// real food names aren't all the same length, and the eye reads the ragged
/// edge as content rather than as a loading pattern.
class _ItemRowSkeleton extends StatelessWidget {
  const _ItemRowSkeleton({required this.index});

  final int index;

  static const _nameWidths = [148.0, 186.0, 132.0];
  static const _macroWidths = [214.0, 178.0, 232.0];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bar(width: _nameWidths[index % _nameWidths.length], height: 13),
              const SizedBox(height: 10),
              _Bar(
                width: _macroWidths[index % _macroWidths.length],
                height: 11,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const _Bar(width: 20, height: 20),
      ],
    );
  }
}

/// A single placeholder block. Its own colour is irrelevant — [Shimmer]
/// repaints every descendant — so it is plain white and acts as a mask.
class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

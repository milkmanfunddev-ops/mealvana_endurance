import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../application/coach_insight_controller.dart';
import '../../domain/coach_insight.dart';

/// Coach-insight panel for the formula editor.
///
/// Shows a single AI-generated piece of guidance about the current draft. The
/// panel is purely presentation: it builds nothing — the editor passes the live
/// [insightContext], and this widget compares the context's stale marker with
/// the controller's stored insight to decide between fresh / outdated / empty.
///
/// States:
///   - no insight yet      → "Get coach insight" CTA
///   - loading             → spinner + "Thinking…"
///   - error               → message + "Try again"
///   - insight (current)   → guidance text
///   - insight (outdated)  → dimmed guidance + "Outdated — refresh"
class CoachInsightPanel extends ConsumerWidget {
  const CoachInsightPanel({
    super.key,
    required this.insightContext,
    required this.formulaId,
  });

  /// The live draft context. Its [CoachInsightContext.staleMarker] determines
  /// whether a previously fetched insight is still current.
  final CoachInsightContext insightContext;

  /// The formula id for the family provider (null for new formulas).
  final String? formulaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(coachInsightControllerProvider(formulaId));
    final notifier = ref.read(
      coachInsightControllerProvider(formulaId).notifier,
    );

    final liveMarker = insightContext.staleMarker;
    final insight = async.value;
    final isLoading = async.isLoading;
    final error = (!isLoading && async.hasError) ? async.error : null;

    final Widget body;
    if (isLoading) {
      body = _LoadingRow(scheme: scheme);
    } else if (error != null) {
      body = _MessageWithAction(
        message: 'Couldn\'t get coach insight.',
        actionLabel: 'Try again',
        scheme: scheme,
        isError: true,
        onPressed: () => notifier.generate(insightContext, trigger: 'retry'),
      );
    } else if (insight == null) {
      body = _MessageWithAction(
        message: 'Get a quick read on this formula from your coach.',
        actionLabel: 'Get coach insight',
        scheme: scheme,
        onPressed: () => notifier.generate(insightContext),
      );
    } else {
      final isCurrent = insight.isCurrentFor(liveMarker);
      body = _InsightBody(
        insight: insight,
        isCurrent: isCurrent,
        scheme: scheme,
        onRefresh: () => notifier.refresh(insightContext),
      );
    }

    return Container(
      key: const ValueKey('formula_kit.coach_insight_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.electrolyte,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Coach insight',
                style: AppTextStyles.smallLabel.copyWith(
                  color: AppColors.electrolyte,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          body,
        ],
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.electrolyte,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Thinking…',
          style: AppTextStyles.bodyMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MessageWithAction extends StatelessWidget {
  const _MessageWithAction({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
    required this.scheme,
    this.isError = false,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;
  final ColorScheme scheme;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isError ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('formula_kit.coach_insight_action'),
            onPressed: onPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.electrolyte,
            ),
            child: Text(
              actionLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.electrolyte,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightBody extends StatelessWidget {
  const _InsightBody({
    required this.insight,
    required this.isCurrent,
    required this.onRefresh,
    required this.scheme,
  });

  final CoachInsight insight;
  final bool isCurrent;
  final VoidCallback onRefresh;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          insight.insight,
          key: const ValueKey('formula_kit.coach_insight_text'),
          style: AppTextStyles.bodyMedium.copyWith(
            color: isCurrent
                ? scheme.onSurface
                : scheme.onSurfaceVariant.withValues(alpha: 0.7),
            height: 1.35,
          ),
        ),
        if (!isCurrent) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.history, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Outdated — your formula changed.',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('formula_kit.coach_insight_refresh'),
                onPressed: onRefresh,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.electrolyte,
                ),
                child: Text(
                  'Refresh',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.electrolyte,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

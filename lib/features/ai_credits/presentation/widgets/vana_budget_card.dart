import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/app_config.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../application/credits_controller.dart';
import '../../application/wallet_channel.dart';
import '../../domain/budget_share.dart';
import '../sheets/token_top_up_sheet.dart';

/// How much of this month's Vana is used, when it refills and any bought
/// extra — a bar and words, with no dollar figure (mp-430 clause 8, mp-436
/// clause 3; ai-cost ticket 10).
///
/// The athlete sees a percentage and a date. The wallet row underneath is in
/// micro-dollars and never reaches the screen: [budgetShareOf] turns it into
/// a share first, and that is the only number this widget can render.
///
/// This is a budget surface, so it watches [walletChannelProvider]: the live
/// wallet connection opens while this card is on screen and closes when it
/// leaves.
class VanaBudgetCard extends ConsumerWidget {
  const VanaBudgetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).aiCreditsEnabled) {
      return const SizedBox.shrink();
    }

    // Open the live wallet connection for as long as this card is showing.
    ref.watch(walletChannelProvider);

    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    final wallet = ref.watch(creditsControllerProvider).value;
    final share = wallet == null ? null : budgetShareOf(wallet);

    return Container(
      key: const ValueKey('ai_credits.budget_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.getValue(ContentKeys.aiCreditsUsageTitle),
            style: AppTextStyles.foodTitle.copyWith(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (share == null)
            _Loading(color: secondary)
          else ...[
            _UsageBar(share: share, track: textColor.withValues(alpha: 0.12)),
            const SizedBox(height: AppSpacing.xs),
            ..._lines(content, share, textColor, secondary),
            if (share.isSpent) ...[
              const SizedBox(height: AppSpacing.sm),
              _TopUpButton(
                label: content.getValue(ContentKeys.aiCreditsTopUpAction),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _lines(
    ContentService content,
    BudgetShare share,
    Color textColor,
    Color secondary,
  ) {
    final refillAt = share.refillAt;
    return [
      Text(
        share.hasWindow
            ? ContentKeys.format(
                content.getValue(ContentKeys.aiCreditsUsageUsed),
                {'percent': percentOf(share.shareUsed!)},
              )
            : content.getValue(ContentKeys.aiCreditsUsageNoWindow),
        key: const ValueKey('ai_credits.usage_used'),
        style: AppTextStyles.bodyMedium.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (refillAt != null)
        Text(
          ContentKeys.format(
            content.getValue(ContentKeys.aiCreditsUsageRefills),
            {'date': DateFormat('MMM d').format(refillAt.toLocal())},
          ),
          key: const ValueKey('ai_credits.usage_refills'),
          style: AppTextStyles.bodySmall.copyWith(color: secondary),
        ),
      if (share.boughtExtraShare > 0)
        Text(
          ContentKeys.format(
            content.getValue(ContentKeys.aiCreditsUsageBoughtExtra),
            {'percent': percentOf(share.boughtExtraShare)},
          ),
          key: const ValueKey('ai_credits.usage_bought_extra'),
          style: AppTextStyles.bodySmall.copyWith(color: secondary),
        ),
      // Only a month that existed can be used up; a wallet with no window is
      // told what a month is instead, above.
      if (share.hasWindow && share.isSpent)
        Text(
          content.getValue(ContentKeys.aiCreditsUsageSpent),
          key: const ValueKey('ai_credits.usage_spent'),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.dragonfruit),
        ),
    ];
  }
}

/// The bar: this month filled to the share used, in dragonfruit once it is
/// all gone. Bought extra is words, not a second segment — it is not part of
/// the month and does not expire with it.
class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.share, required this.track});

  final BudgetShare share;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final used = share.shareUsed ?? 0;
    return ClipRRect(
      key: const ValueKey('ai_credits.usage_bar'),
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            // Positioned.fill, so the fill is as tall as the bar. A loose
            // Stack child here takes its child's height, and a ColoredBox
            // with no child is zero high — the fill was invisible.
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: used.clamp(0.0, 1.0),
                child: ColoredBox(
                  color: share.isSpent
                      ? AppColors.dragonfruit
                      : AppColors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    '…',
    key: const ValueKey('ai_credits.budget_loading'),
    style: AppTextStyles.bodySmall.copyWith(color: color),
  );
}

/// At 100% the athlete gets the top-up sheet (mp-282 §2, mp-430 clause 6) —
/// never a gate, and never a dialog that says "out of credits".
class _TopUpButton extends StatelessWidget {
  const _TopUpButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => KylePrimaryButton(
    key: const ValueKey('ai_credits.top_up'),
    text: label,
    onPressed: () => showTokenTopUpSheet(context),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/services/app_config.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../application/credits_controller.dart';
import '../sheets/token_top_up_sheet.dart';

/// The token balance pill that sits beside an AI surface's prompt.
///
/// Per Xuan's token design: a token glyph plus the balance, in a soft outlined
/// pill. At zero it flips to the accent colour and an accent border so "you
/// are out" reads before the number does. Tapping opens the top-up sheet —
/// the pill is the only entry point to buying, so it must be tappable at any
/// balance, not just zero.
///
/// Renders nothing unless [AppConfig.aiCreditsEnabled], so the surface is
/// unchanged wherever tokens are off.
class TokenPill extends ConsumerWidget {
  const TokenPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).aiCreditsEnabled) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    final wallet = ref.watch(creditsControllerProvider);

    final balance = wallet.value?.balance;
    final out = balance != null && balance <= 0;

    return GestureDetector(
      key: const ValueKey('tokens.balance_pill'),
      onTap: () => showTokenTopUpSheet(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(10, 7, 13, 7),
        decoration: BoxDecoration(
          color: out
              ? AppColors.orange.withValues(alpha: 0.16)
              : onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: out ? AppColors.orange : onSurface.withValues(alpha: 0.22),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TokenGlyph(size: 20, color: out ? AppColors.orange : null),
            const SizedBox(width: 7),
            Text(
              switch (wallet) {
                AsyncData(:final value) => '${value.balance.clamp(0, 99999)}',
                AsyncError() => '–',
                _ => '…',
              },
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: out ? AppColors.orange : onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The token glyph — the Mealvana logomark, which is itself a fortune cookie.
///
/// Tokens are "fortune cookies", so the mark is the brand logomark rather than
/// a stock cookie: `assets/icons/token_cookie.svg` is the logomark flattened to
/// a solid silhouette (crease and the slip's "M" knocked out) so it still reads
/// at 16px. One widget, so every token surface picks up any change.
class TokenGlyph extends StatelessWidget {
  const TokenGlyph({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/token_cookie.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color ?? AppColors.orange, BlendMode.srcIn),
    );
  }
}

/// A quiet "costs N tokens" tag for secondary AI entry points — the photo
/// pickers and re-scan tiles, where the dark inset [TokenCostChip] built for
/// the accent Analyze button would overpower an outlined surface. Just the
/// glyph and the count, no capsule, at reduced opacity so it reads as a price
/// note rather than a second label.
///
/// Renders nothing unless [AppConfig.aiCreditsEnabled], same as the pill.
class TokenCostTag extends ConsumerWidget {
  const TokenCostTag({super.key, this.cost = 1});

  final int cost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).aiCreditsEnabled) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TokenGlyph(size: 14),
        const SizedBox(width: 3),
        Text(
          '$cost',
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// The "costs 1 token" chip that rides inside an AI action button.
///
/// Design: a dark inset capsule on the accent button carrying the glyph and
/// the cost, so the price is attached to the action rather than explained
/// somewhere else on the screen.
class TokenCostChip extends ConsumerWidget {
  const TokenCostChip({super.key, this.cost = 1});

  final int cost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).aiCreditsEnabled) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
      decoration: BoxDecoration(
        color: AppColors.blackberry.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TokenGlyph(size: 16),
          const SizedBox(width: 5),
          Text(
            '$cost',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
            ),
          ),
        ],
      ),
    );
  }
}

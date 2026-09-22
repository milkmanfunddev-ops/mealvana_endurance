import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/services/app_config.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../application/credits_controller.dart';
import '../../domain/budget_share.dart';
import '../sheets/token_top_up_sheet.dart';

/// The Vana budget pill that sits beside an AI surface's prompt.
///
/// Per Xuan's token design: the glyph plus what is left, in a soft outlined
/// pill. Since ai-cost ticket 10 what it shows is a SHARE OF THE MONTH, as a
/// percentage — the wallet holds micro-dollars and the athlete never sees a
/// dollar figure or a credit count (mp-430 clause 8, mp-436 clause 3). Under a
/// tenth of a month left (zero included) it flips to dragonfruit so "you are
/// nearly out" reads before the number does. Tapping opens the top-up sheet —
/// the pill is the only entry point to buying, so it must be tappable at any
/// level, not just empty.
///
/// It reads the cached wallet and does NOT open the live wallet connection:
/// that belongs to the budget screens (`walletChannelProvider`), not to every
/// meal screen.
///
/// Renders nothing unless [AppConfig.aiCreditsEnabled], so the surface is
/// unchanged wherever the budget UI is off.
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

    final left = wallet.value == null
        ? null
        : budgetShareOf(wallet.value!).shareLeft;
    final low = left != null && left < 0.1;

    return GestureDetector(
      key: const ValueKey('tokens.balance_pill'),
      onTap: () => showTokenTopUpSheet(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(10, 7, 13, 7),
        decoration: BoxDecoration(
          color: low
              ? AppColors.dragonfruit.withValues(alpha: 0.16)
              : onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: low
                ? AppColors.dragonfruit
                : onSurface.withValues(alpha: 0.22),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TokenGlyph(size: 20, color: low ? AppColors.dragonfruit : null),
            const SizedBox(width: 7),
            Text(
              switch (wallet) {
                AsyncData() =>
                  '${percentOf((left ?? 0).clamp(0.0, 9.99))}%',
                AsyncError() => '–',
                _ => '…',
              },
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: low ? AppColors.dragonfruit : onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Vana glyph — the Mealvana logomark, which is itself a fortune cookie.
///
/// The mark is the brand logomark rather than a stock cookie: `assets/icons/token_cookie.svg` is the logomark flattened to
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

/// The old "costs N tokens" tag beside a secondary AI entry point.
///
/// Since ai-cost ticket 09 a call draws the monthly budget by what it really
/// costs us: nothing counts turns or actions and no action has a fixed price
/// (mp-430 clause 1). A per-action price would now be a made-up number, so
/// these two render nothing. The widgets stay so their call sites — the photo
/// pickers, the re-scan tiles and the Analyze buttons — keep compiling and
/// keep their layout; the AI surfaces themselves are untouched.
class TokenCostTag extends StatelessWidget {
  const TokenCostTag({super.key, this.cost = 1});

  final int cost;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The old "costs 1 token" price inside an AI action button. See
/// [TokenCostTag] — there is no per-action price any more.
class TokenCostChip extends StatelessWidget {
  const TokenCostChip({super.key, this.cost = 1});

  final int cost;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

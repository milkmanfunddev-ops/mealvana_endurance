import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../application/credits_controller.dart';
import '../../application/purchase_controller.dart';
import '../../data/revenuecat_service.dart';
import '../widgets/token_pill.dart';

/// Show the token top-up sheet.
///
/// One sheet serves both entry points — tapping the balance pill ("Refill
/// tokens") and being blocked at zero ("You're out of tokens") — because they
/// are the same decision at different urgencies. It commits to a purchase and
/// then celebrates in place rather than dismissing, so the user ends where
/// they started with a balance they can see.
Future<void> showTokenTopUpSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TokenTopUpSheet(),
  );
}

/// The two packs offered, in the order they're shown.
///
/// Sizes come from the token-pricing design (50 / 200). The economics behind
/// them live in the Notion cost-accounting doc; if the model changes, the
/// pack sizes are the knob — not the per-analysis cost.
const _packs = <_Pack>[
  _Pack(tokens: 50, price: r'$4.99', tag: 'Starter', productId: 'tokens_50'),
  _Pack(
    tokens: 200,
    price: r'$19.99',
    tag: 'Best value',
    productId: 'tokens_200',
  ),
];

class _Pack {
  const _Pack({
    required this.tokens,
    required this.price,
    required this.tag,
    required this.productId,
  });

  final int tokens;
  final String price;
  final String tag;
  final String productId;
}

class _TokenTopUpSheet extends ConsumerStatefulWidget {
  const _TokenTopUpSheet();

  @override
  ConsumerState<_TokenTopUpSheet> createState() => _TokenTopUpSheetState();
}

class _TokenTopUpSheetState extends ConsumerState<_TokenTopUpSheet> {
  int _selected = 0;
  bool _buying = false;

  /// Non-null once a purchase has landed — switches the sheet to its
  /// celebration state and carries how many tokens were added.
  int? _added;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.blackberryLight : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.cream : AppColors.blackberry)
                    .withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: _added == null ? _packsView() : _successView(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Packs ────────────────────────────────────────────────────────────────

  Widget _packsView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    final balance = ref.watch(creditsControllerProvider).value?.balance ?? 0;
    final out = balance <= 0;

    return Column(
      key: const ValueKey('packs'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const TokenGlyph(size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                out ? "You're out of tokens" : 'Refill tokens',
                style: AppTextStyles.sectionTitle.copyWith(color: onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Each analysis costs 1 token. Top up to keep going.',
          style: AppTextStyles.bodySmall.copyWith(
            color: onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < _packs.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _packRow(_packs[i], i, onSurface),
        ],
        const SizedBox(height: 20),
        KylePrimaryButton(
          key: const ValueKey('tokens.buy'),
          text:
              'Get ${_packs[_selected].tokens} tokens · '
              '${_packs[_selected].price}',
          isLoading: _buying,
          onPressed: _buying ? null : _buy,
        ),
      ],
    );
  }

  Widget _packRow(_Pack pack, int index, Color onSurface) {
    final isSelected = index == _selected;
    return GestureDetector(
      key: ValueKey('tokens.pack_${pack.tokens}'),
      onTap: _buying ? null : () => setState(() => _selected = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.orange.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.orange
                : onSurface.withValues(alpha: 0.14),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            const TokenGlyph(size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pack.tokens} tokens',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                  ),
                  Text(
                    pack.tag,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              pack.price,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Success ──────────────────────────────────────────────────────────────

  Widget _successView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    final added = _added ?? 0;
    final balance = ref.watch(creditsControllerProvider).value?.balance ?? added;

    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 108,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const TokenGlyph(size: 76),
              Positioned(
                right: 92,
                bottom: 10,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.electrolyte,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 19,
                    color: AppColors.blackberry,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "You're topped up!",
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionTitle.copyWith(color: onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          '$added ${added == 1 ? 'token' : 'tokens'} added to your balance.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
            decoration: BoxDecoration(
              color: onSurface.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: onSurface.withValues(alpha: 0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TokenGlyph(size: 22),
                const SizedBox(width: 8),
                Text(
                  '$balance tokens',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        KylePrimaryButton(
          key: const ValueKey('tokens.start_analyzing'),
          text: 'Start analyzing',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  // ── Purchase ─────────────────────────────────────────────────────────────

  Future<void> _buy() async {
    final pack = _packs[_selected];
    setState(() => _buying = true);

    try {
      final package = await _packageFor(pack);
      if (package == null) {
        if (!mounted) return;
        setState(() => _buying = false);
        MealvanaSnackbar.showError(
          context,
          'That pack isn\'t available right now. Please try again later.',
        );
        return;
      }

      await ref.read(purchaseControllerProvider.notifier).buy(package);

      // The wallet is credited server-side by the RevenueCat webhook, so the
      // balance we want to show only exists after a refetch. Refresh before
      // celebrating, otherwise the "new balance" chip shows the old number.
      await ref.read(creditsControllerProvider.notifier).refresh();

      if (!mounted) return;
      setState(() {
        _buying = false;
        _added = pack.tokens;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _buying = false);
      MealvanaSnackbar.showError(context, 'Purchase failed. Nothing charged.');
    }
  }

  /// Resolve the RevenueCat [Package] backing [pack] from the current
  /// offering. Returns null when the store has no matching product — which is
  /// the normal case on a simulator or before the products are approved.
  Future<Package?> _packageFor(_Pack pack) async {
    final offerings = await ref.read(revenueCatServiceProvider).getOfferings();
    final packages = offerings?.current?.availablePackages ?? const <Package>[];
    for (final p in packages) {
      if (p.storeProduct.identifier.contains(pack.productId) ||
          p.identifier.contains(pack.productId)) {
        return p;
      }
    }
    return null;
  }
}

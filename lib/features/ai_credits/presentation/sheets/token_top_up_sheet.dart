import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../application/credits_controller.dart';
import '../../application/purchase_controller.dart';
import '../../domain/credit_packs.dart';
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

/// A purchasable pack, resolved from the live RevenueCat `credits` offering.
///
/// Packs are *not* hardcoded. They previously were, under ids that matched
/// nothing ever provisioned, so the sheet could never resolve a package and the
/// buy button was permanently inert. Reading the offering keeps sizes, ids and
/// localized prices in step with the store by construction — which is why
/// resizing the packs (100/500/1200 → 50/250) needed no change here at all.
class _Pack {
  const _Pack({required this.package, required this.tokens, required this.tag});

  final Package package;

  /// Credits granted, or null when this build doesn't recognise the SKU.
  final int? tokens;

  final String tag;

  StoreProduct get product => package.storeProduct;

  /// Localized price straight from the store (never a hardcoded dollar value).
  String get price => product.priceString;

  String get title => tokens != null ? '$tokens tokens' : product.title;
}

/// Build the display list from an offering, largest pack last and tagged.
List<_Pack> _packsFrom(Offering offering) {
  final packs = offering.availablePackages
      .map(
        (p) => _Pack(
          package: p,
          tokens: creditsForProductId(p.storeProduct.identifier),
          tag: '',
        ),
      )
      .toList();

  // Order by credits so "Best value" is unambiguous; unknown SKUs sort last.
  packs.sort((a, b) => (a.tokens ?? 1 << 30).compareTo(b.tokens ?? 1 << 30));

  return [
    for (var i = 0; i < packs.length; i++)
      _Pack(
        package: packs[i].package,
        tokens: packs[i].tokens,
        tag: packs.length > 1 && i == 0
            ? 'Starter'
            : (packs.length > 1 && i == packs.length - 1 ? 'Best value' : ''),
      ),
  ];
}

class _TokenTopUpSheet extends ConsumerStatefulWidget {
  const _TokenTopUpSheet();

  @override
  ConsumerState<_TokenTopUpSheet> createState() => _TokenTopUpSheetState();
}

class _TokenTopUpSheetState extends ConsumerState<_TokenTopUpSheet> {
  int _selected = 0;
  bool _buying = false;

  /// Set when a purchase attempt fails. Rendered inside the sheet rather than
  /// via a snackbar, which the modal would swallow.
  String? _error;

  /// Non-null once a purchase has landed — switches the sheet to its
  /// celebration state and carries how many tokens were added.
  int? _added;

  /// Balance at the moment a purchase completed at the store but had not yet
  /// been credited. While set, the sheet watches the live balance and flips
  /// itself to the celebration state the instant the webhook lands — the
  /// wallet row is realtime-subscribed, so a slow credit arrives on its own
  /// rather than requiring the user to leave and come back.
  int? _awaitingCreditFrom;

  @override
  Widget build(BuildContext context) {
    // Late-credit watcher: the wallet row is realtime-subscribed, so when a
    // purchase's webhook finally lands the balance rises on its own. If we are
    // sitting in the "tokens on their way" state, complete the story the user
    // started instead of leaving the reassurance text up forever.
    ref.listen(creditsControllerProvider, (_, next) {
      final from = _awaitingCreditFrom;
      final balance = next.value?.balance;
      if (from == null || balance == null || balance <= from) return;
      setState(() {
        _awaitingCreditFrom = null;
        _error = null;
        _added = balance - from;
      });
    });

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
    final offeringAsync = ref.watch(aiCreditOfferingProvider);

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
        offeringAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => _unavailable(onSurface),
          data: (offering) {
            if (offering == null) return _unavailable(onSurface);
            final packs = _packsFrom(offering);
            if (packs.isEmpty) return _unavailable(onSurface);

            // Guard the selection: the offering can change under us between
            // builds (refresh, locale change), and a stale index would throw.
            final selected = _selected.clamp(0, packs.length - 1);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < packs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _packRow(packs[i], i, selected, onSurface),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    key: const ValueKey('tokens.error'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.orange,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                KylePrimaryButton(
                  key: const ValueKey('tokens.buy'),
                  text: packs[selected].tokens != null
                      ? 'Get ${packs[selected].tokens} tokens · '
                            '${packs[selected].price}'
                      : 'Buy · ${packs[selected].price}',
                  isLoading: _buying,
                  onPressed: _buying ? null : () => _buy(packs[selected]),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Shown whenever the store has nothing to sell — no offering, an empty
  /// offering, or a fetch error. This is in-sheet on purpose: the old code
  /// raised a snackbar against the bottom-sheet context, which never became
  /// visible above the modal, so a failed tap looked like a dead button.
  Widget _unavailable(Color onSurface) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Text(
      "Token packs aren't available right now. Please try again later.",
      key: const ValueKey('tokens.unavailable'),
      textAlign: TextAlign.center,
      style: AppTextStyles.bodySmall.copyWith(
        color: onSurface.withValues(alpha: 0.6),
      ),
    ),
  );

  Widget _packRow(_Pack pack, int index, int selected, Color onSurface) {
    final isSelected = index == selected;
    return GestureDetector(
      key: ValueKey('tokens.pack_${pack.tokens ?? pack.product.identifier}'),
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
                    pack.title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                  ),
                  if (pack.tag.isNotEmpty)
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
    final balance =
        ref.watch(creditsControllerProvider).value?.balance ?? added;

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

  /// Purchase [pack]. The package comes straight from the rendered offering,
  /// so there is no id-matching step that can silently fail.
  ///
  /// The message shown comes from the controller's [PurchaseOutcome], not from
  /// a balance comparison. Inferring it from the balance meant a successful
  /// purchase whose grant was merely slow was reported as "Purchase failed.
  /// Nothing was charged." — telling a user who had just been charged that
  /// they hadn't been.
  Future<void> _buy(_Pack pack) async {
    final balanceBefore =
        ref.read(creditsControllerProvider).value?.balance ?? 0;

    setState(() {
      _buying = true;
      _error = null;
    });

    final outcome = await ref
        .read(purchaseControllerProvider.notifier)
        .buy(pack.package);

    if (!mounted) return;

    switch (outcome) {
      case PurchaseOutcome.credited:
        // The wallet is credited server-side by the RevenueCat webhook, so the
        // balance we want to show only exists after a refetch.
        await ref.read(creditsControllerProvider.notifier).refresh();
        if (!mounted) return;
        final balanceAfter =
            ref.read(creditsControllerProvider).value?.balance ?? balanceBefore;
        setState(() {
          _buying = false;
          // Report what the wallet really gained, not what the pack advertised.
          _added = (balanceAfter - balanceBefore) > 0
              ? balanceAfter - balanceBefore
              : (pack.tokens ?? 0);
        });

      case PurchaseOutcome.purchasedButNotCredited:
        setState(() {
          _buying = false;
          // Arm the late-credit watcher (see build) so the sheet upgrades
          // itself to the celebration state when the webhook lands.
          _awaitingCreditFrom = balanceBefore;
          _error =
              'Your purchase went through, but the tokens are still on their '
              "way. They'll appear shortly — no need to buy again.";
        });

      case PurchaseOutcome.cancelled:
        // Not an error. Drop back to the pack list silently.
        setState(() => _buying = false);

      case PurchaseOutcome.notSignedIn:
        setState(() {
          _buying = false;
          _error =
              'Sign in to buy tokens — they are tied to your account so they '
              'follow you to any device.';
        });

      case PurchaseOutcome.failed:
        setState(() {
          _buying = false;
          _error = "That didn't go through. Nothing was charged.";
        });
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../shared/services/app_config.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../application/credits_controller.dart';
import '../../application/purchase_controller.dart';
import '../../domain/credit_wallet.dart';

/// Paywall screen for purchasing AI credit packs.
///
/// When [AppConfig.aiCreditsEnabled] is false (the default), renders a static
/// "Coming soon" placeholder so the route can be registered and navigated to
/// without crashing. No async providers are invoked in the disabled path.
///
/// When enabled, watches:
/// - [creditsControllerProvider] for the user's current balance.
/// - [aiCreditOfferingProvider] for the RevenueCat `credits` offering.
/// - [purchaseControllerProvider] to drive buy/restore actions.
class BuyCreditsScreen extends ConsumerWidget {
  const BuyCreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    if (!config.aiCreditsEnabled) {
      return const _ComingSoonBody();
    }

    return const _EnabledBody();
  }
}

// ---------------------------------------------------------------------------
// Disabled (coming-soon) state
// ---------------------------------------------------------------------------

class _ComingSoonBody extends StatelessWidget {
  const _ComingSoonBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Credits')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_outlined, size: 64),
              SizedBox(height: 16),
              Text(
                'AI Credits — Coming Soon',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Purchase AI credit packs to power coach insights, '
                'meal descriptions, and photo analysis.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Enabled state — watches async providers
// ---------------------------------------------------------------------------

class _EnabledBody extends ConsumerWidget {
  const _EnabledBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(creditsControllerProvider);
    final offeringAsync = ref.watch(aiCreditOfferingProvider);
    final purchaseState = ref.watch(purchaseControllerProvider);

    // Surface purchase errors via snackbar.
    ref.listen<AsyncValue<void>>(purchaseControllerProvider, (_, next) {
      if (next is AsyncError) {
        MealvanaSnackbar.showError(
          context,
          'Purchase failed. Please try again.',
        );
      }
    });

    final isBusy = purchaseState is AsyncLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Credits'),
        actions: [
          TextButton(
            onPressed: isBusy
                ? null
                : () => ref.read(purchaseControllerProvider.notifier).restore(),
            child: const Text('Restore'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current balance header
              _BalanceHeader(walletAsync: walletAsync),
              const SizedBox(height: 32),

              // Credit packs
              Text(
                'Credit Packs',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              offeringAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const _PackagesUnavailable(),
                data: (offering) {
                  if (offering == null ||
                      offering.availablePackages.isEmpty) {
                    return const _PackagesUnavailable();
                  }
                  return _PackageList(
                    packages: offering.availablePackages,
                    isBusy: isBusy,
                    onBuy: (pkg) =>
                        ref.read(purchaseControllerProvider.notifier).buy(pkg),
                  );
                },
              ),

              const SizedBox(height: 32),
              const _CreditsExplanation(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance header
// ---------------------------------------------------------------------------

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.walletAsync});

  final AsyncValue<CreditWallet> walletAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Your Balance',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            walletAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('—'),
              data: (wallet) => Text(
                '${wallet.balance.clamp(0, double.maxFinite).toInt()} credits',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Package list
// ---------------------------------------------------------------------------

class _PackageList extends StatelessWidget {
  const _PackageList({
    required this.packages,
    required this.isBusy,
    required this.onBuy,
  });

  final List<Package> packages;
  final bool isBusy;
  final void Function(Package) onBuy;

  /// Extract the credit count from a product identifier like `mealvana_credits_100`.
  static int? _creditCount(String identifier) {
    const map = {
      'mealvana_credits_100': 100,
      'mealvana_credits_500': 500,
      'mealvana_credits_1200': 1200,
    };
    return map[identifier];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: packages.map((pkg) {
        final product = pkg.storeProduct;
        final credits = _creditCount(product.identifier);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            title: credits != null
                ? Text(
                    '$credits Credits',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : Text(product.title),
            subtitle: credits != null
                ? Text('${product.priceString} one-time purchase')
                : Text(product.priceString),
            trailing: FilledButton(
              onPressed: isBusy ? null : () => onBuy(pkg),
              child: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(product.priceString),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Fallback / explanation widgets
// ---------------------------------------------------------------------------

class _PackagesUnavailable extends StatelessWidget {
  const _PackagesUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Credit packs are not available right now. '
        'Please check back later or contact support.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CreditsExplanation extends StatelessWidget {
  const _CreditsExplanation();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How credits work',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'AI credits power coach insights, meal photo analysis, '
          'meal descriptions, and Jade AI conversations. '
          'Credits are consumed per request and never expire.',
        ),
      ],
    );
  }
}

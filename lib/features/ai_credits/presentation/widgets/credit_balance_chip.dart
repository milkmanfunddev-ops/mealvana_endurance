import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/services/app_config.dart';
import '../../application/credits_controller.dart';

/// A small chip that displays the user's current AI credit balance.
///
/// Only rendered when [AppConfig.aiCreditsEnabled] is true. Tapping navigates
/// to `/buy-credits`. Watching [creditsControllerProvider] so the balance
/// updates automatically after a purchase.
///
/// Usage: drop into any AppBar or toolbar where you want to surface balance.
class CreditBalanceChip extends ConsumerWidget {
  const CreditBalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (!config.aiCreditsEnabled) return const SizedBox.shrink();

    final walletAsync = ref.watch(creditsControllerProvider);

    return GestureDetector(
      onTap: () => context.pushNamed('buy-credits'),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: walletAsync.when(
          loading: () => _Chip(label: '...', key: const ValueKey('loading')),
          error: (_, __) => _Chip(label: '?', key: const ValueKey('error')),
          data: (wallet) => _Chip(
            key: ValueKey(wallet.balance),
            label: '${wallet.balance.clamp(0, double.maxFinite).toInt()}',
            icon: Icons.bolt,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      avatar: icon != null ? Icon(icon, size: 14) : null,
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

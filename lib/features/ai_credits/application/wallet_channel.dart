import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/credits_repository.dart';
import 'credits_controller.dart';

part 'wallet_channel.g.dart';

/// The wallet's live connection, open only while a budget screen is showing
/// (ai-cost ticket 10, spec "Fewer needless calls").
///
/// The realtime subscription on `token_wallets` used to be opened by
/// [CreditsController.build] and, because that controller is `keepAlive`, it
/// then stayed open for the life of the session — a socket held for every
/// athlete on every screen, so that a purchase could land on the two screens
/// that show a balance. Here it is an `autoDispose` provider instead: the
/// channel opens when the first budget screen watches it and closes when the
/// last one goes away. Riverpod's own ref counting is the mechanism, so
/// there is no counter to get wrong.
///
/// A screen opts in by watching this provider; watch it from the Vana budget
/// surfaces only — the pill on the meal screens reads the cached balance and
/// does not need a socket.
///
/// Updates are pushed into [CreditsController], which stays the one cache of
/// the wallet for the session.
@riverpod
void walletChannel(Ref ref) {
  final repo = ref.read(creditsRepositoryProvider);

  final channel = repo.subscribeToWallet((wallet) {
    ref.read(creditsControllerProvider.notifier).applyRemoteWallet(wallet);
  });

  ref.onDispose(() {
    if (channel != null) repo.removeChannel(channel);
  });
}

/// The channel's type, re-exported so callers need not import Supabase.
typedef WalletRealtimeChannel = RealtimeChannel;

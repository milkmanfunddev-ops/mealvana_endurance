import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/credits_repository.dart';
import '../domain/credit_wallet.dart';

part 'credits_controller.g.dart';

/// Exposes the current user's credit [CreditWallet].
///
/// Starts with an async fetch from [CreditsRepository]. Use [refresh] to
/// re-fetch on demand (e.g. after a RevenueCat webhook may have credited the
/// wallet).
@riverpod
class CreditsController extends _$CreditsController {
  CreditsRepository get _repo => ref.read(creditsRepositoryProvider);

  @override
  FutureOr<CreditWallet> build() async {
    return _repo.fetchWallet();
  }

  /// Re-fetch the wallet from Supabase and update state.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.fetchWallet());
  }
}

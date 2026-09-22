/// A wallet transport that counts what the app asks of it.
///
/// The live wallet connection must be open only while a budget screen is
/// showing (ai-cost ticket 10), which is a claim about calls, not about
/// pixels — so the seam is the repository and the test counts subscribes and
/// removes. Rows go in as the server writes them (whole micro-dollars), never
/// as the app's own output.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/data/credits_repository.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeRealtimeChannel extends Fake implements RealtimeChannel {}

class CountingCreditsRepository extends Fake implements CreditsRepository {
  CountingCreditsRepository({this.row = const {'balance': 0}});

  /// The `token_wallets` row this transport serves.
  Map<String, dynamic> row;

  int subscribes = 0;
  int removes = 0;

  /// The callback the app registered, so a test can push a row down the wire.
  void Function(CreditWallet)? onChange;

  @override
  bool get hasAuthenticatedUser => true;

  @override
  bool get isAnonymousUser => false;

  @override
  String? get currentUserId => 'a4d4e2ee-0c1f-4a1e-9f2e-0e6b0a51d0f3';

  @override
  Stream<String?> get authUserIdChanges => const Stream<String?>.empty();

  @override
  Future<int?> ensureWallet() async => null;

  @override
  Future<CreditWallet> fetchWallet() async => CreditWallet.fromMap(row);

  @override
  RealtimeChannel? subscribeToWallet(void Function(CreditWallet) onChange) {
    subscribes++;
    this.onChange = onChange;
    return FakeRealtimeChannel();
  }

  @override
  void removeChannel(RealtimeChannel channel) {
    removes++;
    onChange = null;
  }
}

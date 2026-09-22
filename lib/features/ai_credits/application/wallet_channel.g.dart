// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_channel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(walletChannel)
const walletChannelProvider = WalletChannelProvider._();

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

final class WalletChannelProvider extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
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
  const WalletChannelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'walletChannelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$walletChannelHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return walletChannel(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$walletChannelHash() => r'84d8fa55aaa71e61b87f200c770dc8a9ff4e5f44';

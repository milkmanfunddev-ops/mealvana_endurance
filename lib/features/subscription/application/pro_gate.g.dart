// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pro_gate.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reactive form of [computeProUnlocked]. keepAlive so the router's
/// `ref.read` sees the same value the tabs screen is watching.

@ProviderFor(proUnlocked)
const proUnlockedProvider = ProUnlockedProvider._();

/// Reactive form of [computeProUnlocked]. keepAlive so the router's
/// `ref.read` sees the same value the tabs screen is watching.

final class ProUnlockedProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Reactive form of [computeProUnlocked]. keepAlive so the router's
  /// `ref.read` sees the same value the tabs screen is watching.
  const ProUnlockedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'proUnlockedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$proUnlockedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return proUnlocked(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$proUnlockedHash() => r'993bf9a07cea3b38b06b0c25337088bde683e26e';

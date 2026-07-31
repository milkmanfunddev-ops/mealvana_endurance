// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revenuecat_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Kept alive because this wraps a process-wide native singleton. Under
/// autoDispose the instance that startup configured was thrown away, and every
/// later read built a fresh, unconfigured one.

@ProviderFor(revenueCatService)
const revenueCatServiceProvider = RevenueCatServiceProvider._();

/// Kept alive because this wraps a process-wide native singleton. Under
/// autoDispose the instance that startup configured was thrown away, and every
/// later read built a fresh, unconfigured one.

final class RevenueCatServiceProvider
    extends
        $FunctionalProvider<
          RevenueCatService,
          RevenueCatService,
          RevenueCatService
        >
    with $Provider<RevenueCatService> {
  /// Kept alive because this wraps a process-wide native singleton. Under
  /// autoDispose the instance that startup configured was thrown away, and every
  /// later read built a fresh, unconfigured one.
  const RevenueCatServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'revenueCatServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$revenueCatServiceHash();

  @$internal
  @override
  $ProviderElement<RevenueCatService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RevenueCatService create(Ref ref) {
    return revenueCatService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RevenueCatService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RevenueCatService>(value),
    );
  }
}

String _$revenueCatServiceHash() => r'216a013bf21b15f46dd1d8a9e757e7194b6bab80';

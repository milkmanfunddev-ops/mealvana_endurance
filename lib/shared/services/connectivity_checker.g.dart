// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_checker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(connectivityChecker)
const connectivityCheckerProvider = ConnectivityCheckerProvider._();

final class ConnectivityCheckerProvider
    extends
        $FunctionalProvider<
          ConnectivityChecker,
          ConnectivityChecker,
          ConnectivityChecker
        >
    with $Provider<ConnectivityChecker> {
  const ConnectivityCheckerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityCheckerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityCheckerHash();

  @$internal
  @override
  $ProviderElement<ConnectivityChecker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectivityChecker create(Ref ref) {
    return connectivityChecker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectivityChecker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectivityChecker>(value),
    );
  }
}

String _$connectivityCheckerHash() =>
    r'30667e44b1b05ce84ddc0e94d33aa18442af5d32';

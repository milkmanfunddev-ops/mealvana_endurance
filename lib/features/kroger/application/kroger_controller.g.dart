// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kroger_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The delivery area from the device, via the app's shared location service.
///
/// Returns null for every way this can fail to produce an answer — the
/// permission refused, the services off, the reverse lookup empty — because
/// they all lead to the same place: the shopper types their postcode instead.
/// Nothing here is stored; the coordinates do not leave this function.

@ProviderFor(krogerAreaFinder)
const krogerAreaFinderProvider = KrogerAreaFinderProvider._();

/// The delivery area from the device, via the app's shared location service.
///
/// Returns null for every way this can fail to produce an answer — the
/// permission refused, the services off, the reverse lookup empty — because
/// they all lead to the same place: the shopper types their postcode instead.
/// Nothing here is stored; the coordinates do not leave this function.

final class KrogerAreaFinderProvider
    extends
        $FunctionalProvider<
          KrogerAreaFinder,
          KrogerAreaFinder,
          KrogerAreaFinder
        >
    with $Provider<KrogerAreaFinder> {
  /// The delivery area from the device, via the app's shared location service.
  ///
  /// Returns null for every way this can fail to produce an answer — the
  /// permission refused, the services off, the reverse lookup empty — because
  /// they all lead to the same place: the shopper types their postcode instead.
  /// Nothing here is stored; the coordinates do not leave this function.
  const KrogerAreaFinderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'krogerAreaFinderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$krogerAreaFinderHash();

  @$internal
  @override
  $ProviderElement<KrogerAreaFinder> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KrogerAreaFinder create(Ref ref) {
    return krogerAreaFinder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KrogerAreaFinder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KrogerAreaFinder>(value),
    );
  }
}

String _$krogerAreaFinderHash() => r'f7fef59d0ca1caddbce6c86ebd8dec57f6f3575e';

@ProviderFor(krogerUserId)
const krogerUserIdProvider = KrogerUserIdProvider._();

final class KrogerUserIdProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  const KrogerUserIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'krogerUserIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$krogerUserIdHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return krogerUserId(ref);
  }
}

String _$krogerUserIdHash() => r'2ee86c4388a998afb21a251e94082a12c046e517';

@ProviderFor(krogerBrowser)
const krogerBrowserProvider = KrogerBrowserProvider._();

final class KrogerBrowserProvider
    extends $FunctionalProvider<KrogerBrowser, KrogerBrowser, KrogerBrowser>
    with $Provider<KrogerBrowser> {
  const KrogerBrowserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'krogerBrowserProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$krogerBrowserHash();

  @$internal
  @override
  $ProviderElement<KrogerBrowser> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KrogerBrowser create(Ref ref) {
    return krogerBrowser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KrogerBrowser value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KrogerBrowser>(value),
    );
  }
}

String _$krogerBrowserHash() => r'5e539534d7178bdb94ff63df3d59d7415c158d2b';

@ProviderFor(KrogerController)
const krogerControllerProvider = KrogerControllerFamily._();

final class KrogerControllerProvider
    extends $AsyncNotifierProvider<KrogerController, KrogerState> {
  const KrogerControllerProvider._({
    required KrogerControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'krogerControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$krogerControllerHash();

  @override
  String toString() {
    return r'krogerControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  KrogerController create() => KrogerController();

  @override
  bool operator ==(Object other) {
    return other is KrogerControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$krogerControllerHash() => r'4f31063456bff68fe14aa317f614e6bac4168e69';

final class KrogerControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          KrogerController,
          AsyncValue<KrogerState>,
          KrogerState,
          FutureOr<KrogerState>,
          String
        > {
  const KrogerControllerFamily._()
    : super(
        retry: null,
        name: r'krogerControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  KrogerControllerProvider call(String planId) =>
      KrogerControllerProvider._(argument: planId, from: this);

  @override
  String toString() => r'krogerControllerProvider';
}

abstract class _$KrogerController extends $AsyncNotifier<KrogerState> {
  late final _$args = ref.$arg as String;
  String get planId => _$args;

  FutureOr<KrogerState> build(String planId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<KrogerState>, KrogerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<KrogerState>, KrogerState>,
              AsyncValue<KrogerState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

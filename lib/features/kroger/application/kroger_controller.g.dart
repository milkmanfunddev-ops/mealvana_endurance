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
/// permission refused, the services off, the reverse lookup empty or thrown —
/// because they all lead to the same place: the shopper types their postcode
/// instead. Nothing here is stored; the coordinates do not leave this
/// function.

@ProviderFor(krogerAreaFinder)
const krogerAreaFinderProvider = KrogerAreaFinderProvider._();

/// The delivery area from the device, via the app's shared location service.
///
/// Returns null for every way this can fail to produce an answer — the
/// permission refused, the services off, the reverse lookup empty or thrown —
/// because they all lead to the same place: the shopper types their postcode
/// instead. Nothing here is stored; the coordinates do not leave this
/// function.

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
  /// permission refused, the services off, the reverse lookup empty or thrown —
  /// because they all lead to the same place: the shopper types their postcode
  /// instead. Nothing here is stored; the coordinates do not leave this
  /// function.
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

String _$krogerAreaFinderHash() => r'f2267a1d96d86ee7525805455b73e05657995202';

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

String _$krogerBrowserHash() => r'5582d3f7a43f3c2b7a061de65f864157de2a0b5e';

@ProviderFor(krogerLauncher)
const krogerLauncherProvider = KrogerLauncherProvider._();

final class KrogerLauncherProvider
    extends $FunctionalProvider<KrogerLauncher, KrogerLauncher, KrogerLauncher>
    with $Provider<KrogerLauncher> {
  const KrogerLauncherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'krogerLauncherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$krogerLauncherHash();

  @$internal
  @override
  $ProviderElement<KrogerLauncher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KrogerLauncher create(Ref ref) {
    return krogerLauncher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KrogerLauncher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KrogerLauncher>(value),
    );
  }
}

String _$krogerLauncherHash() => r'cf464c8ac54901269082d3242d3971f949bc4594';

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

String _$krogerControllerHash() => r'935a3427cdd6542603fd122b34bb4b3ff0ffb329';

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

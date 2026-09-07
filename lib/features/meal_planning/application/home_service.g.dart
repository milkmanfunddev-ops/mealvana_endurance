// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(homeService)
const homeServiceProvider = HomeServiceProvider._();

final class HomeServiceProvider
    extends $FunctionalProvider<HomeService, HomeService, HomeService>
    with $Provider<HomeService> {
  const HomeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeServiceHash();

  @$internal
  @override
  $ProviderElement<HomeService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HomeService create(Ref ref) {
    return homeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeService>(value),
    );
  }
}

String _$homeServiceHash() => r'5e08d9b46b901b6879e42b0add0a9fc917201f00';

/// The Plan tab's header data for [date] (`YYYY-MM-DD`; today by default).
///
/// Online only — offline the value is `null` and the tab renders from the
/// local plan alone. When the day note is `stale` (the server is
/// regenerating notes after an edit) the controller re-polls once after
/// [stalePollDelay], up to [maxStalePolls] times; it never generates a note
/// client-side.

@ProviderFor(HomeController)
const homeControllerProvider = HomeControllerFamily._();

/// The Plan tab's header data for [date] (`YYYY-MM-DD`; today by default).
///
/// Online only — offline the value is `null` and the tab renders from the
/// local plan alone. When the day note is `stale` (the server is
/// regenerating notes after an edit) the controller re-polls once after
/// [stalePollDelay], up to [maxStalePolls] times; it never generates a note
/// client-side.
final class HomeControllerProvider
    extends $AsyncNotifierProvider<HomeController, HomePayload?> {
  /// The Plan tab's header data for [date] (`YYYY-MM-DD`; today by default).
  ///
  /// Online only — offline the value is `null` and the tab renders from the
  /// local plan alone. When the day note is `stale` (the server is
  /// regenerating notes after an edit) the controller re-polls once after
  /// [stalePollDelay], up to [maxStalePolls] times; it never generates a note
  /// client-side.
  const HomeControllerProvider._({
    required HomeControllerFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'homeControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$homeControllerHash();

  @override
  String toString() {
    return r'homeControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  HomeController create() => HomeController();

  @override
  bool operator ==(Object other) {
    return other is HomeControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$homeControllerHash() => r'a95a0e3065d6be7bb7ba4c912e7007e6e753965e';

/// The Plan tab's header data for [date] (`YYYY-MM-DD`; today by default).
///
/// Online only — offline the value is `null` and the tab renders from the
/// local plan alone. When the day note is `stale` (the server is
/// regenerating notes after an edit) the controller re-polls once after
/// [stalePollDelay], up to [maxStalePolls] times; it never generates a note
/// client-side.

final class HomeControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          HomeController,
          AsyncValue<HomePayload?>,
          HomePayload?,
          FutureOr<HomePayload?>,
          String?
        > {
  const HomeControllerFamily._()
    : super(
        retry: null,
        name: r'homeControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The Plan tab's header data for [date] (`YYYY-MM-DD`; today by default).
  ///
  /// Online only — offline the value is `null` and the tab renders from the
  /// local plan alone. When the day note is `stale` (the server is
  /// regenerating notes after an edit) the controller re-polls once after
  /// [stalePollDelay], up to [maxStalePolls] times; it never generates a note
  /// client-side.

  HomeControllerProvider call([String? date]) =>
      HomeControllerProvider._(argument: date, from: this);

  @override
  String toString() => r'homeControllerProvider';
}

/// The Plan tab's header data for [date] (`YYYY-MM-DD`; today by default).
///
/// Online only — offline the value is `null` and the tab renders from the
/// local plan alone. When the day note is `stale` (the server is
/// regenerating notes after an edit) the controller re-polls once after
/// [stalePollDelay], up to [maxStalePolls] times; it never generates a note
/// client-side.

abstract class _$HomeController extends $AsyncNotifier<HomePayload?> {
  late final _$args = ref.$arg as String?;
  String? get date => _$args;

  FutureOr<HomePayload?> build([String? date]);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<HomePayload?>, HomePayload?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<HomePayload?>, HomePayload?>,
              AsyncValue<HomePayload?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

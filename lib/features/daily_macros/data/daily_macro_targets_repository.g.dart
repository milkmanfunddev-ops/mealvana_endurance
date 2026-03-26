// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_macro_targets_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dailyMacroTargetsRepository)
const dailyMacroTargetsRepositoryProvider =
    DailyMacroTargetsRepositoryProvider._();

final class DailyMacroTargetsRepositoryProvider
    extends
        $FunctionalProvider<
          DailyMacroTargetsRepository,
          DailyMacroTargetsRepository,
          DailyMacroTargetsRepository
        >
    with $Provider<DailyMacroTargetsRepository> {
  const DailyMacroTargetsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyMacroTargetsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyMacroTargetsRepositoryHash();

  @$internal
  @override
  $ProviderElement<DailyMacroTargetsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DailyMacroTargetsRepository create(Ref ref) {
    return dailyMacroTargetsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DailyMacroTargetsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DailyMacroTargetsRepository>(value),
    );
  }
}

String _$dailyMacroTargetsRepositoryHash() =>
    r'7a5822b40fb83283f0ed79bf26db6a5b37d592e6';

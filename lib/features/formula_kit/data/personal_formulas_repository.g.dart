// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_formulas_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(personalFormulasRepository)
const personalFormulasRepositoryProvider =
    PersonalFormulasRepositoryProvider._();

final class PersonalFormulasRepositoryProvider
    extends
        $FunctionalProvider<
          PersonalFormulasRepository,
          PersonalFormulasRepository,
          PersonalFormulasRepository
        >
    with $Provider<PersonalFormulasRepository> {
  const PersonalFormulasRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalFormulasRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalFormulasRepositoryHash();

  @$internal
  @override
  $ProviderElement<PersonalFormulasRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PersonalFormulasRepository create(Ref ref) {
    return personalFormulasRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersonalFormulasRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersonalFormulasRepository>(value),
    );
  }
}

String _$personalFormulasRepositoryHash() =>
    r'ac9e2922e43ffc7d6c6dc42d580bf08d32ee9678';

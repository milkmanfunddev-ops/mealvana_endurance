// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_templates_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(personalTemplatesRepository)
const personalTemplatesRepositoryProvider =
    PersonalTemplatesRepositoryProvider._();

final class PersonalTemplatesRepositoryProvider
    extends
        $FunctionalProvider<
          PersonalTemplatesRepository,
          PersonalTemplatesRepository,
          PersonalTemplatesRepository
        >
    with $Provider<PersonalTemplatesRepository> {
  const PersonalTemplatesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalTemplatesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalTemplatesRepositoryHash();

  @$internal
  @override
  $ProviderElement<PersonalTemplatesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PersonalTemplatesRepository create(Ref ref) {
    return personalTemplatesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersonalTemplatesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersonalTemplatesRepository>(value),
    );
  }
}

String _$personalTemplatesRepositoryHash() =>
    r'bf365dbbee0b204d209b6f586a5aa72c5aa16f3f';

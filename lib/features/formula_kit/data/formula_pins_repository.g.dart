// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'formula_pins_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(formulaPinsRepository)
const formulaPinsRepositoryProvider = FormulaPinsRepositoryProvider._();

final class FormulaPinsRepositoryProvider
    extends
        $FunctionalProvider<
          FormulaPinsRepository,
          FormulaPinsRepository,
          FormulaPinsRepository
        >
    with $Provider<FormulaPinsRepository> {
  const FormulaPinsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formulaPinsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$formulaPinsRepositoryHash();

  @$internal
  @override
  $ProviderElement<FormulaPinsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FormulaPinsRepository create(Ref ref) {
    return formulaPinsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FormulaPinsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FormulaPinsRepository>(value),
    );
  }
}

String _$formulaPinsRepositoryHash() =>
    r'819fb18274a227e70f06e4095d890ff2eea3c69f';

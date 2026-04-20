// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(checklistRepository)
const checklistRepositoryProvider = ChecklistRepositoryProvider._();

final class ChecklistRepositoryProvider
    extends
        $FunctionalProvider<
          ChecklistRepository,
          ChecklistRepository,
          ChecklistRepository
        >
    with $Provider<ChecklistRepository> {
  const ChecklistRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checklistRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checklistRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChecklistRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChecklistRepository create(Ref ref) {
    return checklistRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChecklistRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChecklistRepository>(value),
    );
  }
}

String _$checklistRepositoryHash() =>
    r'7f8631d60486a53389281bdc1df9bacc8bc8f90f';

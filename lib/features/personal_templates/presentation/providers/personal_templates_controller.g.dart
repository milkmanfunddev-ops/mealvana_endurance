// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_templates_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for personal nutrition plan templates

@ProviderFor(PersonalTemplatesController)
const personalTemplatesControllerProvider =
    PersonalTemplatesControllerProvider._();

/// Controller for personal nutrition plan templates
final class PersonalTemplatesControllerProvider
    extends
        $AsyncNotifierProvider<
          PersonalTemplatesController,
          List<PersonalTemplate>
        > {
  /// Controller for personal nutrition plan templates
  const PersonalTemplatesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalTemplatesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalTemplatesControllerHash();

  @$internal
  @override
  PersonalTemplatesController create() => PersonalTemplatesController();
}

String _$personalTemplatesControllerHash() =>
    r'0604557611551039020fd888fcc29bd376affd56';

/// Controller for personal nutrition plan templates

abstract class _$PersonalTemplatesController
    extends $AsyncNotifier<List<PersonalTemplate>> {
  FutureOr<List<PersonalTemplate>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<List<PersonalTemplate>>, List<PersonalTemplate>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PersonalTemplate>>,
                List<PersonalTemplate>
              >,
              AsyncValue<List<PersonalTemplate>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

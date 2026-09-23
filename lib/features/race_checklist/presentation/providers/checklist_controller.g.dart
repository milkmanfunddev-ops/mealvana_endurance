// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the gear template service

@ProviderFor(gearTemplateService)
const gearTemplateServiceProvider = GearTemplateServiceProvider._();

/// Provider for the gear template service

final class GearTemplateServiceProvider
    extends
        $FunctionalProvider<
          GearTemplateService,
          GearTemplateService,
          GearTemplateService
        >
    with $Provider<GearTemplateService> {
  /// Provider for the gear template service
  const GearTemplateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gearTemplateServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gearTemplateServiceHash();

  @$internal
  @override
  $ProviderElement<GearTemplateService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GearTemplateService create(Ref ref) {
    return gearTemplateService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GearTemplateService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GearTemplateService>(value),
    );
  }
}

String _$gearTemplateServiceHash() =>
    r'2549daffad92ad2c19e17f501e18906abaff8570';

/// Controller for race day checklist

@ProviderFor(ChecklistController)
const checklistControllerProvider = ChecklistControllerFamily._();

/// Controller for race day checklist
final class ChecklistControllerProvider
    extends $AsyncNotifierProvider<ChecklistController, List<ChecklistItem>> {
  /// Controller for race day checklist
  const ChecklistControllerProvider._({
    required ChecklistControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'checklistControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$checklistControllerHash();

  @override
  String toString() {
    return r'checklistControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChecklistController create() => ChecklistController();

  @override
  bool operator ==(Object other) {
    return other is ChecklistControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$checklistControllerHash() =>
    r'29219455c5b6553ae4c492dde193e0e4ddd31135';

/// Controller for race day checklist

final class ChecklistControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ChecklistController,
          AsyncValue<List<ChecklistItem>>,
          List<ChecklistItem>,
          FutureOr<List<ChecklistItem>>,
          String
        > {
  const ChecklistControllerFamily._()
    : super(
        retry: null,
        name: r'checklistControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Controller for race day checklist

  ChecklistControllerProvider call(String eventId) =>
      ChecklistControllerProvider._(argument: eventId, from: this);

  @override
  String toString() => r'checklistControllerProvider';
}

/// Controller for race day checklist

abstract class _$ChecklistController
    extends $AsyncNotifier<List<ChecklistItem>> {
  late final _$args = ref.$arg as String;
  String get eventId => _$args;

  FutureOr<List<ChecklistItem>> build(String eventId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<AsyncValue<List<ChecklistItem>>, List<ChecklistItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ChecklistItem>>, List<ChecklistItem>>,
              AsyncValue<List<ChecklistItem>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Computed provider for checklist progress

@ProviderFor(checklistProgress)
const checklistProgressProvider = ChecklistProgressFamily._();

/// Computed provider for checklist progress

final class ChecklistProgressProvider
    extends
        $FunctionalProvider<
          ChecklistProgress,
          ChecklistProgress,
          ChecklistProgress
        >
    with $Provider<ChecklistProgress> {
  /// Computed provider for checklist progress
  const ChecklistProgressProvider._({
    required ChecklistProgressFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'checklistProgressProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$checklistProgressHash();

  @override
  String toString() {
    return r'checklistProgressProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ChecklistProgress> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChecklistProgress create(Ref ref) {
    final argument = this.argument as String;
    return checklistProgress(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChecklistProgress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChecklistProgress>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChecklistProgressProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$checklistProgressHash() => r'e865d01293e1eb231c2bbe9c2e20676d867fa827';

/// Computed provider for checklist progress

final class ChecklistProgressFamily extends $Family
    with $FunctionalFamilyOverride<ChecklistProgress, String> {
  const ChecklistProgressFamily._()
    : super(
        retry: null,
        name: r'checklistProgressProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Computed provider for checklist progress

  ChecklistProgressProvider call(String eventId) =>
      ChecklistProgressProvider._(argument: eventId, from: this);

  @override
  String toString() => r'checklistProgressProvider';
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_notes_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing voice notes/journal entries list
/// Following Andrea Bizzotto's FOA AsyncNotifier pattern

@ProviderFor(VoiceNotesController)
const voiceNotesControllerProvider = VoiceNotesControllerProvider._();

/// Controller for managing voice notes/journal entries list
/// Following Andrea Bizzotto's FOA AsyncNotifier pattern
final class VoiceNotesControllerProvider
    extends $AsyncNotifierProvider<VoiceNotesController, List<NutritionPlan>> {
  /// Controller for managing voice notes/journal entries list
  /// Following Andrea Bizzotto's FOA AsyncNotifier pattern
  const VoiceNotesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceNotesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceNotesControllerHash();

  @$internal
  @override
  VoiceNotesController create() => VoiceNotesController();
}

String _$voiceNotesControllerHash() =>
    r'e1c1e7ea33dc6cac615d65eaa23938f3a4057727';

/// Controller for managing voice notes/journal entries list
/// Following Andrea Bizzotto's FOA AsyncNotifier pattern

abstract class _$VoiceNotesController
    extends $AsyncNotifier<List<NutritionPlan>> {
  FutureOr<List<NutritionPlan>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<List<NutritionPlan>>, List<NutritionPlan>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<NutritionPlan>>, List<NutritionPlan>>,
              AsyncValue<List<NutritionPlan>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

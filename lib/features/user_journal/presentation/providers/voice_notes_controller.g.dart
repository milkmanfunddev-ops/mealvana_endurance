// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_notes_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$voiceNotesControllerHash() =>
    r'4755ce0a3f76f35bad0cc3dd568ebb1fb0a7970a';

/// Controller for managing voice notes/journal entries list
/// Following Andrea Bizzotto's FOA AsyncNotifier pattern
///
/// Copied from [VoiceNotesController].
@ProviderFor(VoiceNotesController)
final voiceNotesControllerProvider = AutoDisposeAsyncNotifierProvider<
    VoiceNotesController, List<NutritionPlan>>.internal(
  VoiceNotesController.new,
  name: r'voiceNotesControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$voiceNotesControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VoiceNotesController = AutoDisposeAsyncNotifier<List<NutritionPlan>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

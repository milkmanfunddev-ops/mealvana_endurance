// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_notes_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the workout notes repository

@ProviderFor(workoutNotesRepository)
const workoutNotesRepositoryProvider = WorkoutNotesRepositoryProvider._();

/// Provider for the workout notes repository

final class WorkoutNotesRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<WorkoutNotesRepository>,
          WorkoutNotesRepository,
          FutureOr<WorkoutNotesRepository>
        >
    with
        $FutureModifier<WorkoutNotesRepository>,
        $FutureProvider<WorkoutNotesRepository> {
  /// Provider for the workout notes repository
  const WorkoutNotesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutNotesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutNotesRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<WorkoutNotesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WorkoutNotesRepository> create(Ref ref) {
    return workoutNotesRepository(ref);
  }
}

String _$workoutNotesRepositoryHash() =>
    r'1d09b203a2d6b737c521feaddc62562848cb9605';

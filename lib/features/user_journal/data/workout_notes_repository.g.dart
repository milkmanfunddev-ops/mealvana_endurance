// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_notes_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workoutNotesRepository)
const workoutNotesRepositoryProvider = WorkoutNotesRepositoryProvider._();

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
    r'774fde414af7e8c93cb0a04d2761165ab70d6c2e';

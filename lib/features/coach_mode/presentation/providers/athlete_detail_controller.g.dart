// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'athlete_detail_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AthleteDetailController)
const athleteDetailControllerProvider = AthleteDetailControllerFamily._();

final class AthleteDetailControllerProvider
    extends
        $AsyncNotifierProvider<AthleteDetailController, AthleteDetailState> {
  const AthleteDetailControllerProvider._({
    required AthleteDetailControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'athleteDetailControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$athleteDetailControllerHash();

  @override
  String toString() {
    return r'athleteDetailControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AthleteDetailController create() => AthleteDetailController();

  @override
  bool operator ==(Object other) {
    return other is AthleteDetailControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$athleteDetailControllerHash() =>
    r'5663f1af17d423a5ea406794d47c6f4f96873c29';

final class AthleteDetailControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          AthleteDetailController,
          AsyncValue<AthleteDetailState>,
          AthleteDetailState,
          FutureOr<AthleteDetailState>,
          String
        > {
  const AthleteDetailControllerFamily._()
    : super(
        retry: null,
        name: r'athleteDetailControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AthleteDetailControllerProvider call(String relationshipId) =>
      AthleteDetailControllerProvider._(argument: relationshipId, from: this);

  @override
  String toString() => r'athleteDetailControllerProvider';
}

abstract class _$AthleteDetailController
    extends $AsyncNotifier<AthleteDetailState> {
  late final _$args = ref.$arg as String;
  String get relationshipId => _$args;

  FutureOr<AthleteDetailState> build(String relationshipId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<AsyncValue<AthleteDetailState>, AthleteDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AthleteDetailState>, AthleteDetailState>,
              AsyncValue<AthleteDetailState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

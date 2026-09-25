// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-lifetime: a session spans Log a Meal and Review & Log, and the meal
/// controller that counts into it is auto-dispose.

@ProviderFor(diarySession)
const diarySessionProvider = DiarySessionProvider._();

/// App-lifetime: a session spans Log a Meal and Review & Log, and the meal
/// controller that counts into it is auto-dispose.

final class DiarySessionProvider
    extends $FunctionalProvider<DiarySession, DiarySession, DiarySession>
    with $Provider<DiarySession> {
  /// App-lifetime: a session spans Log a Meal and Review & Log, and the meal
  /// controller that counts into it is auto-dispose.
  const DiarySessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diarySessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diarySessionHash();

  @$internal
  @override
  $ProviderElement<DiarySession> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DiarySession create(Ref ref) {
    return diarySession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiarySession value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiarySession>(value),
    );
  }
}

String _$diarySessionHash() => r'347213ae0ee0205e5f0989d4ef766a9339ce137a';

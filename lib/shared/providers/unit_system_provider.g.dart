// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_system_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the current user's preferred [UnitSystem] (imperial/metric).
///
/// Sourced from the user profile: `users.unit_system` on Supabase, mirrored
/// in Drift's `user_profiles.unit_system` column (default `'imperial'`).
/// This is the single shared entry point for reading unit-system preference
/// - callers should use this instead of reaching into settings state or the
/// user profile directly.
///
/// Usage:
/// ```dart
/// final unitSystem = ref.watch(unitSystemProvider).valueOrNull ?? UnitSystem.imperial;
/// final useMetric = unitSystem == UnitSystem.metric;
/// ```

@ProviderFor(unitSystem)
const unitSystemProvider = UnitSystemProvider._();

/// Provides the current user's preferred [UnitSystem] (imperial/metric).
///
/// Sourced from the user profile: `users.unit_system` on Supabase, mirrored
/// in Drift's `user_profiles.unit_system` column (default `'imperial'`).
/// This is the single shared entry point for reading unit-system preference
/// - callers should use this instead of reaching into settings state or the
/// user profile directly.
///
/// Usage:
/// ```dart
/// final unitSystem = ref.watch(unitSystemProvider).valueOrNull ?? UnitSystem.imperial;
/// final useMetric = unitSystem == UnitSystem.metric;
/// ```

final class UnitSystemProvider
    extends
        $FunctionalProvider<
          AsyncValue<UnitSystem>,
          UnitSystem,
          FutureOr<UnitSystem>
        >
    with $FutureModifier<UnitSystem>, $FutureProvider<UnitSystem> {
  /// Provides the current user's preferred [UnitSystem] (imperial/metric).
  ///
  /// Sourced from the user profile: `users.unit_system` on Supabase, mirrored
  /// in Drift's `user_profiles.unit_system` column (default `'imperial'`).
  /// This is the single shared entry point for reading unit-system preference
  /// - callers should use this instead of reaching into settings state or the
  /// user profile directly.
  ///
  /// Usage:
  /// ```dart
  /// final unitSystem = ref.watch(unitSystemProvider).valueOrNull ?? UnitSystem.imperial;
  /// final useMetric = unitSystem == UnitSystem.metric;
  /// ```
  const UnitSystemProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unitSystemProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unitSystemHash();

  @$internal
  @override
  $FutureProviderElement<UnitSystem> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<UnitSystem> create(Ref ref) {
    return unitSystem(ref);
  }
}

String _$unitSystemHash() => r'c48bb738606e6e7a4f6d8ac95a455e81e40e0b69';

import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/data/user_repository.dart';
import '../../../auth/domain/user_preferences.dart';

part 'sweat_profile_controller.g.dart';

/// State for the Sweat Profile settings screen.
///
/// All fields are nullable so they can represent "not yet loaded".
/// The [isLoading] flag is separate from AsyncNotifier loading state
/// to avoid full-screen reloads on field mutations.
class SweatProfileState {
  const SweatProfileState({
    this.sweatRate = SweatRateCat.medium,
    this.sweatSodium = SweatSodiumCat.average,
    this.knownSweatRateMlPerHour,
    this.knownSodiumConcentrationMgPerLiter,
    this.sweatTestDate,
    this.sweatTestSource,
    this.isSaving = false,
  });

  final SweatRateCat sweatRate;
  final SweatSodiumCat sweatSodium;
  final int? knownSweatRateMlPerHour;
  final int? knownSodiumConcentrationMgPerLiter;
  final DateTime? sweatTestDate;
  final String? sweatTestSource;
  final bool isSaving;

  SweatProfileState copyWith({
    SweatRateCat? sweatRate,
    SweatSodiumCat? sweatSodium,
    // Use Object? sentinel for nullable int/DateTime/String so callers can
    // explicitly pass null to clear a field.
    Object? knownSweatRateMlPerHour = _sentinel,
    Object? knownSodiumConcentrationMgPerLiter = _sentinel,
    Object? sweatTestDate = _sentinel,
    Object? sweatTestSource = _sentinel,
    bool? isSaving,
  }) {
    return SweatProfileState(
      sweatRate: sweatRate ?? this.sweatRate,
      sweatSodium: sweatSodium ?? this.sweatSodium,
      knownSweatRateMlPerHour: identical(knownSweatRateMlPerHour, _sentinel)
          ? this.knownSweatRateMlPerHour
          : knownSweatRateMlPerHour as int?,
      knownSodiumConcentrationMgPerLiter: identical(
              knownSodiumConcentrationMgPerLiter, _sentinel)
          ? this.knownSodiumConcentrationMgPerLiter
          : knownSodiumConcentrationMgPerLiter as int?,
      sweatTestDate: identical(sweatTestDate, _sentinel)
          ? this.sweatTestDate
          : sweatTestDate as DateTime?,
      sweatTestSource: identical(sweatTestSource, _sentinel)
          ? this.sweatTestSource
          : sweatTestSource as String?,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// Sentinel object used to distinguish "not passed" from "explicitly null"
/// in nullable copyWith parameters.
const _sentinel = Object();

/// Controller for the Sweat Profile settings screen.
///
/// Follows Andrea Bizzotto's AsyncNotifier pattern. Loads the current
/// [UserProfile] on build and exposes mutation methods that accumulate
/// state locally until [save] is called.
@riverpod
class SweatProfileController extends _$SweatProfileController {
  Future<UserRepository> get _userRepository =>
      ref.read(userRepositoryProvider.future);

  @override
  FutureOr<SweatProfileState> build() async {
    final userRepository = await _userRepository;
    final profile = await userRepository.getCurrentUser();

    return SweatProfileState(
      sweatRate: profile?.sweatRate ?? SweatRateCat.medium,
      sweatSodium: profile?.sweatSodium ?? SweatSodiumCat.average,
      knownSweatRateMlPerHour: profile?.knownSweatRateMlPerHour,
      knownSodiumConcentrationMgPerLiter:
          profile?.knownSodiumConcentrationMgPerLiter,
      sweatTestDate: profile?.sweatTestDate,
      sweatTestSource: profile?.sweatTestSource,
    );
  }

  // ── Local state mutations ──────────────────────────────────────────────────

  void setSweatRate(SweatRateCat rate) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(sweatRate: rate));
  }

  void setSweatSodium(SweatSodiumCat sodium) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(sweatSodium: sodium));
  }

  void setKnownSweatRate(int? mlPerHour) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(knownSweatRateMlPerHour: mlPerHour));
  }

  void setKnownSodiumConcentration(int? mgPerLiter) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(knownSodiumConcentrationMgPerLiter: mgPerLiter),
    );
  }

  void setSweatTestDate(DateTime? date) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(sweatTestDate: date));
  }

  void setSweatTestSource(String? source) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(sweatTestSource: source));
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  /// Validates field constraints and persists the current state to the
  /// [UserRepository] (local Drift + immediate Supabase upload attempt).
  ///
  /// Returns a human-readable error string on validation failure (callers
  /// should show it via [MealvanaSnackbar.showError]), or null on success.
  Future<String?> save() async {
    final current = state.value;
    if (current == null) return 'Profile not loaded yet.';

    // Validate known sweat rate
    final rate = current.knownSweatRateMlPerHour;
    if (rate != null && (rate <= 0 || rate >= 4000)) {
      return 'Known sweat rate must be between 1 and 3999 mL/hr.';
    }

    // Validate known sodium concentration
    final sodium = current.knownSodiumConcentrationMgPerLiter;
    if (sodium != null && (sodium <= 0 || sodium >= 2500)) {
      return 'Sodium concentration must be between 1 and 2499 mg/L.';
    }

    state = AsyncData(current.copyWith(isSaving: true));

    final result = await AsyncValue.guard(() async {
      final userRepository = await _userRepository;
      final profile = await userRepository.getCurrentUser();

      if (profile == null) {
        throw Exception('No user profile found to update.');
      }

      final updated = profile.copyWith(
        sweatRate: current.sweatRate,
        sweatSodium: current.sweatSodium,
        knownSweatRateMlPerHour: current.knownSweatRateMlPerHour,
        knownSodiumConcentrationMgPerLiter:
            current.knownSodiumConcentrationMgPerLiter,
        sweatTestDate: current.sweatTestDate,
        sweatTestSource: current.sweatTestSource,
      );

      await userRepository.updateUserProfile(updated);

      return current.copyWith(isSaving: false);
    });

    if (result.hasError) {
      // Restore non-saving state and propagate error through AsyncValue
      state = AsyncData(current.copyWith(isSaving: false));
      return result.error.toString();
    }

    state = result;
    return null; // success
  }
}

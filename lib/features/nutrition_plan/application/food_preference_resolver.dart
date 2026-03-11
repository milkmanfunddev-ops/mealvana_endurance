import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/domain/user_preferences.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/app_external_deps.dart';

/// Service for resolving user food preferences with safe defaults
class FoodPreferenceResolver {
  FoodPreferenceResolver(this.ref);
  final Ref ref;

  AuthService get _authService => ref.read(authServiceProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  /// Resolve food preferences, falling back to a small, safe default set when none are saved.
  Future<PreferenceResolutionResult> resolveFoodPreferences(String userId) async {
    var preferences = await _authService.getFoodPreferences(userId);
    if (preferences != null && preferences.isNotEmpty) {
      return PreferenceResolutionResult(preferences: preferences, usedDefaults: false);
    }

    // Use defaults instead of failing, and try to persist them for future calls.
    final defaults = buildDefaultFoodPreferences();
    _logger.warning('No food preferences found. Using default set for LLM generation.',
      context: 'FOOD_PREFERENCE_RESOLVER',
      data: {'default_count': defaults.length},
    );

    try {
      final defaultLevels = defaults.map(
        (food, preference) =>
            MapEntry(food, sliderLevelForPreference(preference)),
      );
      await _authService.saveFoodPreferences(
        userId,
        defaults,
        sliderLevels: defaultLevels,
      );
      _logger.info('Default food preferences saved for user',
        context: 'FOOD_PREFERENCE_RESOLVER',
        data: {'user_id': userId, 'count': defaults.length},
      );
    } catch (e, stackTrace) {
      // Non-fatal: proceed with defaults even if persistence fails.
      _logger.warning('Failed to persist default food preferences',
        context: 'FOOD_PREFERENCE_RESOLVER',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return PreferenceResolutionResult(preferences: defaults, usedDefaults: true);
  }

  /// Build default food preferences for users who haven't set any
  Map<String, FoodPreference> buildDefaultFoodPreferences() {
    return {
      // Simple carbs
      'banana': FoodPreference.like,
      'bagel': FoodPreference.like,
      'oatmeal': FoodPreference.like,
      'energy gel': FoodPreference.like,
      'sports drink (carb + electrolytes)': FoodPreference.like,
      'chews': FoodPreference.willingToTry,
      // Hydration/electrolytes
      'water': FoodPreference.like,
      'electrolyte drink mix (electrolyte-only)': FoodPreference.like,
      'electrolyte tablet (electrolyte-only)': FoodPreference.willingToTry,
      // Recovery
      'chocolate milk': FoodPreference.like,
      'protein shake (ready-to-drink)': FoodPreference.like,
      'protein powder (whey)': FoodPreference.willingToTry,
      // Savory carb option
      'pretzels': FoodPreference.willingToTry,
    };
  }
}

/// Result of preference resolution
class PreferenceResolutionResult {
  const PreferenceResolutionResult({
    required this.preferences,
    required this.usedDefaults,
  });

  final Map<String, FoodPreference> preferences;
  final bool usedDefaults;
}

/// Provider for FoodPreferenceResolver
final foodPreferenceResolverProvider = Provider<FoodPreferenceResolver>((ref) {
  return FoodPreferenceResolver(ref);
});

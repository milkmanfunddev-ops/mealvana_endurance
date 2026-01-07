import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/app_external_deps.dart';

/// Theme mode provider for Kyle's design system
/// Manages light/dark theme switching with persistence
final kyleThemeModeProvider = AsyncNotifierProvider<AppThemeModeNotifier, ThemeMode>(() {
  return AppThemeModeNotifier();
});

class AppThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  static const String _themeKey = 'kyle_theme_mode';
  
  @override
  Future<ThemeMode> build() async {
    // Default to dark mode per requirements
    _loadTheme();
    return state.value ?? ThemeMode.dark;
  }
  
  /// Load theme from shared preferences
  void _loadTheme() {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedTheme = prefs.getString(_themeKey);

    ThemeMode themeMode = ThemeMode.dark; // Default

    if (savedTheme != null) {
      // Parse saved theme
      switch (savedTheme) {
        case 'light':
          themeMode = ThemeMode.light;
          break;
        case 'dark':
          themeMode = ThemeMode.dark;
          break;
        case 'system':
          themeMode = ThemeMode.system;
          break;
      }
    }

    state = AsyncValue.data(themeMode);
  }

  /// Set theme mode and persist to storage
  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncValue.data(mode);

    // Persist to shared preferences
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_themeKey, mode.name);
  }
  
  /// Toggle between light and dark themes
  Future<void> toggleTheme() async {
    final currentMode = state.value ?? ThemeMode.dark;
    final newMode = currentMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }
  
  /// Check if current theme is dark
  bool isDark(BuildContext context) {
    final currentMode = state.value ?? ThemeMode.dark;
    switch (currentMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
  }
  
  /// Check if current theme is light
  bool isLight(BuildContext context) {
    return !isDark(context);
  }
}

/// Convenience provider for checking if theme is dark
final isDarkThemeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(kyleThemeModeProvider);
  return themeMode.when(
    data: (mode) => mode == ThemeMode.dark,
    loading: () => true, // Default to dark while loading
    error: (_, __) => true, // Default to dark on error
  );
});

/// Convenience provider for checking if theme is light
final isLightThemeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(kyleThemeModeProvider);
  return themeMode.when(
    data: (mode) => mode == ThemeMode.light,
    loading: () => false, // Default to not light while loading
    error: (_, __) => false, // Default to not light on error
  );
});
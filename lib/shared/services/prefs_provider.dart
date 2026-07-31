import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for SharedPreferences — must be overridden at app startup.
///
/// Defined in its own file (rather than app_external_deps.dart) so that the
/// privacy/consent providers can import it without creating a circular
/// dependency:
///   analytics_tracker.dart → privacy/analytics_consent.dart → prefs_provider.dart
///   app_external_deps.dart → analytics_tracker.dart (no cycle back)
///
/// app_external_deps.dart re-exports this symbol so all existing call sites
/// that import app_external_deps.dart continue to work without change.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with an initialized instance',
  );
});

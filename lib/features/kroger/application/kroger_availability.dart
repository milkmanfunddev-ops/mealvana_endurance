import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/app_config.dart';

/// Dev stays visible per deployment policy. Production requires an explicit
/// release flag; the server independently enforces KROGER_ENABLED and Pro.
final krogerShoppingEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(appConfigProvider).isDevelopment ||
      const bool.fromEnvironment('KROGER_SHOPPING_ENABLED'),
);

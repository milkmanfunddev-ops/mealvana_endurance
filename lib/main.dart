import 'shared/core/bootstrap/bootstrap.dart';

/// Default entry point: a production fallback, not for direct use.
///
/// Use the flavor entry points instead:
/// - Development: `lib/main_dev.dart` (loads `.env.dev.local`)
/// - Production: `lib/main_prod.dart` (loads `.env.prod.local`)
///
/// Defaults to production so a tool that ignores flavors cannot point a
/// release build at dev.
Future<void> main() => bootstrap(AppFlavor.prod);

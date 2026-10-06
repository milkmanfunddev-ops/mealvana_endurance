import 'shared/core/bootstrap/bootstrap.dart';

/// Development flavor entry point. Loads `.env.dev.local`.
///
/// Run: `flutter run --flavor dev -t lib/main_dev.dart`
Future<void> main() => bootstrap(AppFlavor.dev);

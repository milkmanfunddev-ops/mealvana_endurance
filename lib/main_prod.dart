import 'shared/core/bootstrap/bootstrap.dart';

/// Production flavor entry point. Loads `.env.prod.local`.
///
/// Run: `flutter run --flavor prod -t lib/main_prod.dart`
Future<void> main() => bootstrap(AppFlavor.prod);

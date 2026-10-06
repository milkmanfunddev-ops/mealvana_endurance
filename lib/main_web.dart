import 'shared/core/bootstrap/bootstrap.dart';

/// Web entry point. Configuration arrives as `--dart-define` values (web
/// cannot ship an env file); `scripts/build_web.sh` generates them.
///
/// Build command (development):
/// flutter run -d chrome -t lib/main_web.dart \
///   --dart-define=SUPABASE_URL=your_url \
///   --dart-define=SUPABASE_ANON_KEY=your_key \
///   --dart-define=APP_ENVIRONMENT=dev
///
/// Build command (production via Vercel):
/// flutter build web --release --wasm -t lib/main_web.dart \
///   --dart-define=SUPABASE_URL=$SUPABASE_URL \
///   --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
///   --dart-define=SENTRY_DSN=$SENTRY_DSN \
///   --dart-define=APP_ENVIRONMENT=prod
Future<void> main() => bootstrap(AppFlavor.web);

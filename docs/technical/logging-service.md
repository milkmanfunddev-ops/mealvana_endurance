# Logging Architecture

## Overview

Mealvana Endurance now exposes logging through the `AppLogger` abstraction, making it easy to swap implementations in tests while keeping production logs structured and consistent. `PrettyAppLogger` wraps `package:logger` for rich console output, and `NoopAppLogger` keeps unit/widget/integration tests quiet unless they explicitly record log activity.

Key pieces:

- `AppLogger` – interface defining the logging surface (debug/info/warning/error/fatal plus domain helpers such as `api`, `database`, `userAction`, `nutritionPlan`, etc.).
- `PrettyAppLogger` – default implementation. Applies `PrettyPrinter`, honors `kDebugMode` for log levels, and keeps the structured helpers from the legacy singleton.
- `NoopAppLogger` – ignores all messages; useful when tests do not care about console output.
- `appLoggerProvider` – Riverpod provider returning a `PrettyAppLogger` (or whatever override the caller supplies).
- `AppExternalDeps` – bundles the logger alongside analytics, Supabase, and Sentry so call sites can read a single provider for external collaborators.

## Quick Start

### Reading the logger

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';

class NutritionService {
  NutritionService(this.ref);
  final Ref ref;

  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  Future<void> generatePlan() async {
    _logger.info('Generating plan', context: 'NutritionService');
    // ...
  }
}
```

### Overriding in tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/test/helpers/fakes/recording_app_logger.dart';

void main() {
  test('captures expected logs', () {
    final recordingLogger = RecordingAppLogger();

    final container = ProviderContainer(overrides: [
      appLoggerProvider.overrideWithValue(recordingLogger),
    ]);

    container.read(appExternalDepsProvider).logger.info('hello');
    expect(recordingLogger.records.single.message, 'hello');
  });
}
```

### CLI / entrypoint

The app bootstrap no longer calls `LoggingService().initialize(...)`. Simply ensure `PrettyAppLogger` is the default provider (already true in `logging_service.dart`). If you need different defaults (e.g., adjust base level), override `appLoggerProvider` in a custom `ProviderScope` at the root.

```dart
runApp(
  ProviderScope(
    overrides: [
      // Example: quiet logs during golden tests
      if (enableQuietMode) appLoggerProvider.overrideWithValue(const NoopAppLogger()),
    ],
    child: const RootAppWidget(),
  ),
);
```

## API Surface

`AppLogger` keeps the same methods the old singleton exposed. The structured helpers remain unchanged so existing call sites continue to work after switching to dependency injection.

| Method | Purpose |
| ------ | ------- |
| `debug/info/warning/error/fatal` | General-purpose logging with optional `context`, `data`, `error`, `stackTrace`. |
| `api` | Logs HTTP/Edge function calls (endpoint, status code, payloads, durations). |
| `database` | Tracks Drift/SQL operations. |
| `navigation` | Records route changes. |
| `userAction` | Human-facing interactions (button taps, flows). |
| `nutritionPlan` | Domain helper for nutrition workflows. |
| `analytics` | Instrumentation chatter for Mixpanel hooks. |

`PrettyAppLogger` honors `kDebugMode` by default (debug builds log at `Level.debug`, release builds clamp to `Level.info`). It still supports structured payloads and the production filter that mutes verbose logs in release.

## Working With AppExternalDeps

Most services/controllers already depend on `AppExternalDeps`. After the migration, update or create getters that pull the logger from there:

```dart
AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
```

This keeps construction uniform and means tests can override a single provider instead of patching dozens of classes.

## Test Utilities

A new `RecordingAppLogger` lives under `test/helpers/fakes/recording_app_logger.dart`. It captures every log invocation (level, message, optional context/data/error). Use it when you want to assert on logging side effects without printing to stdout.

For suites that do not care about logging, override with `const NoopAppLogger()` to silence noise.

## Migration Notes

1. Delete references to `LoggingService()`/`AppLogger.instance` and replace with provider-backed access (`AppLogger` injected). The singleton was removed.
2. Update providers/repositories to accept an `AppLogger` in the constructor or via `AppExternalDeps`.
3. Remove the `LoggingService().initialize(...)` call from `main.dart`; the provider handles configuration.
4. Update documentation and tests to reference the new abstractions (this file plus the new fake logger).

## Future Improvements

- Wire `PrettyAppLogger` into Sentry breadcrumbs automatically.
- Expose configuration via `AppConfig` so log levels can be tuned per build flavor.
- Consider adding structured JSON output for long-running CLI tasks.
- Build higher-level domain helpers (e.g., `logger.nutritionPlan.startRun(...)`) once coverage stabilizes.

With the dependency injection pattern in place, the repo can now swap log behavior per test, feature, or environment without touching global state.

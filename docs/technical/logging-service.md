# Logging

There is no separate logger. `AppLogger`, `PrettyAppLogger`, `appLoggerProvider`, `DebugLogger`
and `DebugLogStorage` are gone. Every error, warning, note and narrative line goes through
`Report`. See `docs/technical/sentry-integration.md` for which call to make, how to inject it and
how to test it.

## Console output in debug builds

`Report` mirrors each call to the console in debug builds only. Release builds print nothing.

- Output uses `package:logger` with a pretty printer, prefixed with `[area]` when one is given.
- By default the console shows `warning` and above: `fault`, `degraded`, and Report's own
  failures. `note`, `info` and `debug` are hidden.
- To see everything, run with `--dart-define=VERBOSE_APP_LOGS=true`. That lowers the console
  level to `debug`.
- Stack traces print for warnings and errors only.

The flag changes the console only. Sentry, Mixpanel and the debug screen's log receive the same
calls either way.

## Debug screen

The dev debug screen shows the last 500 lines `Report` mirrored, whatever the console level. It
is described in `docs/technical/sentry-integration.md` § The dev debug screen.

## No `print` in catch blocks

The source guard rejects `print(` and `debugPrint(` inside a catch block. The console must never
be the only witness to a failure; report it instead.

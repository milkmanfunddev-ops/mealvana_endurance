/// Riverpod's retry policy for a screen read that must say it failed.
///
/// By default Riverpod 3 retries a failed provider up to ten times with a
/// growing delay, and the provider stays loading the whole time: offline, a
/// list spun 35 to 40 s before its failed text (testing-wave 129, Findings
/// 88-012, 89-011). A read that uses this policy fails at once; the screen
/// shows its error with a Retry the athlete taps.
///
/// `@Riverpod(retry: failFast)`.
Duration? failFast(int retryCount, Object error) => null;

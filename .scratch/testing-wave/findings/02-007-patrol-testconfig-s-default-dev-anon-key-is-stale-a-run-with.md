# 02-007 · Patrol TestConfig's default dev anon key is stale: a run without an env file gets 'Invalid API key' on every auth call

- kind: bug
- status: closed
- ticket: 02
- run: w2-20260923T1442Z
- screen: none
- decision: 

**Steps.**
1. Use `TestConfig.supabaseAnonKey`'s default (integration_test/helpers/test_config.dart), as a bare `patrol test` without `--dart-define-from-file` does.
2. Call dev auth with it (this run copied it into the worktree's env and tried Create Account).

**Expected.**
The default matches dev's current anon key, as its comment promises ("The defaults keep a bare
`patrol test` (no env file) working against dev").

**Actual.**
Dev's legacy anon key has changed: the default is not among the project's keys
(Management API `api-keys`), and signup failed with
`AuthApiException(message: Invalid API key, statusCode: 401)`. Every flow that relies on the
default, and SupabaseProbe with it, fails to authenticate. Runs with the env file are unaffected.

**Evidence.**
- runs/02/console-launch1.log, the `Invalid API key` block under `EmailAuthService.signUpWithEmail`

**Decision quote.**
> 

**Triage.**
Fix ticket 57 (Lee, 2026-09-25). Closed by the retest after it merges.

Closed by the wave lead (2026-09-25, from code): ticket 57 (`38e8f1b3`) removed the built-in key; `TestConfig.supabaseAnonKey` is `String.fromEnvironment` only and `launchApp` stops a run with no env file.

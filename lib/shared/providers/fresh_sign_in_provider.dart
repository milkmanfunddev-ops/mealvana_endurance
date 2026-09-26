import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'fresh_sign_in_provider.g.dart';

/// Whether the session on this device came from a sign-in in THIS process
/// (`AuthChangeEvent.signedIn`), as opposed to a restored one
/// (`initialSession`). Marked by `AuthListenerService` the moment the event
/// arrives, cleared by the first reader that acted on it.
///
/// Testing-wave 134 (Finding 120-001): after Log In the Plan tab showed the
/// account's stale local draft for a second before the first pull replaced
/// it. `MealPlanController` reads this to wait for that pull instead; a
/// normal launch (restored session) stays local-first.
@Riverpod(keepAlive: true)
class FreshSignIn extends _$FreshSignIn {
  @override
  bool build() => false;

  void mark() => state = true;

  void clear() => state = false;
}

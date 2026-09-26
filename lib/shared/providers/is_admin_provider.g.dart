// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'is_admin_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the signed-in user is a team admin (`users.is_admin`, set by hand
/// in the database — mp-144 clause 3). The flag gates admin-only surfaces
/// such as the meal review box; the server enforces the same flag in RLS,
/// so this read is only about what to show.
///
/// One small select per session (`keepAlive`): the cached `user_profiles`
/// row does not carry the flag and a Drift schema bump for a read-only
/// boolean is not worth it. Signed out, or any read failure, means `false`.
/// A sign-in or sign-out that changes the user re-reads, so an athlete who
/// signs in after an admin on the same device never inherits the box.
///
/// A read that failed (an offline start, Finding 89-010) still answers
/// `false` — the gate awaits it — and reads again once the network comes
/// back or the app next resumes, so one bad start does not hide Team review
/// for the whole session.
///
/// The auth stream REPLAYS every past event to each new subscriber (GoTrue's
/// controller is a ReplaySubject). Comparing a replayed event's session to
/// the user captured here re-invalidated this provider on every rebuild, and
/// each rebuild subscribed again: a failing read every 25-70 ms for as long
/// as the network was down, 4,421 times in one run (testing-wave 118-003,
/// 119-004, 120-009). So an event is only a reason to re-read when the user
/// GoTrue holds NOW differs from the one this build read for; a replay of an
/// old sign-out changes nothing.

@ProviderFor(isAdmin)
const isAdminProvider = IsAdminProvider._();

/// Whether the signed-in user is a team admin (`users.is_admin`, set by hand
/// in the database — mp-144 clause 3). The flag gates admin-only surfaces
/// such as the meal review box; the server enforces the same flag in RLS,
/// so this read is only about what to show.
///
/// One small select per session (`keepAlive`): the cached `user_profiles`
/// row does not carry the flag and a Drift schema bump for a read-only
/// boolean is not worth it. Signed out, or any read failure, means `false`.
/// A sign-in or sign-out that changes the user re-reads, so an athlete who
/// signs in after an admin on the same device never inherits the box.
///
/// A read that failed (an offline start, Finding 89-010) still answers
/// `false` — the gate awaits it — and reads again once the network comes
/// back or the app next resumes, so one bad start does not hide Team review
/// for the whole session.
///
/// The auth stream REPLAYS every past event to each new subscriber (GoTrue's
/// controller is a ReplaySubject). Comparing a replayed event's session to
/// the user captured here re-invalidated this provider on every rebuild, and
/// each rebuild subscribed again: a failing read every 25-70 ms for as long
/// as the network was down, 4,421 times in one run (testing-wave 118-003,
/// 119-004, 120-009). So an event is only a reason to re-read when the user
/// GoTrue holds NOW differs from the one this build read for; a replay of an
/// old sign-out changes nothing.

final class IsAdminProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Whether the signed-in user is a team admin (`users.is_admin`, set by hand
  /// in the database — mp-144 clause 3). The flag gates admin-only surfaces
  /// such as the meal review box; the server enforces the same flag in RLS,
  /// so this read is only about what to show.
  ///
  /// One small select per session (`keepAlive`): the cached `user_profiles`
  /// row does not carry the flag and a Drift schema bump for a read-only
  /// boolean is not worth it. Signed out, or any read failure, means `false`.
  /// A sign-in or sign-out that changes the user re-reads, so an athlete who
  /// signs in after an admin on the same device never inherits the box.
  ///
  /// A read that failed (an offline start, Finding 89-010) still answers
  /// `false` — the gate awaits it — and reads again once the network comes
  /// back or the app next resumes, so one bad start does not hide Team review
  /// for the whole session.
  ///
  /// The auth stream REPLAYS every past event to each new subscriber (GoTrue's
  /// controller is a ReplaySubject). Comparing a replayed event's session to
  /// the user captured here re-invalidated this provider on every rebuild, and
  /// each rebuild subscribed again: a failing read every 25-70 ms for as long
  /// as the network was down, 4,421 times in one run (testing-wave 118-003,
  /// 119-004, 120-009). So an event is only a reason to re-read when the user
  /// GoTrue holds NOW differs from the one this build read for; a replay of an
  /// old sign-out changes nothing.
  const IsAdminProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isAdminProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isAdminHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return isAdmin(ref);
  }
}

String _$isAdminHash() => r'6629a6224ec297b4ad012d51959d74abb2b9020c';

/// Facts about the signup's emailed code and the address it went to
/// (testing-wave develop-2026-10 ticket 21).
library;

/// How long GoTrue accepts a signup code after it is sent.
///
/// Hosted dev `mailer_otp_exp` is 3600 s (read with the Management API on
/// 2026-10-07); the local stack says the same (`supabase/config.toml`,
/// `[auth.email] otp_expiry = 3600`). GoTrue refuses a wrong code and a stale
/// one with the same answer, so the verify screen tells them apart by the
/// code's age against this number (01-002).
const Duration signupCodeLifetime = Duration(hours: 1);

/// The address as `public.users.email` stores it: trimmed and lowercase, or
/// null when nothing is left (01-009). Applied where the column is written
/// (`UserProfile.toJson` and the local Drift row), never on the screens.
String? normaliseEmail(String? email) {
  if (email == null) return null;
  final trimmed = email.trim();
  return trimmed.isEmpty ? null : trimmed.toLowerCase();
}

/// Helpers for choosing the best contact identity to attach to Wiredash
/// feedback / bug reports.
///
/// Apple Sign In frequently hands us a private-relay address
/// (`…@privaterelay.appleid.com`) as the auth email, even when the user has
/// entered a real email in our own profile. These helpers prefer any real
/// address over a relay one, only falling back to the relay address when it is
/// the only email we have.
library;

const _privateRelaySuffix = 'privaterelay.appleid.com';

/// Returns true when [email] is an Apple private-relay address.
bool isPrivateRelayEmail(String? email) {
  final e = email?.trim().toLowerCase();
  return e != null && e.endsWith(_privateRelaySuffix);
}

/// Picks the best contact email from [candidates] (in priority order).
///
/// Prefers the first non-empty address that is NOT an Apple private-relay
/// address; only falls back to a relay address if that is all we have. Returns
/// null when there are no usable emails.
String? resolveSupportEmail(Iterable<String?> candidates) {
  final cleaned = <String>[
    for (final c in candidates)
      if (c != null && c.trim().isNotEmpty) c.trim(),
  ];
  if (cleaned.isEmpty) return null;
  for (final email in cleaned) {
    if (!isPrivateRelayEmail(email)) return email;
  }
  // Everything we have is a relay address — use the first as a last resort.
  return cleaned.first;
}

/// Builds a display name from the user's profile fields, preferring
/// first/last name and falling back to a sender name. Returns null when no
/// name is available.
String? resolveSupportName({
  String? firstName,
  String? lastName,
  String? senderName,
}) {
  final parts = <String>[
    for (final p in [firstName, lastName])
      if (p != null && p.trim().isNotEmpty) p.trim(),
  ];
  final full = parts.join(' ').trim();
  if (full.isNotEmpty) return full;
  final sender = senderName?.trim();
  return (sender != null && sender.isNotEmpty) ? sender : null;
}

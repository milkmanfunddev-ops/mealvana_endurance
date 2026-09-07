/// Transition identity helpers.
///
/// SSOT: `docs/ssot/spec/domain/brick.md` R8 (RATIFIED Xuan 2026-08-31):
/// a brick's transitions are `T1 … T(n-1)` **by position** — the gap after
/// leg i is `T{i}`; the sport pair (e.g. "bike→run") is a display label
/// only, carrying no identity. Consumers key transitions positionally and
/// tolerate legacy spellings ("t1", "1") by digit extraction — the Dart twin
/// of `normalizeTransitionName` in
/// `supabase/functions/generate-nutrition-plan-v3/brick-handler.ts`.
library;

/// Canonicalize a wire transition name to `T<digits>`, or pass through a
/// name that carries no digits. Null/blank in, null out.
String? normalizeTransitionName(String? name) {
  if (name == null) return null;
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^t?(\d+)$', caseSensitive: false).firstMatch(trimmed);
  if (match == null) return trimmed;
  return 'T${match.group(1)}';
}

/// The positional key for the gap after segment [index] (0-based): `T{i+1}`.
String transitionKeyForIndex(int index) => 'T${index + 1}';

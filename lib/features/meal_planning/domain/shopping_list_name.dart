/// Shopping list names (ticket 130, Finding 89-015, Lee: all four).
///
/// The same rules `renameList` in `_shared/vana/shopping.ts` applies, so the
/// name the tab shows the moment Save is tapped is the name the server
/// keeps: whitespace collapsed, capped at [shoppingListNameMax] like plan
/// names (`PLAN_NAME_MAX`), and a name another list already has takes the
/// next free " (n)".
library;

/// The cap, the same as a plan name's.
const int shoppingListNameMax = 60;

final _suffix = RegExp(r' \((\d+)\)$');
final _spaces = RegExp(r'\s+');

String _key(String name) => name.trim().toLowerCase();

/// Whitespace collapsed, trimmed, cut at the cap.
String cleanShoppingListName(String name) {
  final clean = name.replaceAll(_spaces, ' ').trim();
  return clean.length > shoppingListNameMax
      ? clean.substring(0, shoppingListNameMax).trimRight()
      : clean;
}

/// [name] itself when no list in [taken] has it (case-insensitive); else
/// its base (a typed " (n)" dropped) with the next free number, kept under
/// the cap with the suffix included.
String uniqueShoppingListName(String name, Iterable<String> taken) {
  final has = {for (final t in taken) _key(t)};
  if (!has.contains(_key(name))) return name;
  final base = name.replaceFirst(_suffix, '');
  for (var n = 2; ; n++) {
    final suffix = ' ($n)';
    final room = shoppingListNameMax - suffix.length;
    final stem = base.length > room ? base.substring(0, room).trimRight() : base;
    final candidate = '$stem$suffix';
    if (!has.contains(_key(candidate))) return candidate;
  }
}

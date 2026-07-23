List<String> tokenizeSearchQuery(String query) {
  return query
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .split(' ')
      .where((t) => t.isNotEmpty)
      .toList();
}

String normalizeSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool matchesSearchTokens(String haystack, List<String> queryTokens) {
  if (queryTokens.isEmpty) return true;
  final normalized = normalizeSearchText(haystack);
  for (final token in queryTokens) {
    final singular = token.endsWith('s') && token.length > 3
        ? token.substring(0, token.length - 1)
        : token;
    if (!normalized.contains(token) && !normalized.contains(singular)) {
      return false;
    }
  }
  return true;
}

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

/// The digits of [query] when it is a product barcode typed into a search
/// box (EAN-8, UPC-A, EAN-13 or GTIN-14: 8, 12, 13 or 14 digits, spaces and
/// dashes allowed), otherwise null. A number is not a name, so the caller
/// looks it up by barcode instead of searching names (testing-wave 28-004).
String? barcodeDigits(String query) {
  final compact = query.replaceAll(RegExp(r'[\s-]'), '');
  if (compact.isEmpty || !RegExp(r'^\d+$').hasMatch(compact)) return null;
  return const {8, 12, 13, 14}.contains(compact.length) ? compact : null;
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

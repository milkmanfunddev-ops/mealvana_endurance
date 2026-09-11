/// Decides whether the "What's new" glass sheet shows on this launch.
///
/// Pure so it is unit-testable without prefs or package info. The sheet is
/// tied to an ANNOUNCEMENT version (content key `whats_new.version`), not
/// the app version: it shows once per announcement, on fresh installs (no
/// record) and on updates that reach that version — and stays quiet on later
/// releases until someone bumps the key. An empty announcement version
/// disables it.
bool shouldShowWhatsNew({
  required String appVersion,
  required String announcementVersion,
  required String? lastShownVersion,
}) {
  final announced = announcementVersion.trim();
  if (announced.isEmpty) return false;
  if (lastShownVersion == announced) return false;
  return compareVersions(appVersion, announced) >= 0;
}

/// Dotted numeric compare (`1.26.0` vs `1.26`), ignoring a `+build` suffix.
/// Non-numeric segments compare as 0. Returns <0, 0, >0.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .split('.')
      .map((s) => int.tryParse(s.trim()) ?? 0)
      .toList();
  final pa = parse(a), pb = parse(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

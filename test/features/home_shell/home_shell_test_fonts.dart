// Shared font loading for the home-shell conformance suites: real Sansita /
// Apercu / Compadre (Ahem's square glyphs overflow the 390-px frame and
// goldens render at token-resolved type), MaterialIcons, and FontAwesome
// solid (the tab-bar glyphs).
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
  }
  await loader.load();
}

/// Resolve a file inside a pub package via `.dart_tool/package_config.json`.
String? _packageFontPath(String package, String relative) {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final match = RegExp(
    '"name":\\s*"$package",\\s*"rootUri":\\s*"([^"]+)"',
  ).firstMatch(config.readAsStringSync());
  if (match == null) return null;
  final root = Uri.parse(match.group(1)!);
  final dir = root.isAbsolute
      ? root.toFilePath()
      : Directory('.dart_tool').uri.resolveUri(root).toFilePath();
  final path = '$dir/$relative';
  return File(path).existsSync() ? path : null;
}

Future<void> loadHomeShellFonts() async {
  await _loadFont('Sansita', [
    'assets/fonts/Sansita/Sansita-Regular.otf',
    'assets/fonts/Sansita/Sansita-Bold.ttf',
  ]);
  await _loadFont('Apercu', [
    'assets/fonts/Apercu/Apercu Regular.otf',
    'assets/fonts/Apercu/Apercu-Medium.otf',
    'assets/fonts/Apercu/Apercu-Bold.otf',
  ]);
  await _loadFont('Compadre', [
    'assets/fonts/Compadre/Compadre-Demo-Regular.otf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final materialIcons = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (materialIcons.existsSync()) {
      await _loadFont('MaterialIcons', [materialIcons.path]);
    }
  }
  for (final (family, file) in [
    ('FontAwesomeRegular', 'Font-Awesome-7-Free-Regular-400.otf'),
    ('FontAwesomeSolid', 'Font-Awesome-7-Free-Solid-900.otf'),
  ]) {
    final fa = _packageFontPath('font_awesome_flutter', 'lib/fonts/$file');
    if (fa != null) {
      await _loadFont('packages/font_awesome_flutter/$family', [fa]);
    }
  }
}

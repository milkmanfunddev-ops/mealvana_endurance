/// Test doubles for the content system in meal-planning widget tests.
///
/// [TestContentService] serves the exact strings from
/// `assets/config/content_defaults.json` (flattened to dotted keys), so a
/// widget test asserts what the app will actually render — no hand-copied
/// labels that drift.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';

class TestContentService extends ContentService {
  TestContentService(super.ref, this.values);

  final Map<String, String> values;

  @override
  String getValue(String key, {String? defaultValue}) =>
      values[key] ?? defaultValue ?? key;
}

/// Loads `assets/config/content_defaults.json` from the repo, flattened.
Map<String, String> loadDefaultContent() {
  final raw = File('assets/config/content_defaults.json').readAsStringSync();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw StateError('content_defaults.json is not an object');
  }
  final flat = <String, String>{};
  void walk(Map<String, dynamic> node, String prefix) {
    for (final entry in node.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        walk(entry.value as Map<String, dynamic>, key);
      } else if (entry.value is String) {
        flat[key] = entry.value as String;
      }
    }
  }

  walk(decoded, '');
  return flat;
}

/// Create function for `contentServiceProvider.overrideWith(...)` — the
/// real JSON values, no backend.
TestContentService testContentService(Ref ref) =>
    TestContentService(ref, loadDefaultContent());

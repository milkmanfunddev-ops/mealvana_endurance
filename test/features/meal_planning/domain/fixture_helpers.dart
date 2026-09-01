import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/wire_record.dart';

/// Contract fixtures copied verbatim from the prototype
/// (`mealplanning-prototype/packages/web/tests/fixtures`, tag `contract-v1`).
/// They are the exact JSON the endpoints returned, so parsers are tested
/// against real wire shapes rather than hand-typed ones.
const fixturesDir = 'test/features/meal_planning/fixtures';

Map<String, dynamic> loadFixture(String name) {
  final file = File('$fixturesDir/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Drops null-valued keys recursively so "absent" and "present-and-null"
/// compare equal. TS optional members (`kind?`, `question?`…) are emitted by
/// the server as either, and our `toJson` picks one convention per field.
Object? stripNulls(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.value != null) entry.key.toString(): stripNulls(entry.value),
    };
  }
  if (value is List) return value.map(stripNulls).toList();
  return value;
}

/// Human-readable list of paths where two JSON trees differ.
List<String> jsonDiff(Object? expected, Object? actual, [String path = r'$']) {
  final out = <String>[];
  if (expected is Map && actual is Map) {
    for (final key in {...expected.keys, ...actual.keys}) {
      if (!expected.containsKey(key)) {
        out.add('$path.$key: unexpected ${actual[key]}');
      } else if (!actual.containsKey(key)) {
        out.add('$path.$key: missing (expected ${expected[key]})');
      } else {
        out.addAll(jsonDiff(expected[key], actual[key], '$path.$key'));
      }
    }
  } else if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      out.add('$path: length ${expected.length} != ${actual.length}');
    }
    final n = expected.length < actual.length ? expected.length : actual.length;
    for (var i = 0; i < n; i++) {
      out.addAll(jsonDiff(expected[i], actual[i], '$path[$i]'));
    }
  } else if (!deepJsonEquals(expected, actual)) {
    out.add('$path: $expected != $actual');
  }
  return out;
}

/// Asserts `actual` round-trips `expected` with no field lost or invented
/// (after null-stripping both sides).
void expectRoundTrip(Object? expected, Object? actual, {String? reason}) {
  final diff = jsonDiff(stripNulls(expected), stripNulls(actual));
  expect(diff, isEmpty, reason: reason ?? diff.join('\n'));
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Pins `ios/Runner/PrivacyInfo.xcprivacy` to the live App Store Connect label.
///
/// The manifest and the label are two separate declarations that must agree. A
/// silent drift between them is exactly how the app ended up shipping a
/// manifest that under-declared Health/Fitness as "App Functionality only"
/// while Mixpanel was receiving the user's weight — and how the App Store label
/// nearly got answered from a doc claiming we collect nothing.
///
/// If you change the manifest, change this test AND the live label together.
/// Last reconciled 2026-07-13 (all 9 types agree).
void main() {
  /// (linked, purposes) exactly as declared on the live label.
  const expected = <String, (bool, Set<String>)>{
    'Health': (true, {'AppFunctionality', 'Analytics'}),
    'Fitness': (true, {'AppFunctionality', 'Analytics'}),
    'CrashData': (true, {'AppFunctionality', 'Analytics'}),
    'PerformanceData': (true, {'AppFunctionality', 'Analytics'}),
    'OtherDiagnosticData': (true, {'AppFunctionality', 'Analytics'}),
    'ProductInteraction': (true, {'AppFunctionality', 'Analytics'}),
    'UserID': (true, {'AppFunctionality', 'Analytics'}),
    // NOT linked: coordinates are cached only in the local Drift
    // `weather_forecasts` table (no user_id, never synced, never sent to
    // Mixpanel), so nothing associates them with the user's identity.
    'PreciseLocation': (false, {'AppFunctionality'}),
    'EmailAddress': (true, {'AppFunctionality'}),
  };

  late Map<String, (bool, Set<String>)> declared;
  late XmlElement root;

  setUpAll(() {
    final file = File('ios/Runner/PrivacyInfo.xcprivacy');
    expect(file.existsSync(), isTrue, reason: 'privacy manifest is missing');
    // <plist> wraps the top-level <dict> that actually holds the keys.
    root = XmlDocument.parse(
      file.readAsStringSync(),
    ).rootElement.findElements('dict').single;
    declared = _parseCollectedDataTypes(root);
  });

  test('declares exactly the 9 expected data types', () {
    expect(declared.keys.toSet(), expected.keys.toSet());
  });

  test('every type matches the live App Store Connect label', () {
    for (final entry in expected.entries) {
      final type = entry.key;
      final (expectedLinked, expectedPurposes) = entry.value;
      final actual = declared[type];

      expect(actual, isNotNull, reason: '$type is not declared at all');
      final (actualLinked, actualPurposes) = actual!;

      // Compared field-by-field: Set has identity equality in Dart, so
      // comparing the records directly would fail even on identical contents.
      expect(
        actualLinked,
        expectedLinked,
        reason:
            '$type: linked flag disagrees with the live App Store label. '
            'Manifest and label must be reconciled together — see docs/privacy/.',
      );
      expect(
        actualPurposes,
        unorderedEquals(expectedPurposes),
        reason:
            '$type: purposes disagree with the live App Store label. '
            'Manifest and label must be reconciled together — see docs/privacy/.',
      );
    }
  });

  test('Health and Fitness declare the Analytics purpose', () {
    // identifyUser() sends Gender / Age / Weight (lbs) / Gut Training Level to
    // Mixpanel People. If those properties are ever removed from
    // analytics_tracker.dart, drop Analytics here AND tighten the in-app
    // consent copy — but until then, omitting it under-declares.
    for (final type in ['Health', 'Fitness']) {
      expect(
        declared[type]!.$2,
        contains('Analytics'),
        reason: '$type reaches Mixpanel via identifyUser()',
      );
    }
  });

  test('nothing is declared as tracking (no IDFA, no ad SDKs → no ATT)', () {
    expect(_boolAfter(root, 'NSPrivacyTracking'), isFalse);

    for (final dict in _collectedDataTypeDicts(root)) {
      expect(
        _boolAfter(dict, 'NSPrivacyCollectedDataTypeTracking'),
        isFalse,
        reason: 'Declaring tracking would require the ATT prompt.',
      );
    }
  });
}

List<XmlElement> _collectedDataTypeDicts(XmlElement root) {
  final array = _valueAfter(root, 'NSPrivacyCollectedDataTypes');
  return array!.findElements('dict').toList();
}

Map<String, (bool, Set<String>)> _parseCollectedDataTypes(XmlElement root) {
  final result = <String, (bool, Set<String>)>{};

  for (final dict in _collectedDataTypeDicts(root)) {
    final type = _valueAfter(
      dict,
      'NSPrivacyCollectedDataType',
    )!.innerText.replaceFirst('NSPrivacyCollectedDataType', '');

    final linked = _boolAfter(dict, 'NSPrivacyCollectedDataTypeLinked');

    final purposes = _valueAfter(dict, 'NSPrivacyCollectedDataTypePurposes')!
        .findElements('string')
        .map(
          (e) =>
              e.innerText.replaceFirst('NSPrivacyCollectedDataTypePurpose', ''),
        )
        .toSet();

    result[type] = (linked, purposes);
  }
  return result;
}

/// In a plist `<dict>`, a `<key>` is followed by its value element as a sibling.
XmlElement? _valueAfter(XmlElement dict, String key) {
  for (final child in dict.childElements) {
    if (child.name.local == 'key' && child.innerText == key) {
      return child.nextElementSibling;
    }
  }
  return null;
}

bool _boolAfter(XmlElement dict, String key) =>
    _valueAfter(dict, key)!.name.local == 'true';

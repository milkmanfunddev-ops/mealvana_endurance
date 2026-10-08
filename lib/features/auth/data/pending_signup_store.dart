import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/report/report.dart';
import '../domain/pending_signup.dart';

part 'pending_signup_store.g.dart';

@Riverpod(keepAlive: true)
PendingSignupStore pendingSignupStore(Ref ref) => PendingSignupStore(
  prefs: ref.read(appExternalDepsProvider).sharedPreferences,
  report: ref.read(reportProvider),
);

/// What [PendingSignupStore.read] found.
typedef PendingSignupLookup = ({PendingSignup? record, bool unreadable});

/// Where a [PendingSignup] lives between Create Account and the code
/// (testing-wave develop-2026-10 ticket 42, 30-007).
///
/// The record (address, OTP type, send time, the onboarding answers) is JSON
/// in SharedPreferences under [prefsKey], beside the onboarding snapshot
/// (`OnboardingSnapshotService.prefsKey`). The upgrade path's deferred
/// password (GoTrue refuses it until the address is confirmed) goes to the
/// Keychain / Keystore under [passwordKey], never to SharedPreferences (Lee,
/// 2026-10-08: kept until the code is used or the signup is abandoned).
///
/// Never throws to its callers: every failure becomes a note (D9) and a
/// false / empty answer. No note carries the address or the password.
///
/// Running twice at once: each method is one read or one write per key, so
/// two writers end with the later one's record; [markResent] after [clear]
/// finds no record and writes nothing.
class PendingSignupStore {
  PendingSignupStore({
    required SharedPreferences prefs,
    required Report report,
    FlutterSecureStorage secureStorage = _defaultSecureStorage,
  }) : _prefs = prefs,
       _report = report,
       _secure = secureStorage;

  static const prefsKey = 'pending_signup_v1';
  static const passwordKey = 'pending_signup_password';

  /// `first_unlock`, as the internal-device flag uses: a cold launch in the
  /// background after a reboot can still read it.
  static const _defaultSecureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final SharedPreferences _prefs;
  final Report _report;
  final FlutterSecureStorage _secure;

  /// The record as this process last read or wrote it; null once cleared.
  /// The root redirect reads it synchronously, so a stale launch decision
  /// never reopens a signup that has since been verified or abandoned.
  PendingSignup? _current;

  /// Whether a pending signup is open, as far as this process knows.
  bool get isOpen => _current != null;

  /// The stored record. `unreadable` is true when something is stored but
  /// cannot be decoded (or the read itself failed); the caller clears it.
  Future<PendingSignupLookup> read() async {
    try {
      final raw = _prefs.getString(prefsKey);
      if (raw == null) {
        _current = null;
        return (record: null, unreadable: false);
      }
      final record = PendingSignup.fromJson(_decode(raw));
      _current = record;
      return (record: record, unreadable: record == null);
    } catch (e) {
      await _report.noteFailed('read', e);
      return (record: null, unreadable: true);
    }
  }

  /// The upgrade path's deferred password, or null (plain path, none stored,
  /// or the Keychain refused).
  Future<String?> readPassword() async {
    try {
      return await _secure.read(key: passwordKey);
    } catch (e) {
      await _report.noteFailed('read_password', e);
      return null;
    }
  }

  /// Stores [record], and [password] beside it in secure storage. A null
  /// [password] removes any stored one, so a plain-path record never sits
  /// next to an earlier upgrade's password. True when both writes landed.
  Future<bool> write(PendingSignup record, {String? password}) async {
    var ok = true;
    try {
      ok = await _prefs.setString(prefsKey, jsonEncode(record.toJson()));
      if (ok) _current = record;
    } catch (e) {
      await _report.noteFailed('write', e);
      return false;
    }
    try {
      if (password != null && password.isNotEmpty) {
        await _secure.write(key: passwordKey, value: password);
      } else {
        await _secure.delete(key: passwordKey);
      }
    } catch (e) {
      await _report.noteFailed('write_password', e);
      ok = false;
    }
    _report.info(
      'Pending signup recorded',
      area: 'auth',
      data: {'otp_type': record.otpType, 'stored': ok},
    );
    return ok;
  }

  /// A Resend sent a new code to [email] at [at]: the record's send time
  /// moves so a relaunch counts Resend down from the new code. A record for
  /// another address, or none, is left alone. True when it moved.
  Future<bool> markResent(DateTime at, {required String email}) async {
    final lookup = await read();
    final record = lookup.record;
    if (record == null ||
        record.email.trim().toLowerCase() != email.trim().toLowerCase()) {
      return false;
    }
    try {
      final moved = record.copyWith(codeSentAt: at);
      final ok = await _prefs.setString(prefsKey, jsonEncode(moved.toJson()));
      if (ok) _current = moved;
      return ok;
    } catch (e) {
      await _report.noteFailed('mark_resent', e);
      return false;
    }
  }

  /// Removes the record and the password, and says why with a note:
  /// `verified`, `different_email`, `log_in`, or a launch reason.
  Future<void> clear({required String reason}) async {
    var hadRecord = false;
    try {
      hadRecord = _prefs.getString(prefsKey) != null;
      await _prefs.remove(prefsKey);
      _current = null;
    } catch (e) {
      await _report.noteFailed('clear', e);
    }
    try {
      await _secure.delete(key: passwordKey);
    } catch (e) {
      await _report.noteFailed('clear_password', e);
    }
    await _report.note(
      'Pending signup cleared',
      area: 'auth',
      data: {'reason': reason, 'had_record': hadRecord},
    );
  }

  static Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

}

extension on Report {
  /// One note per failed store step: the step name and the error's type,
  /// never the address or the password (D9).
  Future<void> noteFailed(String step, Object error) => note(
    'Pending signup store: $step failed',
    area: 'auth',
    data: {'step': step, 'error_type': error.runtimeType.toString()},
  );
}

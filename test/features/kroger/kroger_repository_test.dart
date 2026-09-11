import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mealvana_endurance/features/kroger/data/kroger_repository.dart';
import 'package:mealvana_endurance/features/kroger/domain/kroger_models.dart';

class FakeRemote extends KrogerRemote {
  FakeRemote() : super(SupabaseClient('https://example.supabase.co', 'test'));
  int saves = 0;
  Future<int> Function(KrogerDraft)? onSave;
  Future<Map<String, dynamic>?> Function(String)? onLoad;
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? onCall;
  @override
  Future<int> save(KrogerDraft draft) async {
    saves++;
    return onSave == null ? draft.revision + 1 : await onSave!(draft);
  }

  @override
  Future<Map<String, dynamic>?> load(String planId) async =>
      onLoad == null ? null : await onLoad!(planId);
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async => onCall == null
      ? {
          'available': true,
          'connected': true,
          'environment': 'certification',
          'receipt': null,
        }
      : await onCall!(action, data);
}

void main() {
  late KrogerRepository repo;
  late FakeRemote remote;
  const draft = KrogerDraft(
    planId: 'plan',
    lines: [KrogerLine(id: '1', name: 'Milk', requiredQty: '2 l')],
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    remote = FakeRemote();
    repo = KrogerRepository(await SharedPreferences.getInstance(), remote);
  });
  test(
    'offline draft survives reconstruction and is isolated by account',
    () async {
      await repo.saveLocal('a', draft);
      expect(
        KrogerRepository(repo.prefs, remote).load('a', 'plan').dirty,
        true,
      );
      expect(repo.load('b', 'plan').lines, isEmpty);
    },
  );
  test('failed upload preserves dirty edits', () async {
    await repo.saveLocal('a', draft);
    remote.onSave = (_) async => throw const KrogerException('unavailable');
    await expectLater(
      repo.ensureSynced('a', 'plan'),
      throwsA(isA<KrogerException>()),
    );
    expect(repo.load('a', 'plan').dirty, true);
  });
  test(
    'successful upload advances revision, unchanged save stays clean',
    () async {
      await repo.saveLocal('a', draft);
      final result = await repo.ensureSynced('a', 'plan');
      expect(result.revision, 1);
      expect((await repo.saveLocal('a', result)).dirty, false);
    },
  );
  test(
    'edits during upload survive and concurrent sync calls share one upload',
    () async {
      await repo.saveLocal('a', draft);
      final pending = Completer<int>();
      remote.onSave = (_) => pending.future;
      final first = repo.ensureSynced('a', 'plan');
      final second = repo.ensureSynced('a', 'plan');
      await repo.saveLocal('a', draft.copyWith(modality: 'PICKUP'));
      pending.complete(1);
      await Future.wait([first, second]);
      expect(remote.saves, 1);
      expect(repo.load('a', 'plan').modality, 'PICKUP');
      expect(repo.load('a', 'plan').dirty, true);
      expect(repo.load('a', 'plan').revision, 1);
    },
  );
  test('edits during cloud read are not overwritten', () async {
    final pending = Completer<Map<String, dynamic>?>();
    remote.onLoad = (_) => pending.future;
    final sync = repo.ensureSynced('a', 'plan');
    await repo.saveLocal('a', draft.copyWith(modality: 'PICKUP'));
    pending.complete({'revision': 2, 'draft': draft.toJson()});
    expect((await sync).modality, 'PICKUP');
    expect(repo.load('a', 'plan').dirty, true);
  });
  test('CAS conflict does not discard local draft', () async {
    await repo.saveLocal('a', draft);
    remote.onSave = (_) async => throw const KrogerException('draft_conflict');
    await expectLater(
      repo.ensureSynced('a', 'plan'),
      throwsA(
        isA<KrogerException>().having((e) => e.code, 'code', 'draft_conflict'),
      ),
    );
    expect(repo.load('a', 'plan').lines.single.name, 'Milk');
  });
  group('KrogerRemote', () {
    KrogerRemote answering(http.Response Function() respond) => KrogerRemote(
      SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient((_) async => respond()),
      ),
    );
    Matcher code(String c) =>
        throwsA(isA<KrogerException>().having((e) => e.code, 'code', c));

    test("the server's own code reaches the controller", () async {
      final remote = answering(
        () => http.Response(
          jsonEncode({'error': 'invalid_action'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      );
      await expectLater(remote.call('location'), code('invalid_action'));
    });
    test('an answer with no code is not blamed on Kroger', () async {
      // A crashed function or a gateway page: Mealvana answered, badly.
      final remote = answering(() => http.Response('Internal error', 502));
      await expectLater(remote.call('status'), code('unexpected'));
    });
    test(
      'a request that never got an answer is left for the controller',
      () async {
        // The controller is what tells a network failure from a bug.
        final remote = answering(
          () => throw http.ClientException('Connection refused'),
        );
        await expectLater(
          remote.call('status'),
          throwsA(isA<http.ClientException>()),
        );
      },
    );
  });
}

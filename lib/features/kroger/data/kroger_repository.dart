import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/app_external_deps.dart';
import '../domain/kroger_models.dart';

part 'kroger_repository.g.dart';

@riverpod
KrogerRepository krogerRepository(Ref ref) {
  final deps = ref.watch(appExternalDepsProvider);
  return KrogerRepository(
    deps.sharedPreferences,
    KrogerRemote(deps.supabaseClient),
  );
}

class KrogerRemote {
  KrogerRemote(this.client);
  final SupabaseClient client;
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    try {
      final result = await client.functions.invoke(
        'kroger',
        body: {'action': action, ...data},
      );
      final body = Map<String, dynamic>.from(result.data as Map);
      if (body['error'] case final String error) throw KrogerException(error);
      return body;
    } on FunctionException catch (e) {
      // The function answered, so Kroger was not necessarily involved: a
      // crash or a gateway page carries no code, and is not Kroger's fault.
      throw KrogerException(
        e.details is Map
            ? (e.details as Map)['error'] as String? ?? 'unexpected'
            : 'unexpected',
      );
    }
  }

  Future<Map<String, dynamic>?> load(String planId) async => await client
      .from('kroger_drafts')
      .select('revision,draft')
      .eq('id', planId)
      .maybeSingle();
  Future<int> save(KrogerDraft draft) async {
    try {
      return (await client.rpc(
                'save_kroger_draft',
                params: {
                  'p_id': draft.planId,
                  'p_revision': draft.revision,
                  'p_draft': draft.toJson(),
                },
              )
              as num)
          .toInt();
    } on PostgrestException catch (e) {
      if (e.message.contains('draft_conflict')) {
        throw const KrogerException('draft_conflict');
      }
      rethrow;
    }
  }
}

/// User/plan-scoped durable local draft. Dirty revisions survive offline edits.
/// On-demand sync uses server compare-and-swap; drafts contain no OAuth tokens.
class KrogerRepository {
  KrogerRepository(this.prefs, this.remote);
  final SharedPreferences prefs;
  final KrogerRemote remote;
  final Map<String, Future<KrogerDraft>> _syncing = {};
  String _key(String user, String plan) => 'kroger.draft.$user.$plan';
  KrogerDraft load(String user, String plan) {
    final raw = prefs.getString(_key(user, plan));
    if (raw == null) return KrogerDraft(planId: plan);
    return KrogerDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<KrogerDraft> saveLocal(String user, KrogerDraft draft) async {
    final existing = load(user, draft.planId);
    if (jsonEncode(existing.toJson()) == jsonEncode(draft.toJson())) {
      return existing;
    }
    final next = draft.copyWith(dirty: true);
    await _store(user, next);
    return next;
  }

  Future<void> _store(String user, KrogerDraft draft) async {
    if (!await prefs.setString(
      _key(user, draft.planId),
      jsonEncode(draft.toJson()),
    )) {
      throw const KrogerException('local_save_failed');
    }
  }

  Future<KrogerDraft> ensureSynced(String user, String plan) async {
    final key = _key(user, plan);
    final active = _syncing[key];
    if (active != null) return active;
    final operation = _sync(user, plan);
    _syncing[key] = operation;
    try {
      return await operation;
    } finally {
      _syncing.remove(key);
    }
  }

  Future<KrogerDraft> _sync(String user, String plan) async {
    final local = load(user, plan);
    if (local.dirty) {
      final version = await remote.save(local);
      final current = load(user, plan);
      // Preserve edits made while the upload was in flight, but advance their base revision.
      final same = jsonEncode(current.toJson()) == jsonEncode(local.toJson());
      final next = current.copyWith(revision: version, dirty: !same);
      await _store(user, next);
      return next;
    }
    return await loadRemote(user, plan, replace: false);
  }

  Future<KrogerDraft> loadRemote(
    String user,
    String plan, {
    bool replace = true,
  }) async {
    final row = await remote.load(plan);
    if (!replace && load(user, plan).dirty) return load(user, plan);
    if (row == null) return load(user, plan);
    final draft = KrogerDraft.fromJson(
      Map<String, dynamic>.from(row['draft'] as Map),
    ).copyWith(revision: row['revision'] as int, dirty: false);
    if (draft.planId != plan) throw const KrogerException('unexpected');
    await _store(user, draft);
    return draft;
  }

  KrogerProduct? preferred(String user, String store, String name) {
    final raw = prefs.getString(
      'kroger.choice.$user.$store.${name.toLowerCase()}',
    );
    return raw == null
        ? null
        : KrogerProduct.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> remember(
    String user,
    String store,
    String name,
    KrogerProduct product,
  ) async {
    if (!await prefs.setString(
      'kroger.choice.$user.$store.${name.toLowerCase()}',
      jsonEncode(product.toJson()),
    )) {
      throw const KrogerException('local_save_failed');
    }
  }
}

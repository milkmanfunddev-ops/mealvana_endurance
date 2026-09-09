import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../meal_planning/application/shopping_list_controller.dart';
import '../data/kroger_repository.dart';
import '../domain/kroger_models.dart';
import 'kroger_matching.dart';

part 'kroger_controller.g.dart';

typedef KrogerBrowser = Future<String> Function(String url, String scheme);
@riverpod
Future<String?> krogerUserId(Ref ref) async {
  await ref.watch(userIdProvider.future);
  return ref.read(appExternalDepsProvider).supabaseClient.auth.currentUser?.id;
}

@riverpod
KrogerBrowser krogerBrowser(Ref ref) => (url, scheme) async {
  if (defaultTargetPlatform == TargetPlatform.android &&
      (await PackageInfo.fromPlatform()).packageName != scheme) {
    throw const KrogerException('redirect_mismatch');
  }
  return FlutterWebAuth2.authenticate(
    url: url,
    callbackUrlScheme: scheme,
    options: const FlutterWebAuth2Options(preferEphemeral: true),
  );
};

class KrogerState {
  const KrogerState({
    required this.draft,
    this.busy = false,
    this.available = false,
    this.connected = false,
    this.environment = 'certification',
    this.message,
    this.stores = const [],
    this.products = const [],
    this.searchLineId,
  });
  final KrogerDraft draft;
  final bool busy, available, connected;
  final String environment;
  final String? message, searchLineId;
  final List<KrogerStore> stores;
  final List<KrogerProduct> products;
  KrogerState copyWith({
    KrogerDraft? draft,
    bool? busy,
    bool? available,
    bool? connected,
    String? environment,
    String? message,
    List<KrogerStore>? stores,
    List<KrogerProduct>? products,
    String? searchLineId,
  }) => KrogerState(
    draft: draft ?? this.draft,
    busy: busy ?? this.busy,
    available: available ?? this.available,
    connected: connected ?? this.connected,
    environment: environment ?? this.environment,
    message: message,
    stores: stores ?? this.stores,
    products: products ?? this.products,
    searchLineId: searchLineId ?? this.searchLineId,
  );
}

@riverpod
class KrogerController extends _$KrogerController {
  bool needsQuantityReview(KrogerLine line) =>
      KrogerMatching.packages(line.requiredQty, line.product?.size ?? '') ==
      null;
  String? _user;
  Object _scope = Object();
  void _assertScope() {
    final expected = Zone.current[#krogerScope];
    if (!ref.mounted || expected != null && !identical(expected, _scope)) {
      throw const KrogerException('session_changed');
    }
  }

  void _publish(KrogerState value) {
    _assertScope();
    state = AsyncData(value);
  }

  KrogerRepository get _repo {
    _assertScope();
    return ref.read(krogerRepositoryProvider);
  }

  @override
  Future<KrogerState> build(String planId) async {
    final scope = _scope = Object();
    final user = await ref.watch(krogerUserIdProvider.future);
    if (!ref.mounted || !identical(scope, _scope)) {
      throw const KrogerException('session_changed');
    }
    _user = user;
    if (_user == null) throw const KrogerException('reconnect_required');
    return runZoned(_loadDraft, zoneValues: {#krogerScope: scope});
  }

  Future<KrogerState> _loadDraft() async {
    ref.listen(shoppingListControllerProvider, (_, next) {
      if (state.value != null &&
          !state.value!.busy &&
          next.value?.planId == planId) {
        unawaited(_run(() async => _persist(_reconcile(state.value!.draft))));
      }
    });
    var draft = _reconcile(_repo.load(_user!, planId));
    // Always return the locally editable draft, including when the service is offline.
    final remote = await AsyncValue.guard(() async {
      final status = await _repo.remote.call('status');
      if (status['available'] != true) {
        return KrogerState(
          draft: draft,
          connected: status['connected'] == true,
          environment: status['environment'] as String? ?? draft.environment,
          message: status['reason'] as String? ?? 'not_configured',
        );
      }
      draft = _reconcile(
        _environment(await _repo.ensureSynced(_user!, planId), status),
      );
      final receipt = await _repo.remote.call('export_status', {
        'planId': planId,
      });
      draft = draft.copyWith(
        receiptStatus: (receipt['receipt'] as Map?)?['status'] as String?,
        clearReceipt: receipt['receipt'] == null,
      );
      draft = await _repo.saveLocal(_user!, draft);
      return KrogerState(
        draft: draft,
        available: true,
        connected: status['connected'] == true,
        environment: status['environment'] as String? ?? 'certification',
      );
    });
    _assertScope();
    if (remote.hasError || remote.value?.available != true) {
      draft = await _repo.saveLocal(_user!, draft);
    }
    return remote.value?.copyWith(draft: draft) ??
        KrogerState(draft: draft, message: _error(remote.error));
  }

  String _error(Object? error) =>
      error is KrogerException ? error.code : 'unavailable';
  KrogerDraft _environment(KrogerDraft draft, Map<String, dynamic> status) {
    final environment = status['environment'] as String? ?? draft.environment;
    if (environment == draft.environment) return draft;
    return draft.copyWith(
      environment: environment,
      clearStore: true,
      clearReceipt: true,
      lines: draft.lines
          .map(
            (l) => l.copyWith(
              clearProduct: true,
              approved: false,
              quantityEdited: false,
            ),
          )
          .toList(),
    );
  }

  KrogerDraft _reconcile(KrogerDraft draft) {
    final source = ref.read(shoppingListControllerProvider).value;
    return source?.planId == planId
        ? KrogerMatching.reconcile(draft, source!.items)
        : draft;
  }

  Future<void> _persist(KrogerDraft draft) async {
    final saved = await _repo.saveLocal(_user!, draft);
    if (ref.mounted) {
      _publish(
        state.value!.copyWith(draft: saved, message: state.value?.message),
      );
    }
  }

  Future<void> _run(Future<void> Function() work) async {
    final current = state.value;
    if (current == null || current.busy) return;
    _publish(current.copyWith(busy: true));
    final scope = _scope;
    final result = await runZoned(
      () => AsyncValue.guard(() async {
        await work();
        // Source updates arriving during a network operation must not be dropped.
        _assertScope();
        await _persist(_reconcile(state.value!.draft));
      }),
      zoneValues: {#krogerScope: scope},
    );
    if (!ref.mounted || !identical(scope, _scope)) return;
    _publish(
      (state.value ?? current).copyWith(
        busy: false,
        message: result.hasError ? _error(result.error) : state.value?.message,
      ),
    );
  }

  Future<void> refresh() => _run(() async {
    final status = await _repo.remote.call('status');
    final synced = status['available'] == true
        ? await _repo.ensureSynced(_user!, planId)
        : state.value!.draft;
    var draft = _reconcile(_environment(synced, status));
    if (status['available'] == true) {
      final response = await _repo.remote.call('export_status', {
        'planId': planId,
      });
      draft = draft.copyWith(
        receiptStatus: (response['receipt'] as Map?)?['status'] as String?,
        clearReceipt: response['receipt'] == null,
      );
    }
    await _persist(draft);
    _publish(
      state.value!.copyWith(
        available: status['available'] == true,
        connected: status['connected'] == true,
        environment: status['environment'] as String?,
        message: status['available'] == true
            ? null
            : status['reason'] as String? ?? 'not_configured',
      ),
    );
  });
  Future<void> loadCloud() => _run(
    () async => _persist(_reconcile(await _repo.loadRemote(_user!, planId))),
  );
  Future<void> connect() => _run(() async {
    if (kIsWeb) throw const KrogerException('mobile_only');
    final start = await _repo.remote.call('connect');
    final redirect = Uri.parse(start['redirect'] as String);
    final result = Uri.parse(
      await ref.read(krogerBrowserProvider)(
        start['url'] as String,
        redirect.scheme,
      ),
    );
    if (result.scheme != redirect.scheme ||
        result.host != redirect.host ||
        result.path != redirect.path ||
        result.queryParameters['state'] != start['state']) {
      throw const KrogerException('invalid_oauth_state');
    }
    if (result.queryParameters['error'] != null ||
        result.queryParameters['code'] == null) {
      throw const KrogerException('authorization_cancelled');
    }
    await _repo.remote.call('exchange', {
      'code': result.queryParameters['code'],
      'state': start['state'],
    });
    _publish(state.value!.copyWith(connected: true, available: true));
  });
  Future<void> disconnect() => _run(() async {
    await _repo.remote.call('disconnect');
    _publish(state.value!.copyWith(connected: false));
  });
  Future<void> findStores(String zip) => _run(() async {
    _publish(state.value!.copyWith(stores: []));
    final result = await _repo.remote.call('stores', {'zip': zip});
    _publish(
      state.value!.copyWith(
        stores: [
          for (final s in result['stores'] as List)
            KrogerStore.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      ),
    );
  });
  Future<void> selectStore(KrogerStore store, String modality) => _run(
    () async {
      final draft = state.value!.draft;
      final changed = draft.store?.id != store.id || draft.modality != modality;
      await _persist(
        draft.copyWith(
          store: store,
          modality: modality,
          lines: changed
              ? draft.lines
                    .map(
                      (l) => l.copyWith(
                        clearProduct: true,
                        approved: false,
                        quantityEdited: false,
                      ),
                    )
                    .toList()
              : draft.lines,
        ),
      );
      _publish(state.value!.copyWith(stores: [], products: []));
    },
  );
  Future<List<KrogerProduct>> _search(String query) async {
    final draft = state.value!.draft;
    if (draft.store == null) throw const KrogerException('choose_store');
    final data = await _repo.remote.call('search', {
      'query': query,
      'store': draft.store!.id,
      'modality': draft.modality,
    });
    return [
      for (final p in data['products'] as List)
        KrogerProduct.fromJson(Map<String, dynamic>.from(p as Map)),
    ];
  }

  Future<void> search(String lineId, String query) => _run(() async {
    _publish(state.value!.copyWith(products: []));
    final products = await _search(query);
    _publish(
      state.value!.copyWith(
        products: products,
        searchLineId: lineId,
        message: products.isEmpty ? 'no_products' : null,
      ),
    );
  });
  Future<void> matchAll() => _run(() async {
    await _persist(_reconcile(state.value!.draft));
    for (final line
        in state.value!.draft.lines
            .where((l) => !l.excluded && !l.approved)
            .toList()) {
      final products = await _search(line.name);
      if (!ref.mounted) return;
      if (products.isEmpty) continue;
      final preferred = _repo.preferred(
        _user!,
        state.value!.draft.store!.id,
        line.name,
      );
      final product =
          products
              .where(
                (p) =>
                    p.upc == (line.product?.upc ?? preferred?.upc) &&
                    p.available,
              )
              .firstOrNull ??
          products.where((p) => p.available).firstOrNull;
      if (product != null) {
        // Suggestions always need review, including remembered products.
        await _updateLine(
          line.id,
          (l) => l.copyWith(
            product: product,
            approved: false,
            quantity: l.quantityEdited
                ? l.quantity
                : KrogerMatching.packages(l.requiredQty, product.size) ?? 1,
          ),
        );
      }
    }
    _publish(state.value!.copyWith(message: 'review_matches'));
  });
  Future<void> _updateLine(
    String id,
    KrogerLine Function(KrogerLine) edit,
  ) async => _persist(
    state.value!.draft.copyWith(
      lines: [
        for (final l in state.value!.draft.lines)
          if (l.id == id) edit(l) else l,
      ],
    ),
  );
  Future<void> choose(String id, KrogerProduct product) => _run(() async {
    await _updateLine(
      id,
      (l) => l.copyWith(
        product: product,
        approved: false,
        quantity: l.quantityEdited
            ? l.quantity
            : KrogerMatching.packages(l.requiredQty, product.size) ?? 1,
      ),
    );
    _publish(state.value!.copyWith(products: []));
  });
  Future<void> approve(String id) => _run(() async {
    final line = state.value!.draft.lines.firstWhere((l) => l.id == id);
    if (line.product?.available != true) {
      throw const KrogerException('product_unavailable');
    }
    await _updateLine(id, (l) => l.copyWith(approved: true));
    await _repo.remember(
      _user!,
      state.value!.draft.store!.id,
      line.name,
      line.product!,
    );
  });
  Future<void> quantity(String id, int count) => _run(() async {
    if (count < 1 || count > 99) return;
    await _updateLine(
      id,
      (l) => l.copyWith(quantity: count, quantityEdited: true, approved: false),
    );
  });
  Future<void> exclude(String id, bool value) =>
      _run(() => _updateLine(id, (l) => l.copyWith(excluded: value)));
  Future<void> addManual(String name) => _run(() async {
    final value = name.trim();
    if (value.isEmpty || value.length > 100) return;
    final draft = state.value!.draft;
    await _persist(
      draft.copyWith(
        lines: [
          ...draft.lines,
          KrogerLine(
            id: const Uuid().v4(),
            name: value,
            requiredQty: '',
            manual: true,
          ),
        ],
      ),
    );
  });
  Future<void> export() => _run(() async {
    final draft = _reconcile(state.value!.draft);
    await _persist(draft);
    if (!draft.ready) throw const KrogerException('review_required');
    final synced = await _repo.ensureSynced(_user!, planId);
    if (synced.dirty) throw const KrogerException('review_required');
    // Reconcile again after network work: a plan change invalidates the reviewed quantities.
    final latest = _reconcile(synced);
    if (jsonEncode(latest.lines.map((l) => l.toJson()).toList()) !=
        jsonEncode(draft.lines.map((l) => l.toJson()).toList())) {
      await _persist(latest);
      throw const KrogerException('review_required');
    }
    await _persist(latest.copyWith(receiptStatus: 'sending'));
    final result = await _repo.remote.call('export', {
      'id': const Uuid().v4(),
      'planId': planId,
      'store': draft.store!.id,
      'modality': draft.modality,
      'items': [
        for (final l in draft.included)
          {
            'upc': l.product!.upc,
            'quantity': l.quantity,
            'price': l.product!.price,
            'size': l.product!.size,
          },
      ],
    });
    if (result['changed'] case final List changed) {
      var next = state.value!.draft.copyWith(clearReceipt: true);
      for (final raw in changed) {
        final p = KrogerProduct.fromJson(Map<String, dynamic>.from(raw as Map));
        next = next.copyWith(
          lines: [
            for (final l in next.lines)
              if (l.product?.upc == p.upc)
                l.copyWith(
                  product: p,
                  approved: false,
                  quantity: l.quantityEdited
                      ? l.quantity
                      : KrogerMatching.packages(l.requiredQty, p.size) ?? 1,
                )
              else
                l,
          ],
        );
      }
      await _persist(next);
      _publish(state.value!.copyWith(message: 'products_changed'));
    } else {
      await _persist(
        state.value!.draft.copyWith(
          receiptStatus: (result['receipt'] as Map)['status'] as String,
        ),
      );
    }
  });
  Future<void> openCart() => _run(() async {
    if (!await launchUrl(
      Uri.parse('https://www.kroger.com/cart'),
      mode: LaunchMode.externalApplication,
    )) {
      throw const KrogerException('unavailable');
    }
  });
}

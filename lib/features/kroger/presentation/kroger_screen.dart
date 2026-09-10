import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../content/application/content_service.dart';
import '../../content/domain/content_keys.dart';
import '../../../theme/kyle_design/app_spacing.dart';
import '../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../application/kroger_controller.dart';
import '../domain/kroger_messages.dart';
import '../domain/kroger_models.dart';

String krogerText(WidgetRef ref, String key) =>
    ref.read(contentServiceProvider).getValue(key);
String _format(WidgetRef ref, String key, Map<String, String> values) =>
    ContentKeys.format(krogerText(ref, key), values);

class KrogerScreen extends ConsumerWidget {
  const KrogerScreen({super.key, required this.planId});
  final String planId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = krogerControllerProvider(planId);
    final controller = ref.read(provider.notifier);
    final result = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      final message = next.value?.message;
      // Suppressed only when the body is already showing these exact words:
      // gating on availability instead would silence every later failure —
      // a rate limit, an expired authorization — for an unavailable session.
      if (message != null &&
          previous?.value?.message != message &&
          message != next.value?.unavailableReason) {
        MealvanaSnackbar.showInfo(
          context,
          krogerText(
            ref,
            krogerMessageKey(message) ?? ContentKeys.krogerUnavailable,
          ),
        );
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(krogerText(ref, ContentKeys.krogerTitle)),
        actions: [
          IconButton(
            tooltip: krogerText(ref, ContentKeys.krogerRefresh),
            icon: const Icon(Icons.refresh),
            onPressed: result.value?.busy == true ? null : controller.refresh,
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(provider),
            child: Text(krogerText(ref, ContentKeys.krogerRefresh)),
          ),
        ),
        data: (s) => Column(
          children: [
            if (s.busy) const LinearProgressIndicator(),
            Expanded(
              child: AbsorbPointer(
                absorbing: s.busy,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(krogerText(ref, ContentKeys.krogerIntro)),
                    if (s.environment == 'certification' && s.available)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(
                          krogerText(ref, ContentKeys.krogerCertification),
                        ),
                      ),
                    if (!s.available)
                      // Pro required, rate limited, reconnect required and
                      // genuinely not configured are four different facts.
                      Text(
                        krogerText(
                          ref,
                          krogerMessageKey(
                                s.unavailableReason ?? 'not_configured',
                              ) ??
                              ContentKeys.krogerNotConfigured,
                        ),
                      ),
                    if (s.message == 'draft_conflict') ...[
                      Text(krogerText(ref, ContentKeys.krogerDraftConflict)),
                      TextButton(
                        onPressed: () async {
                          if (await _confirm(
                            context,
                            ref,
                            ContentKeys.krogerLoadCloudConfirm,
                          )) {
                            await controller.loadCloud();
                          }
                        },
                        child: Text(
                          krogerText(ref, ContentKeys.krogerLoadCloud),
                        ),
                      ),
                    ],
                    if (!s.connected && s.available)
                      FilledButton(
                        onPressed: controller.connect,
                        child: Text(krogerText(ref, ContentKeys.krogerConnect)),
                      ),
                    if (s.connected)
                      TextButton(
                        onPressed: controller.disconnect,
                        child: Text(
                          krogerText(ref, ContentKeys.krogerDisconnect),
                        ),
                      ),
                    // Where the groceries are going, and nothing about the
                    // facility they come from: a shopper does not think in
                    // Locations, and a Spoke is not somewhere to be sent.
                    if (s.available) ...[
                      if (s.confirmedArea case final area?) ...[
                        ListTile(
                          key: const ValueKey('kroger.area'),
                          title: Text(
                            _format(ref, ContentKeys.krogerDeliveryTo, {
                              'area': area,
                            }),
                          ),
                          subtitle: Text(
                            krogerText(ref, ContentKeys.krogerDeliveryNote),
                          ),
                          trailing: TextButton(
                            onPressed: () => _area(context, ref, controller),
                            child: Text(
                              krogerText(ref, ContentKeys.krogerChangeArea),
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(krogerText(ref, ContentKeys.krogerAreaUnknown)),
                        OutlinedButton(
                          key: const ValueKey('kroger.set_area'),
                          onPressed: () => _area(context, ref, controller),
                          child: Text(
                            krogerText(ref, ContentKeys.krogerSetArea),
                          ),
                        ),
                      ],
                    ],
                    if (s.draft.exported) ...[
                      Text(
                        krogerText(
                          ref,
                          s.draft.receiptStatus == 'sent'
                              ? ContentKeys.krogerSent
                              : s.draft.receiptStatus == 'sending'
                              ? ContentKeys.krogerSending
                              : ContentKeys.krogerUnknown,
                        ),
                      ),
                      if (s.environment == 'production')
                        FilledButton(
                          onPressed: controller.openCart,
                          child: Text(
                            krogerText(ref, ContentKeys.krogerOpenCart),
                          ),
                        ),
                      Text(krogerText(ref, ContentKeys.krogerAfterExport)),
                    ],
                    // A Location, not an area: the Location is persisted and
                    // the area is not, so a shopper coming back to a resolved
                    // draft can still match even before saying where they are
                    // again.
                    if (s.connected &&
                        s.draft.store != null &&
                        !s.draft.exported)
                      OutlinedButton(
                        onPressed: controller.matchAll,
                        child: Text(
                          krogerText(ref, ContentKeys.krogerMatchAll),
                        ),
                      ),
                    for (final line in s.draft.lines)
                      _LineCard(line: line, state: s, controller: controller),
                    if (!s.draft.exported)
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(krogerText(ref, ContentKeys.krogerAddItem)),
                        onPressed: () async {
                          final name = await _input(
                            context,
                            ref,
                            ContentKeys.krogerItemName,
                          );
                          if (name != null) await controller.addManual(name);
                        },
                      ),
                    Text(
                      _format(ref, ContentKeys.krogerEstimate, {
                        'price': s.draft.estimate.toStringAsFixed(2),
                      }),
                    ),
                    Text(
                      s.draft.unknownPrices > 0
                          ? _format(ref, ContentKeys.krogerUnknownPrices, {
                              'count': '${s.draft.unknownPrices}',
                            })
                          : krogerText(ref, ContentKeys.krogerEstimateNote),
                    ),
                    if (s.draft.dirty)
                      Text(krogerText(ref, ContentKeys.krogerSavedLocal)),
                    const SizedBox(height: AppSpacing.md),
                    // Rendered only when it can send. A permanently greyed
                    // button is a control the shopper cannot learn anything
                    // from by tapping.
                    if (!s.draft.exported && s.connected && s.draft.ready)
                      FilledButton(
                        key: const ValueKey('kroger.export'),
                        onPressed: () async {
                          if (await _confirm(
                            context,
                            ref,
                            ContentKeys.krogerSendConfirm,
                          )) {
                            await controller.export();
                          }
                        },
                        child: Text(krogerText(ref, ContentKeys.krogerSend)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineCard extends ConsumerWidget {
  const _LineCard({
    required this.line,
    required this.state,
    required this.controller,
  });
  final KrogerLine line;
  final KrogerState state;
  final KrogerController controller;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = line.product;
    final editable = !state.draft.exported;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (editable)
                  TextButton(
                    onPressed: () =>
                        controller.exclude(line.id, !line.excluded),
                    child: Text(
                      krogerText(
                        ref,
                        line.excluded
                            ? ContentKeys.krogerInclude
                            : ContentKeys.krogerSkip,
                      ),
                    ),
                  ),
              ],
            ),
            if (line.requiredQty.isNotEmpty)
              Text(
                _format(ref, ContentKeys.krogerNeeded, {
                  'quantity': line.requiredQty,
                }),
              ),
            if (!line.excluded) ...[
              if (product == null)
                Text(krogerText(ref, ContentKeys.krogerUnmatched))
              else ...[
                Text(product.name),
                Text(
                  _format(ref, ContentKeys.krogerPackage, {
                    'size': product.size.isEmpty
                        ? krogerText(ref, ContentKeys.krogerUnknownSize)
                        : product.size,
                  }),
                ),
                if (product.price != null)
                  Text(
                    _format(ref, ContentKeys.krogerPrice, {
                      'price': product.price!.toStringAsFixed(2),
                    }),
                  ),
                if (!product.available)
                  Text(krogerText(ref, ContentKeys.krogerUnavailableProduct)),
                if (controller.needsQuantityReview(line))
                  Text(krogerText(ref, ContentKeys.krogerQuantityReview)),
                Row(
                  children: [
                    Text(krogerText(ref, ContentKeys.krogerQuantity)),
                    IconButton(
                      tooltip: krogerText(
                        ref,
                        ContentKeys.krogerQuantityDecrease,
                      ),
                      onPressed: editable && line.quantity > 1
                          ? () =>
                                controller.quantity(line.id, line.quantity - 1)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('${line.quantity}'),
                    IconButton(
                      tooltip: krogerText(
                        ref,
                        ContentKeys.krogerQuantityIncrease,
                      ),
                      onPressed: editable && line.quantity < 99
                          ? () =>
                                controller.quantity(line.id, line.quantity + 1)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
              if (line.approved)
                Text(krogerText(ref, ContentKeys.krogerApproved)),
              if (editable)
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    // Searching needs a Location and a connection; approving
                    // needs a product that can actually be had. Without those
                    // there is nothing to tap, so there is no button.
                    if (state.connected && state.draft.store != null)
                      OutlinedButton(
                        onPressed: () =>
                            _products(context, ref, controller, line),
                        child: Text(
                          krogerText(
                            ref,
                            product == null
                                ? ContentKeys.krogerChoose
                                : ContentKeys.krogerChange,
                          ),
                        ),
                      ),
                    if (product != null && product.available && !line.approved)
                      FilledButton.tonal(
                        onPressed: () => controller.approve(line.id),
                        child: Text(krogerText(ref, ContentKeys.krogerApprove)),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, WidgetRef ref, String key) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(krogerText(ref, key)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(krogerText(ref, ContentKeys.krogerCancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(krogerText(ref, ContentKeys.krogerContinue)),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> _input(
  BuildContext context,
  WidgetRef ref,
  String key, {
  String initial = '',
  bool numeric = false,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => _InputDialog(
      title: krogerText(ref, key),
      cancel: krogerText(ref, ContentKeys.krogerCancel),
      submit: krogerText(ref, ContentKeys.krogerContinue),
      initial: initial,
      numeric: numeric,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.cancel,
    required this.submit,
    required this.initial,
    required this.numeric,
  });
  final String title, cancel, submit, initial;
  final bool numeric;
  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final text = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: text,
      autofocus: true,
      maxLength: widget.numeric ? 5 : 100,
      keyboardType: widget.numeric ? TextInputType.number : TextInputType.text,
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, text.text),
        child: Text(widget.submit),
      ),
    ],
  );
}

/// The one place the shopper says anything about where they are: a postcode,
/// typed once. There is no Location list here and there is not one anywhere
/// else either — the Location follows from the area and the Modality.
Future<void> _area(
  BuildContext context,
  WidgetRef ref,
  KrogerController controller,
) async {
  final area = await _input(context, ref, ContentKeys.krogerZip, numeric: true);
  if (area == null) return;
  await controller.setArea(area);
}

Future<void> _products(
  BuildContext context,
  WidgetRef ref,
  KrogerController controller,
  KrogerLine line,
) async {
  final query = await _input(
    context,
    ref,
    ContentKeys.krogerSearchHint,
    initial: line.name,
  );
  if (query == null || !context.mounted) return;
  await controller.search(line.id, query);
  if (!context.mounted) return;
  final products =
      ref.read(krogerControllerProvider(controller.planId)).value?.products ??
      [];
  if (products.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        children: [
          for (final p in products)
            ListTile(
              title: Text(p.name),
              subtitle: Text(
                [
                  p.size,
                  if (p.price != null)
                    _format(ref, ContentKeys.krogerPrice, {
                      'price': p.price!.toStringAsFixed(2),
                    }),
                ].join(' · '),
              ),
              enabled: p.available,
              onTap: () {
                Navigator.pop(context);
                controller.choose(line.id, p);
              },
            ),
        ],
      ),
    ),
  );
}

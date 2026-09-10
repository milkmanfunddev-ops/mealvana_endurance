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
                      if (s.isProduction)
                        FilledButton(
                          key: const ValueKey('kroger.hand_off'),
                          onPressed: controller.handOff,
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
                    // The review, in three parts. A line is going to Kroger,
                    // is the shopper's own to add there, or is not being
                    // ordered — and it says which without being read closely.
                    if (s.draft.matched.isNotEmpty)
                      _Section(
                        key: const ValueKey('kroger.matched'),
                        title: krogerText(
                          ref,
                          ContentKeys.krogerMatchedHeading,
                        ),
                        children: [
                          for (final line in s.draft.matched)
                            _MatchedLine(
                              line: line,
                              state: s,
                              controller: controller,
                            ),
                        ],
                      ),
                    if (s.draft.unmatched.isNotEmpty)
                      _Section(
                        key: const ValueKey('kroger.unmatched'),
                        title: krogerText(
                          ref,
                          ContentKeys.krogerUnmatchedHeading,
                        ),
                        note: krogerText(ref, ContentKeys.krogerUnmatchedNote),
                        children: [
                          for (final line in s.draft.unmatched)
                            _UnmatchedLine(
                              line: line,
                              state: s,
                              controller: controller,
                            ),
                        ],
                      ),
                    if (s.draft.skipped.isNotEmpty)
                      _Section(
                        key: const ValueKey('kroger.skipped'),
                        title: krogerText(
                          ref,
                          ContentKeys.krogerSkippedHeading,
                        ),
                        children: [
                          for (final line in s.draft.skipped)
                            _SkippedLine(
                              line: line,
                              state: s,
                              controller: controller,
                            ),
                        ],
                      ),
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
                    Text(krogerText(ref, ContentKeys.krogerPriceNote)),
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
                    // Sending again is a separate thing, asked for outright.
                    // Kroger's cart takes additions and nothing else, so this
                    // adds a second copy of everything and Mealvana cannot
                    // take it back — which is what the confirmation says.
                    //
                    // Offered over an acknowledged send and no other: a
                    // `sending` or `unknown` receipt cannot say what is in the
                    // cart, and Kroger's own cart is where those are settled.
                    if (s.draft.resendable && s.connected)
                      OutlinedButton(
                        key: const ValueKey('kroger.export_again'),
                        onPressed: () async {
                          if (await _confirm(
                            context,
                            ref,
                            ContentKeys.krogerSendAgainConfirm,
                          )) {
                            await controller.export(resend: true);
                          }
                        },
                        child: Text(
                          krogerText(ref, ContentKeys.krogerSendAgain),
                        ),
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

/// One part of the review, with its heading. Rendered only when it has lines
/// in it: an empty "You add these on Kroger" reads as a failure.
class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.children,
    this.note,
  });
  final String title;
  final String? note;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: AppSpacing.md),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      if (note case final note?) Text(note),
      ...children,
    ],
  );
}

/// The ingredient beside the product Kroger will actually send, named and
/// sized exactly as Kroger returned it. No price: a delivery Location
/// publishes none, and Kroger's terms forbid borrowing another's.
class _MatchedLine extends ConsumerWidget {
  const _MatchedLine({
    required this.line,
    required this.state,
    required this.controller,
  });
  final KrogerLine line;
  final KrogerState state;
  final KrogerController controller;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = line.product!;
    final editable = !state.draft.exported;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShopperLine(line: line, state: state, controller: controller),
            Text(product.name),
            Text(
              _format(ref, ContentKeys.krogerPackage, {
                'size': product.size.isEmpty
                    ? krogerText(ref, ContentKeys.krogerUnknownSize)
                    : product.size,
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
                  tooltip: krogerText(ref, ContentKeys.krogerQuantityDecrease),
                  onPressed: editable && line.quantity > 1
                      ? () => controller.quantity(line.id, line.quantity - 1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('${line.quantity}'),
                IconButton(
                  tooltip: krogerText(ref, ContentKeys.krogerQuantityIncrease),
                  onPressed: editable && line.quantity < 99
                      ? () => controller.quantity(line.id, line.quantity + 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (line.approved)
              Text(krogerText(ref, ContentKeys.krogerApproved)),
            if (editable)
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  // Correcting one match is still here; it is simply no
                  // longer the way the shopper is expected to work.
                  if (state.canChooseProduct)
                    OutlinedButton(
                      onPressed: () =>
                          _products(context, ref, controller, line),
                      child: Text(krogerText(ref, ContentKeys.krogerChange)),
                    ),
                  if (product.available && !line.approved)
                    FilledButton.tonal(
                      onPressed: () => controller.approve(line.id),
                      child: Text(krogerText(ref, ContentKeys.krogerApprove)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// An ingredient Kroger's delivery catalogue had nothing for. Listed plainly,
/// because the shopper is going to add it themselves on Kroger's site — and
/// listed still after the Hand-off, for exactly the same reason.
class _UnmatchedLine extends ConsumerWidget {
  const _UnmatchedLine({
    required this.line,
    required this.state,
    required this.controller,
  });
  final KrogerLine line;
  final KrogerState state;
  final KrogerController controller;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShopperLine(line: line, state: state, controller: controller),
        if (state.canChooseProduct)
          OutlinedButton(
            onPressed: () => _products(context, ref, controller, line),
            child: Text(krogerText(ref, ContentKeys.krogerChoose)),
          ),
      ],
    ),
  );
}

/// A line the shopper has taken out, or one their list already has ticked
/// off. Kept on the screen so that taking something out is reversible.
class _SkippedLine extends ConsumerWidget {
  const _SkippedLine({
    required this.line,
    required this.state,
    required this.controller,
  });
  final KrogerLine line;
  final KrogerState state;
  final KrogerController controller;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    children: [
      Expanded(child: Text(line.name)),
      if (!state.draft.exported)
        TextButton(
          onPressed: () => controller.exclude(line.id, false),
          child: Text(krogerText(ref, ContentKeys.krogerInclude)),
        ),
    ],
  );
}

/// The ingredient as the shopper's own list has it: their words, their
/// amount, and the control that takes it out of the order. It opens both a
/// matched line and an unmatched one.
class _ShopperLine extends ConsumerWidget {
  const _ShopperLine({
    required this.line,
    required this.state,
    required this.controller,
  });
  final KrogerLine line;
  final KrogerState state;
  final KrogerController controller;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
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
          if (!state.draft.exported)
            TextButton(
              onPressed: () => controller.exclude(line.id, true),
              child: Text(krogerText(ref, ContentKeys.krogerSkip)),
            ),
        ],
      ),
      if (line.requiredQty.isNotEmpty)
        Text(
          _format(ref, ContentKeys.krogerNeeded, {
            'quantity': line.requiredQty,
          }),
        ),
    ],
  );
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
                p.size.isEmpty
                    ? krogerText(ref, ContentKeys.krogerUnknownSize)
                    : p.size,
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

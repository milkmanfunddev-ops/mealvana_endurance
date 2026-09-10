import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../content/application/content_service.dart';
import '../../content/domain/content_keys.dart';
import '../../meal_planning/presentation/widgets/vana_round_button.dart';
import '../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import '../../../shared/widgets/kyle_design/buttons/tertiary_button.dart';
import '../../../shared/widgets/kyle_design/cards/base_card.dart';
import '../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../shared/widgets/kyle_design/inputs/kyle_input_field.dart';
import '../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../../shared/widgets/kyle_design/materials/glass.dart';
import '../../../theme/kyle_design/app_colors.dart';
import '../../../theme/kyle_design/app_materials.dart';
import '../../../theme/kyle_design/app_spacing.dart';
import '../../../theme/kyle_design/app_text_styles.dart';
import '../application/kroger_controller.dart';
import '../domain/kroger_messages.dart';
import '../domain/kroger_models.dart';

String krogerText(WidgetRef ref, String key) =>
    ref.read(contentServiceProvider).getValue(key);
String _format(WidgetRef ref, String key, Map<String, String> values) =>
    ContentKeys.format(krogerText(ref, key), values);

/// How tall Kroger's product photograph is drawn.
///
/// Local on purpose. The design system has no ratified product-image
/// component and no size for one (gap DS-4), and
/// `docs/ssot/spec/design/source-authority.md` §3 keeps unratified values out
/// of `lib/theme/kyle_design/` — so this waits here for the ruling rather
/// than entering the registry ahead of it.
const _productImageHeight = 96.0;

/// The screen's own ink: cream on blackberry in the dark theme, blackberry on
/// cream in the light one. Read once per build rather than threaded through
/// every widget — the same two lines the other meal-planning screens open on.
bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;
Color _ink(BuildContext context) =>
    _isDark(context) ? AppColors.cream : AppColors.blackberry;
Color _mutedInk(BuildContext context) => _ink(context).withValues(alpha: 0.65);

/// `/food/kroger/:planId` — the reviewed hand-off to a Kroger delivery cart,
/// drawn as one of the app's own meal-planning screens: the in-body header
/// with a round back button that Recents and Swap use, design-system controls
/// throughout, and sheets on the glass surface. Nothing here is a component of
/// its own; where the design system lacks one, the gap is recorded in
/// `.scratch/kroger-delivery/design-system-gaps.md` rather than invented here.
///
/// Kroger's own marks are deliberately absent (see the gaps note): the primary
/// logo is licensed for add-to-cart only while the integration is not
/// monetized, and this sits behind Pro.
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
    final busy = result.value?.busy == true;
    return Scaffold(
      backgroundColor: _isDark(context)
          ? AppColors.blackberry
          : AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              // A refresh that cannot run is not drawn — the progress bar
              // below already says why it is gone.
              onRefresh: busy ? null : controller.refresh,
            ),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: result.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: KyleSecondaryButton(
                    isFullWidth: false,
                    text: krogerText(ref, ContentKeys.krogerRefresh),
                    onPressed: () => ref.invalidate(provider),
                  ),
                ),
                data: (loaded) => AbsorbPointer(
                  absorbing: loaded.busy,
                  child: _Body(state: loaded, controller: controller),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The header the meal-planning detail screens draw in the body rather than in
/// an [AppBar]: a round back button, the screen's name, and the one action.
class _Header extends ConsumerWidget {
  const _Header({required this.onRefresh});
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    child: Row(
      children: [
        VanaRoundButton.back(context: context, onTap: () => context.pop()),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            krogerText(ref, ContentKeys.krogerTitle),
            style: AppTextStyles.sectionTitle.copyWith(
              color: _ink(context),
              fontSize: 20,
            ),
          ),
        ),
        if (onRefresh != null)
          VanaRoundButton(
            key: const ValueKey('kroger.refresh'),
            icon: FontAwesomeIcons.arrowsRotate,
            tooltip: krogerText(ref, ContentKeys.krogerRefresh),
            onTap: onRefresh!,
          ),
      ],
    ),
  );
}

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.controller});
  final KrogerState state;
  final KrogerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = state;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        _BodyText(krogerText(ref, ContentKeys.krogerIntro)),
        if (view.environment == 'certification' && view.available)
          _BodyText(krogerText(ref, ContentKeys.krogerCertification)),
        if (!view.available)
          // Pro required, rate limited, reconnect required and genuinely not
          // configured are four different facts.
          _BodyText(
            krogerText(
              ref,
              krogerMessageKey(view.unavailableReason ?? 'not_configured') ??
                  ContentKeys.krogerNotConfigured,
            ),
          ),
        if (view.message == 'draft_conflict') ...[
          _BodyText(krogerText(ref, ContentKeys.krogerDraftConflict)),
          _LeftAction(
            child: KyleTertiaryButton(
              text: krogerText(ref, ContentKeys.krogerLoadCloud),
              onPressed: () async {
                if (await _confirm(
                  context,
                  ref,
                  ContentKeys.krogerLoadCloudConfirm,
                )) {
                  await controller.loadCloud();
                }
              },
            ),
          ),
        ],
        if (!view.connected && view.available)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: KylePrimaryButton(
              text: krogerText(ref, ContentKeys.krogerConnect),
              onPressed: controller.connect,
            ),
          ),
        if (view.connected)
          _LeftAction(
            child: KyleTertiaryButton(
              text: krogerText(ref, ContentKeys.krogerDisconnect),
              onPressed: controller.disconnect,
            ),
          ),
        // Where the groceries are going, and nothing about the facility they
        // come from: a shopper does not think in Locations, and a Spoke is not
        // somewhere to be sent.
        if (view.available)
          if (view.confirmedArea case final area?)
            BaseCard(
              key: const ValueKey('kroger.area'),
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _format(ref, ContentKeys.krogerDeliveryTo, {
                            'area': area,
                          }),
                          style: AppTextStyles.subtitle.copyWith(
                            color: _ink(context),
                          ),
                        ),
                      ),
                      KyleTertiaryButtonSmall(
                        text: krogerText(ref, ContentKeys.krogerChangeArea),
                        onPressed: () =>
                            _promptForArea(context, ref, controller),
                      ),
                    ],
                  ),
                  Text(
                    krogerText(ref, ContentKeys.krogerDeliveryNote),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: _mutedInk(context),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _BodyText(krogerText(ref, ContentKeys.krogerAreaUnknown)),
            _LeftAction(
              child: KyleSecondaryButtonSmall(
                key: const ValueKey('kroger.set_area'),
                text: krogerText(ref, ContentKeys.krogerSetArea),
                onPressed: () => _promptForArea(context, ref, controller),
              ),
            ),
          ],
        if (view.draft.exported) ...[
          _BodyText(
            krogerText(
              ref,
              view.draft.receiptStatus == 'sent'
                  ? ContentKeys.krogerSent
                  : view.draft.receiptStatus == 'sending'
                  ? ContentKeys.krogerSending
                  : ContentKeys.krogerUnknown,
            ),
          ),
          if (view.isProduction)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: KylePrimaryButton(
                key: const ValueKey('kroger.hand_off'),
                text: krogerText(ref, ContentKeys.krogerOpenCart),
                onPressed: controller.handOff,
              ),
            ),
          _BodyText(krogerText(ref, ContentKeys.krogerAfterExport)),
        ],
        // A Location, not an area: the Location is persisted and the area is
        // not, so a shopper coming back to a resolved draft can still match
        // even before saying where they are again.
        if (view.connected && view.draft.store != null && !view.draft.exported)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: KyleSecondaryButton(
              text: krogerText(ref, ContentKeys.krogerMatchAll),
              onPressed: controller.matchAll,
            ),
          ),
        // The review, in three parts. A line is going to Kroger, is the
        // shopper's own to add there, or is not being ordered — and it says
        // which without being read closely.
        if (view.draft.matched.isNotEmpty)
          _Section(
            key: const ValueKey('kroger.matched'),
            title: krogerText(ref, ContentKeys.krogerMatchedHeading),
            children: [
              for (final line in view.draft.matched)
                _MatchedLine(line: line, state: view, controller: controller),
            ],
          ),
        if (view.draft.unmatched.isNotEmpty)
          _Section(
            key: const ValueKey('kroger.unmatched'),
            title: krogerText(ref, ContentKeys.krogerUnmatchedHeading),
            note: krogerText(ref, ContentKeys.krogerUnmatchedNote),
            children: [
              for (final line in view.draft.unmatched)
                _UnmatchedLine(line: line, state: view, controller: controller),
            ],
          ),
        if (view.draft.skipped.isNotEmpty)
          _Section(
            key: const ValueKey('kroger.skipped'),
            title: krogerText(ref, ContentKeys.krogerSkippedHeading),
            children: [
              for (final line in view.draft.skipped)
                _SkippedLine(line: line, state: view, controller: controller),
            ],
          ),
        if (!view.draft.exported)
          _LeftAction(
            child: KyleTertiaryButton(
              icon: Icons.add,
              text: krogerText(ref, ContentKeys.krogerAddItem),
              onPressed: () async {
                final name = await _promptForText(
                  context,
                  ref,
                  ContentKeys.krogerItemName,
                );
                if (name != null) await controller.addManual(name);
              },
            ),
          ),
        _BodyText(krogerText(ref, ContentKeys.krogerPriceNote)),
        if (view.draft.dirty)
          _BodyText(krogerText(ref, ContentKeys.krogerSavedLocal)),
        const SizedBox(height: AppSpacing.md),
        // Rendered only when it can send. A permanently greyed button is a
        // control the shopper cannot learn anything from by tapping.
        if (!view.draft.exported && view.connected && view.draft.ready)
          KylePrimaryButton(
            key: const ValueKey('kroger.export'),
            text: krogerText(ref, ContentKeys.krogerSend),
            onPressed: () async {
              if (await _confirm(context, ref, ContentKeys.krogerSendConfirm)) {
                await controller.export();
              }
            },
          ),
        // Sending again is a separate thing, asked for outright. Kroger's cart
        // takes additions and nothing else, so this adds a second copy of
        // everything and Mealvana cannot take it back — which is what the
        // confirmation says.
        //
        // Offered over an acknowledged send and no other: a `sending` or
        // `unknown` receipt cannot say what is in the cart, and Kroger's own
        // cart is where those are settled.
        if (view.draft.resendable && view.connected)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: KyleSecondaryButton(
              key: const ValueKey('kroger.export_again'),
              text: krogerText(ref, ContentKeys.krogerSendAgain),
              onPressed: () async {
                if (await _confirm(
                  context,
                  ref,
                  ContentKeys.krogerSendAgainConfirm,
                )) {
                  await controller.export(resend: true);
                }
              },
            ),
          ),
      ],
    );
  }
}

/// A button that is not the screen's main action, so it sits at the start of
/// the line rather than stretching across it. The design-system buttons size
/// themselves; only where they sit is this screen's business.
class _LeftAction extends StatelessWidget {
  const _LeftAction({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.centerLeft, child: child);
}

/// A paragraph of the screen's own prose, in the body register.
class _BodyText extends StatelessWidget {
  const _BodyText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(color: _mutedInk(context)),
    ),
  );
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
      Text(
        title,
        style: AppTextStyles.sectionTitle.copyWith(color: _ink(context)),
      ),
      if (note case final note?) _BodyText(note),
      ...children,
    ],
  );
}

/// The ingredient beside the product Kroger will actually send, named and
/// sized exactly as Kroger returned it, with Kroger's own photograph shown
/// whole. No price: a delivery Location publishes none, and Kroger's terms
/// forbid borrowing another's.
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
    return BaseCard(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShopperLine(line: line, state: state, controller: controller),
          const SizedBox(height: AppSpacing.xs),
          _ProductImage(product: product),
          Text(
            product.name,
            style: AppTextStyles.bodyMedium.copyWith(color: _ink(context)),
          ),
          Text(
            _format(ref, ContentKeys.krogerPackage, {
              'size': product.size.isEmpty
                  ? krogerText(ref, ContentKeys.krogerUnknownSize)
                  : product.size,
            }),
            style: AppTextStyles.bodySmall.copyWith(color: _mutedInk(context)),
          ),
          if (!product.available)
            _BodyText(krogerText(ref, ContentKeys.krogerUnavailableProduct)),
          if (controller.needsQuantityReview(line))
            _BodyText(krogerText(ref, ContentKeys.krogerQuantityReview)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: KylePlusMinusControl(
              value: line.quantity,
              min: 1,
              max: 99,
              enabled: editable,
              label: krogerText(ref, ContentKeys.krogerQuantity),
              onChanged: (value) => controller.quantity(line.id, value),
            ),
          ),
          if (line.approved)
            Text(
              krogerText(ref, ContentKeys.krogerApproved),
              style: AppTextStyles.smallLabel.copyWith(
                color: _mutedInk(context),
              ),
            ),
          if (editable)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                // Correcting one match is still here; it is simply no longer
                // the way the shopper is expected to work.
                if (state.canChooseProduct)
                  KyleSecondaryButtonSmall(
                    text: krogerText(ref, ContentKeys.krogerChange),
                    onPressed: () =>
                        _chooseProduct(context, ref, controller, line),
                  ),
                if (product.available && !line.approved)
                  KylePrimaryButtonSmall(
                    text: krogerText(ref, ContentKeys.krogerApprove),
                    onPressed: () => controller.approve(line.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Kroger's product photograph, whole. Uncropped and unadorned is a licence
/// term, not a preference: nothing is drawn over it and nothing is cut off it,
/// so the fit is `contain` and there is no [Stack] here.
class _ProductImage extends ConsumerWidget {
  const _ProductImage({required this.product});
  final KrogerProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = product.image;
    if (image == null || image.isEmpty) return const SizedBox.shrink();
    return Semantics(
      image: true,
      label: _format(ref, ContentKeys.krogerProductImage, {
        'product': product.name,
      }),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: SizedBox(
          height: _productImageHeight,
          width: double.infinity,
          child: Image.network(
            image,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
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
          _LeftAction(
            child: KyleSecondaryButtonSmall(
              text: krogerText(ref, ContentKeys.krogerChoose),
              onPressed: () => _chooseProduct(context, ref, controller, line),
            ),
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
      Expanded(
        child: Text(
          line.name,
          style: AppTextStyles.bodyMedium.copyWith(color: _mutedInk(context)),
        ),
      ),
      if (!state.draft.exported)
        KyleTertiaryButtonSmall(
          text: krogerText(ref, ContentKeys.krogerInclude),
          onPressed: () => controller.exclude(line.id, false),
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
              style: AppTextStyles.foodTitle.copyWith(color: _ink(context)),
            ),
          ),
          if (!state.draft.exported)
            KyleTertiaryButtonSmall(
              text: krogerText(ref, ContentKeys.krogerSkip),
              onPressed: () => controller.exclude(line.id, true),
            ),
        ],
      ),
      if (line.requiredQty.isNotEmpty)
        Text(
          _format(ref, ContentKeys.krogerNeeded, {
            'quantity': line.requiredQty,
          }),
          style: AppTextStyles.bodySmall.copyWith(color: _mutedInk(context)),
        ),
    ],
  );
}

/// Every sheet this screen raises: the glass surface over the standard scrim,
/// as the calendar and What's-new sheets draw it.
Future<T?> _sheet<T>(
  BuildContext context,
  Widget Function(BuildContext context) builder,
) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  barrierColor: AppMaterials.sheetScrim,
  backgroundColor: Colors.transparent,
  builder: (context) => GlassSheetSurface(
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: builder(context),
      ),
    ),
  ),
);

Future<bool> _confirm(BuildContext context, WidgetRef ref, String key) async =>
    await _sheet<bool>(
      context,
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            krogerText(ref, key),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.cream,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          KylePrimaryButton(
            text: krogerText(ref, ContentKeys.krogerContinue),
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: AppSpacing.xs),
          KyleTertiaryButton(
            text: krogerText(ref, ContentKeys.krogerCancel),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> _promptForText(
  BuildContext context,
  WidgetRef ref,
  String key, {
  String initial = '',
  bool numeric = false,
}) => _sheet<String>(
  context,
  (context) => _InputSheet(
    title: krogerText(ref, key),
    cancel: krogerText(ref, ContentKeys.krogerCancel),
    submit: krogerText(ref, ContentKeys.krogerContinue),
    initial: initial,
    numeric: numeric,
  ),
);

class _InputSheet extends StatefulWidget {
  const _InputSheet({
    required this.title,
    required this.cancel,
    required this.submit,
    required this.initial,
    required this.numeric,
  });
  final String title, cancel, submit, initial;
  final bool numeric;
  @override
  State<_InputSheet> createState() => _InputSheetState();
}

class _InputSheetState extends State<_InputSheet> {
  late final text = TextEditingController(text: widget.initial);

  // KyleInputField takes a focus node but has no `autofocus` of its own, so
  // the sheet raises the keyboard through the node it owns (gap DS-2).
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focus.requestFocus();
    });
  }

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: AppTextStyles.sectionTitle.copyWith(color: AppColors.cream),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          label: widget.title,
          textField: true,
          child: KyleInputField(
            controller: text,
            focusNode: focus,
            // No hint: the title above the field already says what this is,
            // and a hint repeating it reads twice to a screen reader.
            keyboardType: widget.numeric
                ? TextInputType.number
                : TextInputType.text,
            // The dialog's old maxLength, kept: a five-digit postcode, and a
            // manual item name Kroger's cart will accept.
            inputFormatters: [
              LengthLimitingTextInputFormatter(widget.numeric ? 5 : 100),
            ],
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        KylePrimaryButton(
          text: widget.submit,
          onPressed: () => Navigator.pop(context, text.text),
        ),
        const SizedBox(height: AppSpacing.xs),
        KyleTertiaryButton(
          text: widget.cancel,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

/// The one place the shopper says anything about where they are: a postcode,
/// typed once. There is no Location list here and there is not one anywhere
/// else either — the Location follows from the area and the Modality.
Future<void> _promptForArea(
  BuildContext context,
  WidgetRef ref,
  KrogerController controller,
) async {
  final area = await _promptForText(
    context,
    ref,
    ContentKeys.krogerZip,
    numeric: true,
  );
  if (area == null) return;
  await controller.setArea(area);
}

Future<void> _chooseProduct(
  BuildContext context,
  WidgetRef ref,
  KrogerController controller,
  KrogerLine line,
) async {
  final query = await _promptForText(
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
  await _sheet<void>(
    context,
    (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final p in products)
            _ProductChoice(
              product: p,
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

/// One search result on the glass sheet: Kroger's photograph whole, and
/// Kroger's own words for the product beside it.
class _ProductChoice extends ConsumerWidget {
  const _ProductChoice({required this.product, required this.onTap});
  final KrogerProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    button: product.available,
    label: product.name,
    child: InkWell(
      onTap: product.available ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductImage(product: product),
            Text(
              product.name,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.cream.withValues(
                  alpha: product.available ? 1 : 0.5,
                ),
              ),
            ),
            Text(
              product.size.isEmpty
                  ? krogerText(ref, ContentKeys.krogerUnknownSize)
                  : product.size,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.cream.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

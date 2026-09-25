import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/services/privacy/privacy_links.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../settings/domain/account_deletion_entry.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../application/pro_paywall_controller.dart';
import '../../application/subscription_screen_controller.dart';
import '../../application/subscription_status_provider.dart';
import '../pro_gate_redirect.dart';
import '../widgets/pro_feature_list.dart';
import '../widgets/redeem_code_sheet.dart';
import 'subscription_screen.dart' show openManageSubscription;

/// Opens [uri] outside the app. A provider so widget tests can intercept
/// "Manage subscription" and the terms and privacy links instead of reaching
/// the url_launcher channel.
final paywallUrlLauncherProvider = Provider<Future<bool> Function(Uri uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// The clip the paywall opens on: about four seconds of the dev app recorded
/// from the simulator (timeline, Vana answering, a week's meal plan), silent,
/// 540×1174. Its first frame is the poster and the Reduce Motion still.
const kPaywallClipAsset = 'assets/video/paywall_clip.mp4';
const kPaywallClipPosterAsset = 'assets/video/paywall_clip_first.jpg';
const kPaywallClipAspectRatio = 540 / 1174;

/// Makes the clip's player. A provider so widget tests drive a fake instead
/// of the `video_player` platform channel.
final paywallClipPlayerProvider = Provider<PhoneClipPlayer Function()>(
  (_) =>
      () => VideoPhoneClipPlayer(asset: kPaywallClipAsset),
);

/// The clip's first frame. A provider so widget tests need no asset decode.
final paywallClipPosterProvider = Provider<ImageProvider>(
  (_) => const AssetImage(kPaywallClipPosterAsset),
);

/// The paywall route's page: always a plain full-screen page (mp-280,
/// mp-611). Everyone without Pro meets the same paywall with no close
/// button; the onboarding query only says which shape it opened.
Page<void> paywallRoutePage(GoRouterState state) => MaterialPage<void>(
  key: state.pageKey,
  child: PaywallScreen(
    onboarding: state.uri.queryParameters[kOnboardingPaywallQuery] == '1',
  ),
);

/// The paywall — where an inactive account lands after sign-in and stays
/// (mp-280), in Bevel's layout with our branding (mp-493).
///
/// It opens on a clip of our own app, then slides to the features. The two
/// plan cards stay pinned above one Continue button through the whole
/// scroll; annual is selected by default and carries its saving and its
/// per-month price, worked out from the store's prices (mp-493 §3). Prices
/// come from RevenueCat's Current Offering (mp-453): while it is `founding`,
/// each plan shows the founding price with the normal one struck through,
/// under a "Founding member" line. Under the features sit the trial terms,
/// the price after the trial, the renewal terms and links to the terms and
/// privacy policy (mp-453 §4).
///
/// Everything secondary is behind the one ⋯ button (mp-494): Restore
/// purchases, Redeem code (our own Code entry, mp-458; this is the update
/// that ships it, mp-496 §3), Manage subscription (only when the account has
/// a store subscription on record), Sign out and Delete account. The same
/// menu serves the onboarding shape (mp-494 §2, replacing mp-417 §3).
///
/// One presentation for everyone without Pro (mp-280, mp-493 §5, mp-611):
/// full screen with no close button, for an account that never subscribed
/// and one whose Pro ended alike; nothing in the app sits behind it. The
/// router moves the person into the app the moment the gate opens.
///
/// UI only: purchase and restore live in [ProPaywallController]; Manage
/// subscription is the Subscription screen's [openManageSubscription];
/// whether there is a subscription to manage is
/// [paywallHasSubscriptionProvider]; sign-out and delete reuse
/// [SettingsController]'s flows; the gate itself is `appGateProvider`. All
/// copy comes from [ContentKeys].
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.onboarding = false});

  /// Reached as onboarding's last step (mp-417 §4). Since mp-494 §2 both
  /// shapes carry the same menu, so nothing on the screen differs yet; the
  /// route still says which shape it opened.
  final bool onboarding;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  /// The pinned plans tray, measured so a message floats above it.
  final _plansKey = GlobalKey();

  /// How much of the screen's bottom a message keeps clear: the plans and
  /// Continue while they are on screen, nothing before (the clip) or after
  /// (the paywall gone). A message that covered them hid Continue for its
  /// whole duration (11-005). Floating messages already stand above the
  /// bottom safe area, which the tray's height includes.
  double _plansClearance() {
    if (!mounted) return 0;
    final box = _plansKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return 0;
    final media = MediaQuery.of(context);
    final top = box.localToGlobal(Offset.zero).dy;
    final clearance = media.size.height - top - media.viewPadding.bottom;
    return clearance > 0 ? clearance : 0;
  }

  Future<void> _buy(BuildContext context, WidgetRef ref, Package pkg) async {
    final content = ref.read(contentServiceProvider);
    // Read before the purchase: once Pro is active every status says
    // `hadPro`, so only the status before the buy tells a returning account
    // (its Pro ended, 10-002) from a new one. The router resolved the
    // status before it showed this screen, so the future is already done.
    final returning = (await ref.read(
      subscriptionStatusProvider.future,
    )).hadPro;
    final outcome = await ref
        .read(proPaywallControllerProvider.notifier)
        .buy(pkg);
    if (!context.mounted) return;

    switch (outcome) {
      case ProPurchaseOutcome.activated:
        MealvanaSnackbar.showSuccess(
          context,
          content.getValue(
            returning
                ? ContentKeys.paywallPurchaseSuccessReturning
                : ContentKeys.paywallPurchaseSuccess,
          ),
          bottomClearance: _plansClearance(),
        );
      case ProPurchaseOutcome.purchasedPending:
        MealvanaSnackbar.showWarning(
          context,
          content.getValue(ContentKeys.paywallPurchasePending),
          bottomClearance: _plansClearance(),
        );
      case ProPurchaseOutcome.requiresAccount:
      case ProPurchaseOutcome.notSignedIn:
        // Anonymous / signed-out: the link-in-place signup keeps the auth id
        // the webhook maps the subscription onto. `/auth/*` is ungated.
        context.pushNamed(
          'auth-post-onboarding',
          queryParameters: {'mode': 'signup'},
        );
      case ProPurchaseOutcome.cancelled:
        break;
      case ProPurchaseOutcome.failed:
        // The ref.listen below already surfaces the AsyncError.
        break;
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final content = ref.read(contentServiceProvider);
    final active = await ref
        .read(proPaywallControllerProvider.notifier)
        .restore();
    if (!context.mounted) return;
    if (active) {
      MealvanaSnackbar.showSuccess(
        context,
        content.getValue(ContentKeys.paywallRestoreSuccess),
        bottomClearance: _plansClearance(),
      );
    } else {
      MealvanaSnackbar.showInfo(
        context,
        content.getValue(ContentKeys.paywallRestoreNone),
        bottomClearance: _plansClearance(),
      );
    }
  }

  /// The Subscription screen's Manage (87-007): the store's page, or the
  /// message for the store the plan came from, never a fixed one here.
  Future<void> _manage(BuildContext context, WidgetRef ref) =>
      openManageSubscription(context, ref, messageClearance: _plansClearance);

  Future<void> _openLink(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    final content = ref.read(contentServiceProvider);
    final launch = ref.read(paywallUrlLauncherProvider);
    var opened = false;
    try {
      opened = await launch(Uri.parse(url));
    } catch (_) {
      opened = false;
    }
    if (!context.mounted || opened) return;
    MealvanaSnackbar.showError(
      context,
      content.getValue(ContentKeys.paywallLinkFailed),
      bottomClearance: _plansClearance(),
    );
  }

  /// [note] and [manage] add a second line and a Manage subscription action
  /// (which closes the confirm, then runs [onManage]) when both are given.
  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    required String cancel,
    required bool destructive,
    String? note,
    String? manage,
    VoidCallback? onManage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: note == null
            ? Text(body)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(body),
                  const SizedBox(height: AppSpacing.md),
                  Text(note),
                ],
              ),
        actions: [
          if (note != null && manage != null)
            TextButton(
              key: const ValueKey('paywall.confirm.manage'),
              onPressed: () {
                Navigator.pop(context, false);
                onManage?.call();
              },
              child: Text(manage),
            ),
          TextButton(
            key: const ValueKey('paywall.confirm.cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancel),
          ),
          TextButton(
            key: const ValueKey('paywall.confirm.action'),
            onPressed: () => Navigator.pop(context, true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: AppColors.dragonfruit)
                : null,
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final content = ref.read(contentServiceProvider);
    final confirmed = await _confirm(
      context,
      title: content.getValue(ContentKeys.paywallSignOutConfirmTitle),
      // Settings' body, one key for both confirms (86-004).
      body: content.getValue(ContentKeys.settingsSignOutConfirmBody),
      action: content.getValue(ContentKeys.paywallSignOutButton),
      cancel: content.getValue(ContentKeys.paywallCancel),
      destructive: false,
    );
    if (!confirmed || !context.mounted) return;
    // Same flow as Settings: uploads dirty rows, clears the entitlement,
    // signs out of Supabase. The auth listener re-routes a session-less
    // route to /welcome by itself; the explicit go is the same belt and
    // braces Settings wears.
    await ref.read(settingsControllerProvider.notifier).signOut();
    if (context.mounted) GoRouter.maybeOf(context)?.go('/welcome');
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final content = ref.read(contentServiceProvider);
    // A store subscription that will renew outlives the account: say so and
    // offer Manage (finding 02-004).
    final renewing = await ref.read(renewingStoreSubscriptionProvider.future);
    if (!context.mounted) return;
    final confirmed = await _confirm(
      context,
      title: content.getValue(ContentKeys.paywallDeleteConfirmTitle),
      body: content.getValue(ContentKeys.paywallDeleteConfirmBody),
      action: content.getValue(ContentKeys.paywallDeleteConfirmAction),
      cancel: content.getValue(ContentKeys.paywallCancel),
      destructive: true,
      note: renewing
          ? content.getValue(ContentKeys.paywallDeleteConfirmSubscription)
          : null,
      manage: renewing
          ? content.getValue(ContentKeys.paywallManageButton)
          : null,
      onManage: () => _manage(context, ref),
    );
    if (!confirmed || !context.mounted) return;
    await ref
        .read(settingsControllerProvider.notifier)
        .deleteAccount(from: AccountDeletionEntry.paywall);
    if (context.mounted) GoRouter.maybeOf(context)?.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = ref.watch(contentServiceProvider);
    final plansAsync = ref.watch(paywallPlansProvider);
    final hasSubscription =
        ref.watch(paywallHasSubscriptionProvider).value ?? false;
    final paywallState = ref.watch(proPaywallControllerProvider);
    final isBusy = paywallState is AsyncLoading;

    ref.listen<AsyncValue<void>>(proPaywallControllerProvider, (_, next) {
      if (next is AsyncError) {
        MealvanaSnackbar.showError(
          context,
          content.getValue(ContentKeys.paywallPurchaseFailed),
          bottomClearance: _plansClearance(),
        );
      }
    });

    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final secondaryColor = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;

    final clipPlayer = ref.watch(paywallClipPlayerProvider);
    final clipPoster = ref.watch(paywallClipPosterProvider);
    final clipLabel = content.getValue(ContentKeys.paywallClipLabel);

    // mp-494 §1: exactly these, in this order; Manage only with a
    // subscription to manage. Redeem code opens our own entry, never the
    // store's offer-code sheet.
    void unlessBusy(void Function() action) {
      if (!isBusy) action();
    }

    final menu = [
      OverflowMenuEntry(
        key: const ValueKey('paywall.restore_button'),
        label: content.getValue(ContentKeys.paywallRestoreButton),
        onSelected: () => unlessBusy(() => _restore(context, ref)),
      ),
      OverflowMenuEntry(
        key: const ValueKey('paywall.redeem_code_button'),
        label: content.getValue(ContentKeys.redeemCodeButton),
        onSelected: () => unlessBusy(
          () => openRedeemCode(context, ref, messageClearance: _plansClearance),
        ),
      ),
      if (hasSubscription)
        OverflowMenuEntry(
          key: const ValueKey('paywall.manage_button'),
          label: content.getValue(ContentKeys.paywallManageButton),
          onSelected: () => unlessBusy(() => _manage(context, ref)),
        ),
      OverflowMenuEntry(
        key: const ValueKey('paywall.sign_out_button'),
        label: content.getValue(ContentKeys.paywallSignOutButton),
        onSelected: () => unlessBusy(() => _signOut(context, ref)),
      ),
      OverflowMenuEntry(
        key: const ValueKey('paywall.delete_account_button'),
        label: content.getValue(ContentKeys.paywallDeleteAccountButton),
        destructive: true,
        onSelected: () => unlessBusy(() => _deleteAccount(context, ref)),
      ),
    ];

    return Scaffold(
      key: const ValueKey('paywall.screen'),
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      body: _PaywallPages(
        // Page one: the clip of our own app, silent, in the phone frame
        // (mp-493 §1). A tap skips it.
        clip: (onEnded) => PhoneClipFrame(
          key: const ValueKey('paywall.clip'),
          player: clipPlayer,
          poster: clipPoster,
          aspectRatio: kPaywallClipAspectRatio,
          semanticLabel: clipLabel,
          onEnded: onEnded,
        ),
        // Page two: the ⋯ button, the features scrolling, and the plans
        // pinned under them with the one Continue.
        features: (reduceMotion) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    OverflowMenuButton(
                      key: const ValueKey('paywall.more_button'),
                      semanticLabel: content.getValue(
                        ContentKeys.paywallMoreLabel,
                      ),
                      color: textColor,
                      entries: menu,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('paywall.scroll'),
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Reduce Motion: the clip's first frame stands in for the
                    // clip (mp-493 §1).
                    if (reduceMotion) ...[
                      Center(
                        child: SizedBox(
                          width: 120,
                          child: PhoneClipFrame(
                            key: const ValueKey('paywall.clip_still'),
                            player: clipPlayer,
                            poster: clipPoster,
                            aspectRatio: kPaywallClipAspectRatio,
                            semanticLabel: clipLabel,
                            still: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    // The app's name and one line on what the prices below buy.
                    // No hero, no pitch beyond that (Lee, 2026-09-16).
                    Text(
                      key: const ValueKey('paywall.title'),
                      content.getValue(ContentKeys.paywallTitle),
                      style: AppTextStyles.h1.copyWith(color: textColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      key: const ValueKey('paywall.subtitle'),
                      content.getValue(ContentKeys.paywallSubtitle),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: secondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Four headline features, the divider and the rest; the AI
                    // features share the one Vana line (mp-493 §2).
                    const SizedBox(height: AppSpacing.xxl),
                    ProFeatureList(
                      key: const ValueKey('paywall.features'),
                      content: content,
                    ),

                    // Trial terms, the price after the trial, renewal and the
                    // two links (mp-453 §4), whatever the store answered.
                    const SizedBox(height: AppSpacing.xxl),
                    _PaywallTerms(
                      plans: plansAsync.value,
                      content: content,
                      color: secondaryColor,
                      onTerms: () =>
                          _openLink(context, ref, kTermsOfServiceUrl),
                      onPrivacy: () =>
                          _openLink(context, ref, kPrivacyPolicyUrl),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            // The plans and the one Continue, pinned (mp-493 §3).
            _PlansTray(
              key: _plansKey,
              plansAsync: plansAsync,
              content: content,
              isBusy: isBusy,
              secondaryColor: secondaryColor,
              onContinue: (pkg) => _buy(context, ref, pkg),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two pages of the paywall: the clip, then the features and plans.
/// The clip's end (or a tap on it) moves the page on; Reduce Motion starts
/// on the features with the clip's first frame at their head.
class _PaywallPages extends StatefulWidget {
  const _PaywallPages({required this.clip, required this.features});

  final Widget Function(VoidCallback onEnded) clip;
  final Widget Function(bool reduceMotion) features;

  @override
  State<_PaywallPages> createState() => _PaywallPagesState();
}

class _PaywallPagesState extends State<_PaywallPages> {
  bool _clipDone = false;

  void _moveOn() {
    if (!_clipDone && mounted) setState(() => _clipDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = SlideOverPager.reduceMotionOf(context);
    return SlideOverPager(
      showSecond: _clipDone || reduceMotion,
      first: GestureDetector(
        key: const ValueKey('paywall.clip_page'),
        behavior: HitTestBehavior.opaque,
        onTap: _moveOn,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Center(child: widget.clip(_moveOn)),
          ),
        ),
      ),
      second: widget.features(reduceMotion),
    );
  }
}

enum _Plan { annual, monthly }

/// The pinned tray: the "Founding member" line while founding prices are
/// on, the annual and monthly cards, and the one Continue that buys the
/// selected plan. Annual is selected until the person picks monthly
/// (mp-493 §3). While the store has not answered, or served nothing, the
/// tray says so and Continue has nothing to buy.
class _PlansTray extends StatefulWidget {
  const _PlansTray({
    super.key,
    required this.plansAsync,
    required this.content,
    required this.isBusy,
    required this.secondaryColor,
    required this.onContinue,
  });

  final AsyncValue<PaywallPlans> plansAsync;
  final ContentService content;
  final bool isBusy;
  final Color secondaryColor;
  final void Function(Package pkg) onContinue;

  @override
  State<_PlansTray> createState() => _PlansTrayState();
}

class _PlansTrayState extends State<_PlansTray> {
  _Plan _choice = _Plan.annual;

  /// The plans are inert while busy, as Continue is: a purchase, restore or
  /// redeemed Code has opened the app and the router is about to replace
  /// the paywall (05-004, 87-001).
  void _choose(_Plan plan) {
    if (!widget.isBusy) setState(() => _choice = plan);
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    String t(String key) => content.getValue(key);
    final plans = widget.plansAsync.value;
    final monthly = plans?.monthly;
    final annual = plans?.annual;
    final selected = switch (_choice) {
      _Plan.annual => annual ?? monthly,
      _Plan.monthly => monthly ?? annual,
    };

    final continueButton = KylePrimaryButton(
      key: const ValueKey('paywall.continue_button'),
      text: t(ContentKeys.paywallContinueButton),
      isLoading: widget.isBusy,
      onPressed: widget.isBusy || selected == null
          ? null
          : () => widget.onContinue(selected),
    );

    if (plans == null || plans.isEmpty) {
      return PlanCardTray(
        key: const ValueKey('paywall.plans'),
        cards: [
          if (widget.plansAsync.isLoading && plans == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(),
              ),
            )
          else
            _PricingUnavailable(
              key: const ValueKey('paywall.pricing_unavailable'),
              text: t(ContentKeys.paywallPricingUnavailable),
              color: widget.secondaryColor,
            ),
        ],
        action: continueButton,
      );
    }

    String? struck(Package pkg, String template) {
      final regular = plans.regularPriceFor(pkg);
      return regular == null
          ? null
          : ContentKeys.format(template, {'price': regular});
    }

    String? trial(Package pkg) {
      final offer = plans.introOfferFor(pkg);
      return offer == null
          ? null
          : ContentKeys.format(t(ContentKeys.paywallPlanTrial), {
              'days': offer.freeDays,
            });
    }

    final perMonth = t(ContentKeys.paywallPerMonth);
    final perYear = t(ContentKeys.paywallPerYear);
    final saving = plans.annualSavingPercent;
    final annualPerMonth = plans.annualPerMonthPrice();

    return PlanCardTray(
      key: const ValueKey('paywall.plans'),
      header: plans.isFounding
          ? Text(
              key: const ValueKey('paywall.founding_line'),
              t(ContentKeys.paywallFoundingLine),
              style: AppTextStyles.overline.copyWith(
                color: AppColors.electrolyte,
              ),
            )
          : null,
      cards: [
        if (annual != null)
          PlanCard(
            key: const ValueKey('paywall.plan.annual'),
            title: t(ContentKeys.paywallAnnualLabel),
            price: ContentKeys.format(perYear, {
              'price': annual.storeProduct.priceString,
            }),
            regularPrice: struck(annual, perYear),
            detail: annualPerMonth == null
                ? null
                : ContentKeys.format(t(ContentKeys.paywallPerMonthEquivalent), {
                    'price': annualPerMonth,
                  }),
            badge: saving == null
                ? null
                : ContentKeys.format(t(ContentKeys.paywallAnnualSaving), {
                    'percent': saving,
                  }),
            note: trial(annual),
            selected: identical(selected, annual),
            onSelected: () => _choose(_Plan.annual),
          ),
        if (monthly != null)
          PlanCard(
            key: const ValueKey('paywall.plan.monthly'),
            title: t(ContentKeys.paywallMonthlyLabel),
            price: ContentKeys.format(perMonth, {
              'price': monthly.storeProduct.priceString,
            }),
            regularPrice: struck(monthly, perMonth),
            note: trial(monthly),
            selected: identical(selected, monthly),
            onSelected: () => _choose(_Plan.monthly),
          ),
      ],
      action: continueButton,
    );
  }
}

/// The terms under the features: the free week and the price after it (from
/// the store, or the plain prices when the offer is spent), the renewal
/// terms, and links to the terms of use and the privacy policy. The price
/// line is left out while the store has not answered with both plans; the
/// renewal terms and links are always there.
class _PaywallTerms extends StatelessWidget {
  const _PaywallTerms({
    required this.plans,
    required this.content,
    required this.color,
    required this.onTerms,
    required this.onPrivacy,
  });

  final PaywallPlans? plans;
  final ContentService content;
  final Color color;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  String? _priceLine() {
    final monthly = plans?.monthly;
    final annual = plans?.annual;
    if (monthly == null || annual == null) return null;
    final prices = {
      'monthly': monthly.storeProduct.priceString,
      'annual': annual.storeProduct.priceString,
    };
    final offer = plans!.introOfferFor(monthly) ?? plans!.introOfferFor(annual);
    return offer == null
        ? ContentKeys.format(
            content.getValue(ContentKeys.paywallPlansTerms),
            prices,
          )
        : ContentKeys.format(content.getValue(ContentKeys.paywallTrialTerms), {
            ...prices,
            'days': offer.freeDays,
          });
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.bodySmall.copyWith(color: color);
    final priceLine = _priceLine();
    return Column(
      key: const ValueKey('paywall.terms'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (priceLine != null) ...[
          Text(
            key: const ValueKey('paywall.trial_terms'),
            priceLine,
            style: style,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          key: const ValueKey('paywall.renewal_terms'),
          content.getValue(ContentKeys.paywallRenewalTerms),
          style: style,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          children: [
            KyleTertiaryButton(
              key: const ValueKey('paywall.terms_link'),
              text: content.getValue(ContentKeys.paywallTermsLink),
              onPressed: onTerms,
            ),
            KyleTertiaryButton(
              key: const ValueKey('paywall.privacy_link'),
              text: content.getValue(ContentKeys.paywallPrivacyLink),
              onPressed: onPrivacy,
            ),
          ],
        ),
      ],
    );
  }
}

class _PricingUnavailable extends StatelessWidget {
  const _PricingUnavailable({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyMedium.copyWith(color: color),
      textAlign: TextAlign.center,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/services/privacy/privacy_links.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../application/pro_paywall_controller.dart';
import '../../domain/entitlement.dart';

/// Opens [uri] outside the app. A provider so widget tests can intercept
/// "Manage subscription" and the terms and privacy links instead of reaching
/// the url_launcher channel.
final paywallUrlLauncherProvider = Provider<Future<bool> Function(Uri uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// The paywall — where an inactive account lands after sign-in and stays
/// (mp-280). It offers the monthly and annual plans with the store's free
/// introductory week when the person is eligible (mp-279), and exactly four
/// other actions: Restore purchases, Manage subscription, Sign out and
/// Delete account. Prices come from RevenueCat's Current Offering (mp-453):
/// while it is `founding`, each plan shows the founding price with the
/// normal one struck through beside it, under a "Founding member" line.
/// Below the plans sit the trial terms, the price after the trial, the
/// renewal terms and links to the terms and privacy policy (mp-453 §4).
/// There is no close button: nothing renders behind it, and
/// the router moves the person into the app the moment the gate opens.
///
/// Two shapes of the one screen:
/// - lapsed (default): the four actions above;
/// - [onboarding]: the last step after account creation (mp-297). Plans and
///   Restore only — Manage, Sign out and Delete are for a lapsed account,
///   not one made a moment ago.
///
/// UI only: purchase / restore / management URL live in
/// [ProPaywallController]; sign-out and delete reuse [SettingsController]'s
/// flows; the gate itself is `appGateProvider`. All copy comes from
/// [ContentKeys].
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, this.onboarding = false});

  /// Reached as onboarding's last step: plans and Restore only.
  final bool onboarding;

  Future<void> _buy(BuildContext context, WidgetRef ref, Package pkg) async {
    final content = ref.read(contentServiceProvider);
    final outcome = await ref
        .read(proPaywallControllerProvider.notifier)
        .buy(pkg);
    if (!context.mounted) return;

    switch (outcome) {
      case ProPurchaseOutcome.activated:
        MealvanaSnackbar.showSuccess(
          context,
          content.getValue(ContentKeys.paywallPurchaseSuccess),
        );
      case ProPurchaseOutcome.purchasedPending:
        MealvanaSnackbar.showWarning(
          context,
          content.getValue(ContentKeys.paywallPurchasePending),
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
      );
    } else {
      MealvanaSnackbar.showInfo(
        context,
        content.getValue(ContentKeys.paywallRestoreNone),
      );
    }
  }

  Future<void> _manage(BuildContext context, WidgetRef ref) async {
    final content = ref.read(contentServiceProvider);
    final launch = ref.read(paywallUrlLauncherProvider);
    final uri = await ref
        .read(proPaywallControllerProvider.notifier)
        .managementUrl();
    final opened = uri != null && await launch(uri);
    if (!context.mounted || opened) return;
    MealvanaSnackbar.showInfo(
      context,
      content.getValue(ContentKeys.paywallManageUnavailable),
    );
  }

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
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    required String cancel,
    required bool destructive,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
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
      body: content.getValue(ContentKeys.paywallSignOutConfirmBody),
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
    final confirmed = await _confirm(
      context,
      title: content.getValue(ContentKeys.paywallDeleteConfirmTitle),
      body: content.getValue(ContentKeys.paywallDeleteConfirmBody),
      action: content.getValue(ContentKeys.paywallDeleteConfirmAction),
      cancel: content.getValue(ContentKeys.paywallCancel),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(settingsControllerProvider.notifier).deleteAccount();
    if (context.mounted) GoRouter.maybeOf(context)?.go('/welcome');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final content = ref.watch(contentServiceProvider);
    final plansAsync = ref.watch(paywallPlansProvider);
    final paywallState = ref.watch(proPaywallControllerProvider);
    final isBusy = paywallState is AsyncLoading;

    ref.listen<AsyncValue<void>>(proPaywallControllerProvider, (_, next) {
      if (next is AsyncError) {
        MealvanaSnackbar.showError(
          context,
          content.getValue(ContentKeys.paywallPurchaseFailed),
        );
      }
    });

    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final secondaryColor = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;

    return Scaffold(
      key: const ValueKey('paywall.screen'),
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
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
                style: AppTextStyles.bodyMedium.copyWith(color: secondaryColor),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Plans
              // A content card: solid fill + hairline, never glass
              // (tokens.md §Materials, boundaries).
              BaseCard(
                key: const ValueKey('paywall.pricing_card'),
                backgroundColor: isDark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    plansAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (_, _) => _PricingUnavailable(
                        text: content.getValue(
                          ContentKeys.paywallPricingUnavailable,
                        ),
                        color: secondaryColor,
                      ),
                      data: (plans) {
                        if (plans.isEmpty) {
                          return _PricingUnavailable(
                            key: const ValueKey('paywall.pricing_unavailable'),
                            text: content.getValue(
                              ContentKeys.paywallPricingUnavailable,
                            ),
                            color: secondaryColor,
                          );
                        }
                        final monthly = plans.monthly;
                        final annual = plans.annual;
                        final perMonth = content.getValue(
                          ContentKeys.paywallPerMonth,
                        );
                        final perYear = content.getValue(
                          ContentKeys.paywallPerYear,
                        );
                        String? struck(Package pkg, String template) {
                          final regular = plans.regularPriceFor(pkg);
                          return regular == null
                              ? null
                              : ContentKeys.format(template, {
                                  'price': regular,
                                });
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (plans.isFounding) ...[
                              Text(
                                key: const ValueKey('paywall.founding_line'),
                                content.getValue(
                                  ContentKeys.paywallFoundingLine,
                                ),
                                style: AppTextStyles.overline.copyWith(
                                  color: AppColors.electrolyte,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (monthly != null)
                              _PlanRow(
                                rowKey: const ValueKey('paywall.plan.monthly'),
                                buttonKey: const ValueKey(
                                  'paywall.subscribe_monthly',
                                ),
                                label: content.getValue(
                                  ContentKeys.paywallMonthlyLabel,
                                ),
                                price: ContentKeys.format(perMonth, {
                                  'price': monthly.storeProduct.priceString,
                                }),
                                regularPrice: struck(monthly, perMonth),
                                regularKey: const ValueKey(
                                  'paywall.plan.monthly.regular_price',
                                ),
                                intro: plans.introOfferFor(monthly),
                                content: content,
                                isBusy: isBusy,
                                onPressed: () => _buy(context, ref, monthly),
                                textColor: textColor,
                                secondaryColor: secondaryColor,
                              ),
                            if (monthly != null && annual != null)
                              const SizedBox(height: AppSpacing.md),
                            if (annual != null)
                              _PlanRow(
                                rowKey: const ValueKey('paywall.plan.annual'),
                                buttonKey: const ValueKey(
                                  'paywall.subscribe_annual',
                                ),
                                label: content.getValue(
                                  ContentKeys.paywallAnnualLabel,
                                ),
                                price: ContentKeys.format(perYear, {
                                  'price': annual.storeProduct.priceString,
                                }),
                                regularPrice: struck(annual, perYear),
                                regularKey: const ValueKey(
                                  'paywall.plan.annual.regular_price',
                                ),
                                intro: plans.introOfferFor(annual),
                                content: content,
                                isBusy: isBusy,
                                onPressed: () => _buy(context, ref, annual),
                                textColor: textColor,
                                secondaryColor: secondaryColor,
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Trial terms, the price after the trial, renewal and the two
              // links (mp-453 §4), whatever the store answered.
              const SizedBox(height: AppSpacing.lg),
              _PaywallTerms(
                plans: plansAsync.value,
                content: content,
                color: secondaryColor,
                onTerms: () => _openLink(context, ref, kTermsOfServiceUrl),
                onPrivacy: () => _openLink(context, ref, kPrivacyPolicyUrl),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // The four actions, and nothing else (mp-280 §2); Restore alone
              // in onboarding mode.
              KyleSecondaryButton(
                key: const ValueKey('paywall.restore_button'),
                text: content.getValue(ContentKeys.paywallRestoreButton),
                isLoading: isBusy,
                onPressed: isBusy ? null : () => _restore(context, ref),
              ),
              if (!onboarding) ...[
                const SizedBox(height: AppSpacing.sm),
                KyleTertiaryButton(
                  key: const ValueKey('paywall.manage_button'),
                  text: content.getValue(ContentKeys.paywallManageButton),
                  onPressed: isBusy ? null : () => _manage(context, ref),
                ),
                KyleTertiaryButton(
                  key: const ValueKey('paywall.sign_out_button'),
                  text: content.getValue(ContentKeys.paywallSignOutButton),
                  onPressed: isBusy ? null : () => _signOut(context, ref),
                ),
                TextButton(
                  key: const ValueKey('paywall.delete_account_button'),
                  onPressed: isBusy ? null : () => _deleteAccount(context, ref),
                  child: Text(
                    content.getValue(ContentKeys.paywallDeleteAccountButton),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.dragonfruit,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

/// One plan: label, localised price and (when the store grants it) the free
/// introductory line on the left; the buy button on the right.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.rowKey,
    required this.buttonKey,
    required this.label,
    required this.price,
    this.regularPrice,
    this.regularKey,
    required this.intro,
    required this.content,
    required this.isBusy,
    required this.onPressed,
    required this.textColor,
    required this.secondaryColor,
  });

  final Key rowKey;
  final Key buttonKey;
  final String label;
  final String price;

  /// The normal price, struck through beside [price] while founding prices
  /// are on (mp-453 §2); null otherwise.
  final String? regularPrice;
  final Key? regularKey;
  final IntroOffer? intro;
  final ContentService content;
  final bool isBusy;
  final VoidCallback onPressed;
  final Color textColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    final offer = intro;
    final regular = regularPrice;
    return Row(
      key: rowKey,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.h5.copyWith(color: textColor)),
              const SizedBox(height: AppSpacing.xs),
              if (offer != null)
                Text(
                  ContentKeys.format(
                    content.getValue(ContentKeys.paywallIntroLine),
                    {'days': offer.freeDays, 'price': price},
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.electrolyte,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  price,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: secondaryColor,
                  ),
                ),
              if (regular != null)
                Text(
                  key: regularKey,
                  regular,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: secondaryColor,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: secondaryColor,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        KylePrimaryButton(
          key: buttonKey,
          text: content.getValue(
            offer != null
                ? ContentKeys.paywallStartTrialButton
                : ContentKeys.paywallSubscribeButton,
          ),
          isFullWidth: false,
          isLoading: isBusy,
          onPressed: isBusy ? null : onPressed,
        ),
      ],
    );
  }
}

/// The terms under the plans: the free week and the price after it (from
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../application/pro_paywall_controller.dart';
import '../../domain/entitlement.dart';

/// Opens [uri] outside the app. A provider so widget tests can intercept
/// "Manage subscription" instead of reaching the url_launcher channel.
final paywallUrlLauncherProvider = Provider<Future<bool> Function(Uri uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// The paywall — where an inactive account lands after sign-in and stays
/// (mp-280). It offers the monthly and annual plans with the store's free
/// introductory week when the person is eligible (mp-279), and exactly four
/// other actions: Restore purchases, Manage subscription, Sign out and
/// Delete account. There is no close button: nothing renders behind it, and
/// the router moves the person into the app the moment the gate opens.
///
/// UI only: purchase / restore / management URL live in
/// [ProPaywallController]; sign-out and delete reuse [SettingsController]'s
/// flows; the gate itself is `appGateProvider`. All copy comes from
/// [ContentKeys].
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

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
              // Hero
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.orange, AppColors.dragonfruit],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.orange.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                    ),
                    child: Icon(Icons.bolt, size: 48, color: textColor),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    key: const ValueKey('paywall.title'),
                    content.getValue(ContentKeys.paywallTitle),
                    style: AppTextStyles.h1.copyWith(color: textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    content.getValue(ContentKeys.paywallSubtitle),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: secondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Plans
              BaseCard(
                key: const ValueKey('paywall.pricing_card'),
                backgroundColor: isDark
                    ? AppColors.blackberryLight.withValues(alpha: 0.5)
                    : AppColors.surfaceLight,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      content.getValue(ContentKeys.paywallPricingTitle),
                      style: AppTextStyles.h4.copyWith(color: textColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (monthly != null)
                              _PlanRow(
                                rowKey: const ValueKey('paywall.plan.monthly'),
                                buttonKey: const ValueKey(
                                  'paywall.subscribe_monthly',
                                ),
                                label: content.getValue(
                                  ContentKeys.paywallMonthlyLabel,
                                ),
                                price: ContentKeys.format(
                                  content.getValue(ContentKeys.paywallPerMonth),
                                  {'price': monthly.storeProduct.priceString},
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
                                price: ContentKeys.format(
                                  content.getValue(ContentKeys.paywallPerYear),
                                  {'price': annual.storeProduct.priceString},
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
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      content.getValue(ContentKeys.paywallCancelNote),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: secondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // The four actions, and nothing else (mp-280 §2).
              KyleSecondaryButton(
                key: const ValueKey('paywall.restore_button'),
                text: content.getValue(ContentKeys.paywallRestoreButton),
                isLoading: isBusy,
                onPressed: isBusy ? null : () => _restore(context, ref),
              ),
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
  final IntroOffer? intro;
  final ContentService content;
  final bool isBusy;
  final VoidCallback onPressed;
  final Color textColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    final offer = intro;
    return Row(
      key: rowKey,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.h5.copyWith(color: textColor)),
              const SizedBox(height: AppSpacing.xs),
              if (offer != null) ...[
                Text(
                  ContentKeys.format(
                    content.getValue(ContentKeys.paywallIntroLine),
                    {'days': offer.freeDays, 'price': price},
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.electrolyte,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else
                Text(
                  price,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: secondaryColor,
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

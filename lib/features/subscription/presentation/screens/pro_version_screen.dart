import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../shared/services/app_config.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../application/pro_paywall_controller.dart';
import '../../application/subscription_status_provider.dart';
import '../../domain/entitlement.dart';

/// Mealvana Pro — the subscription paywall (meal planning is Pro-only).
///
/// Reads the `default` RevenueCat offering for the real, localised
/// `$rc_monthly` / `$rc_annual` prices, shows the current [SubscriptionStatus]
/// and offers Restore. Buy buttons are live only when
/// [AppConfig.proPurchaseEnabled] — until the paywall is submitted with its
/// App Review screenshot the screen shows prices with purchasing disabled.
///
/// UI only: purchase / restore live in [ProPaywallController]; status in
/// `subscriptionStatusProvider`. All copy comes from [ContentKeys].
class ProVersionScreen extends ConsumerWidget {
  const ProVersionScreen({super.key});

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
          content.getValue(
            ContentKeys.proVersionPurchaseSuccess,
            defaultValue: 'Welcome to Mealvana Pro!',
          ),
        );
      case ProPurchaseOutcome.purchasedPending:
        MealvanaSnackbar.showWarning(
          context,
          content.getValue(
            ContentKeys.proVersionPurchasePending,
            defaultValue:
                'Your purchase went through — Pro will unlock in a moment.',
          ),
        );
      case ProPurchaseOutcome.requiresAccount:
      case ProPurchaseOutcome.notSignedIn:
        // Anonymous / signed-out: the link-in-place signup keeps the auth id
        // the webhook maps the subscription onto.
        context.pushNamed(
          'auth-post-onboarding',
          queryParameters: {'mode': 'signup'},
        );
      case ProPurchaseOutcome.cancelled:
      case ProPurchaseOutcome.disabled:
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
        content.getValue(
          ContentKeys.proVersionRestoreSuccess,
          defaultValue: 'Your Pro subscription has been restored.',
        ),
      );
    } else {
      MealvanaSnackbar.showInfo(
        context,
        content.getValue(
          ContentKeys.proVersionRestoreNone,
          defaultValue: 'No active subscription was found for this account.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final content = ref.watch(contentServiceProvider);
    final statusAsync = ref.watch(subscriptionStatusProvider);
    final offeringAsync = ref.watch(proOfferingProvider);
    final paywallState = ref.watch(proPaywallControllerProvider);
    final purchaseEnabled = ref.watch(appConfigProvider).proPurchaseEnabled;
    final isBusy = paywallState is AsyncLoading;
    final status = statusAsync.asData?.value ?? SubscriptionStatus.none;

    ref.listen<AsyncValue<void>>(proPaywallControllerProvider, (_, next) {
      if (next is AsyncError) {
        MealvanaSnackbar.showError(
          context,
          content.getValue(
            ContentKeys.proVersionPurchaseFailed,
            defaultValue: 'Purchase failed. Please try again.',
          ),
        );
      }
    });

    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final secondaryColor = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;

    return Scaffold(
      key: const ValueKey('pro_version.screen'),
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('pro_version.close_button'),
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                    child: Icon(
                      Icons.workspace_premium,
                      size: 48,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    key: const ValueKey('pro_version.title'),
                    content.getValue(
                      ContentKeys.proVersionTitle,
                      defaultValue: 'Mealvana Pro',
                    ),
                    style: AppTextStyles.h1.copyWith(color: textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (status.active)
                    _StatusBadge(
                      key: const ValueKey('pro_version.active_badge'),
                      label: content.getValue(
                        status.isTrial
                            ? ContentKeys.proVersionTrialBadge
                            : ContentKeys.proVersionActiveBadge,
                        defaultValue: status.isTrial
                            ? 'Free trial'
                            : "You're Pro",
                      ),
                      detail: status.expiresAt == null
                          ? null
                          : content
                                .getValue(
                                  ContentKeys.proVersionActiveUntil,
                                  defaultValue: 'Active until {date}',
                                )
                                .replaceAll(
                                  '{date}',
                                  MaterialLocalizations.of(
                                    context,
                                  ).formatMediumDate(
                                    status.expiresAt!.toLocal(),
                                  ),
                                ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    content.getValue(
                      ContentKeys.proVersionSubtitle,
                      defaultValue:
                          "Plan the week's meals with Vana, build the "
                          'shopping list, and cook with step-by-step '
                          'guidance — all tuned to your training.',
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: secondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Features
              Text(
                content.getValue(
                  ContentKeys.proVersionFeaturesTitle,
                  defaultValue: "What's included",
                ),
                style: AppTextStyles.h3.copyWith(color: textColor),
              ),
              const SizedBox(height: AppSpacing.lg),
              _FeatureCard(
                icon: Icons.auto_awesome,
                iconColor: AppColors.electrolyte,
                title: content.getValue(
                  ContentKeys.proVersionFeature1Title,
                  defaultValue: 'Meal planning with Vana',
                ),
                description: content.getValue(
                  ContentKeys.proVersionFeature1Description,
                  defaultValue:
                      'Tell Vana what you like and get a week of meals '
                      'matched to your training load, diet, and allergens.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _FeatureCard(
                icon: Icons.shopping_basket_outlined,
                iconColor: AppColors.orange,
                title: content.getValue(
                  ContentKeys.proVersionFeature2Title,
                  defaultValue: 'Shopping lists',
                ),
                description: content.getValue(
                  ContentKeys.proVersionFeature2Description,
                  defaultValue:
                      'One tap turns the plan into a shopping list you can '
                      'tick off in the aisle.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _FeatureCard(
                icon: Icons.restaurant_menu,
                iconColor: AppColors.dragonfruit,
                title: content.getValue(
                  ContentKeys.proVersionFeature3Title,
                  defaultValue: 'Recipes & cooking mode',
                ),
                description: content.getValue(
                  ContentKeys.proVersionFeature3Description,
                  defaultValue:
                      'Step-by-step directions with timers, plus the full '
                      'Mealvana recipe library.',
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Pricing
              BaseCard(
                key: const ValueKey('pro_version.pricing_card'),
                backgroundColor: isDark
                    ? AppColors.blackberryLight.withValues(alpha: 0.5)
                    : AppColors.surfaceLight,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      content.getValue(
                        ContentKeys.proVersionPricingTitle,
                        defaultValue: 'Choose your plan',
                      ),
                      style: AppTextStyles.h4.copyWith(color: textColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    offeringAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (_, _) => _PricingUnavailable(
                        text: content.getValue(
                          ContentKeys.proVersionPricingUnavailable,
                          defaultValue:
                              "Plans aren't available right now. "
                              'Please check back later.',
                        ),
                        color: secondaryColor,
                      ),
                      data: (offering) {
                        final monthly =
                            offering?.monthly ??
                            offering?.getPackage(r'$rc_monthly');
                        final annual =
                            offering?.annual ??
                            offering?.getPackage(r'$rc_annual');
                        if (monthly == null && annual == null) {
                          return _PricingUnavailable(
                            key: const ValueKey(
                              'pro_version.pricing_unavailable',
                            ),
                            text: content.getValue(
                              ContentKeys.proVersionPricingUnavailable,
                              defaultValue:
                                  "Plans aren't available right now. "
                                  'Please check back later.',
                            ),
                            color: secondaryColor,
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (monthly != null)
                              _PlanRow(
                                priceKey: const ValueKey(
                                  'pro_version.monthly_price',
                                ),
                                buttonKey: const ValueKey(
                                  'pro_version.subscribe_monthly',
                                ),
                                label: content.getValue(
                                  ContentKeys.proVersionMonthlyLabel,
                                  defaultValue: 'Monthly',
                                ),
                                price: content
                                    .getValue(
                                      ContentKeys.proVersionPerMonth,
                                      defaultValue: '{price} / month',
                                    )
                                    .replaceAll(
                                      '{price}',
                                      monthly.storeProduct.priceString,
                                    ),
                                buttonText: content.getValue(
                                  ContentKeys.proVersionSubscribeButton,
                                  defaultValue: 'Subscribe',
                                ),
                                enabled:
                                    purchaseEnabled && !isBusy && !status.active,
                                isLoading: isBusy,
                                onPressed: () => _buy(context, ref, monthly),
                                textColor: textColor,
                                secondaryColor: secondaryColor,
                              ),
                            if (monthly != null && annual != null)
                              const SizedBox(height: AppSpacing.md),
                            if (annual != null)
                              _PlanRow(
                                priceKey: const ValueKey(
                                  'pro_version.annual_price',
                                ),
                                buttonKey: const ValueKey(
                                  'pro_version.subscribe_annual',
                                ),
                                label: content.getValue(
                                  ContentKeys.proVersionAnnualLabel,
                                  defaultValue: 'Annual',
                                ),
                                price: content
                                    .getValue(
                                      ContentKeys.proVersionPerYear,
                                      defaultValue: '{price} / year',
                                    )
                                    .replaceAll(
                                      '{price}',
                                      annual.storeProduct.priceString,
                                    ),
                                buttonText: content.getValue(
                                  ContentKeys.proVersionSubscribeButton,
                                  defaultValue: 'Subscribe',
                                ),
                                enabled:
                                    purchaseEnabled && !isBusy && !status.active,
                                isLoading: isBusy,
                                onPressed: () => _buy(context, ref, annual),
                                textColor: textColor,
                                secondaryColor: secondaryColor,
                              ),
                            if (!purchaseEnabled && !status.active) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                key: const ValueKey(
                                  'pro_version.purchase_coming_soon',
                                ),
                                content.getValue(
                                  ContentKeys.proVersionPurchaseComingSoon,
                                  defaultValue:
                                      'Subscriptions open soon. The prices '
                                      'shown are final.',
                                ),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: secondaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    KyleTertiaryButton(
                      key: const ValueKey('pro_version.restore_button'),
                      text: content.getValue(
                        ContentKeys.proVersionRestoreButton,
                        defaultValue: 'Restore purchases',
                      ),
                      isLoading: isBusy,
                      onPressed: () => _restore(context, ref),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      content.getValue(
                        ContentKeys.proVersionManageNote,
                        defaultValue:
                            'Cancel anytime in your App Store or Google Play '
                            'subscription settings.',
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: secondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
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

/// "You're Pro" / "Free trial" pill with an optional expiry line.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({super.key, required this.label, this.detail});

  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.electrolyte,
            borderRadius: AppRadius.buttonRadius,
          ),
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textLight,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            detail!,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textDarkSecondary
                  : AppColors.textLightSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// One plan: label + localised price on the left, Subscribe on the right.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.priceKey,
    required this.buttonKey,
    required this.label,
    required this.price,
    required this.buttonText,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
    required this.textColor,
    required this.secondaryColor,
  });

  final Key priceKey;
  final Key buttonKey;
  final String label;
  final String price;
  final String buttonText;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;
  final Color textColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.h5.copyWith(color: textColor),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                key: priceKey,
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
          text: buttonText,
          isFullWidth: false,
          isLoading: isLoading,
          onPressed: enabled ? onPressed : null,
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

/// Feature card widget
class _FeatureCard extends ConsumerWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BaseCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h5.copyWith(
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textDarkSecondary
                        : AppColors.textLightSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

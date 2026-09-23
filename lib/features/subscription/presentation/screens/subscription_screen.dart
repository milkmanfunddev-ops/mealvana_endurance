import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../application/subscription_screen_controller.dart';
import '../../domain/grant.dart';
import '../open_paywall.dart';
import '../widgets/pro_feature_list.dart';
import '../widgets/redeem_code_sheet.dart';
import 'paywall_screen.dart';

/// The Subscription screen in Settings (mp-495, approved as mp-500).
///
/// The plan's status with its date (a trial with the day it ends, active
/// with the day it renews, founding member, or ended; a Grant with where it
/// came from and its days left, mp-558), then what Pro
/// includes as a tick list with the AI features under the one Vana line, as
/// on the paywall. Upgrade opens the paywall, only once the plan has ended;
/// Manage subscription opens the store's own page, only with a store
/// subscription on record. Redeem code opens our own Code entry (mp-458),
/// always there: a Code can grant Pro, pair or refer whatever the plan.
///
/// Built from the paywall's `kyle_design` pieces (`FeatureList`, the Kyle
/// buttons, `BaseCard`) in our branding (mp-495 §4). UI only: the status is
/// [SubscriptionScreenController]'s; Manage goes where the paywall's does.
///
/// Settings reaches it by a named push ([route], [routeName]) rather than a
/// router entry.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  static const routeName = '/settings/subscription';

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (_) => const SubscriptionScreen(),
    settings: const RouteSettings(name: routeName),
  );

  Future<void> _manage(BuildContext context, WidgetRef ref) async {
    final content = ref.read(contentServiceProvider);
    final launch = ref.read(paywallUrlLauncherProvider);
    final uri = await ref
        .read(subscriptionScreenControllerProvider.notifier)
        .managementUrl();
    var opened = false;
    if (uri != null) {
      try {
        opened = await launch(uri);
      } catch (_) {
        opened = false;
      }
    }
    if (!context.mounted || opened) return;
    MealvanaSnackbar.showInfo(
      context,
      content.getValue(ContentKeys.paywallManageUnavailable),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = ref.watch(contentServiceProvider);
    final screen = ref.watch(subscriptionScreenControllerProvider);
    final state = screen.value;
    String t(String key) => content.getValue(key);

    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final secondaryColor = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;

    return Scaffold(
      key: const ValueKey('subscription.screen'),
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CustomAppBarBackButton(
          key: const ValueKey('subscription.back_button'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          t(ContentKeys.subscriptionTitle),
          style: AppTextStyles.sectionTitle.copyWith(color: textColor),
        ),
      ),
      body: state == null && screen.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.electrolyte),
            )
          : SingleChildScrollView(
              key: const ValueKey('subscription.scroll'),
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state != null) ...[
                    _PlanStatusCard(
                      state: state,
                      content: content,
                      textColor: textColor,
                      secondaryColor: secondaryColor,
                    ),
                    if (state.canUpgrade) ...[
                      const SizedBox(height: AppSpacing.md),
                      KylePrimaryButton(
                        key: const ValueKey('subscription.upgrade_button'),
                        text: t(ContentKeys.subscriptionUpgradeButton),
                        // The same way in as the AI guard: the app goes to
                        // the full-screen paywall.
                        onPressed: () => openPaywall(GoRouter.of(context)),
                      ),
                    ],
                    if (state.canManage) ...[
                      const SizedBox(height: AppSpacing.md),
                      KyleSecondaryButton(
                        key: const ValueKey('subscription.manage_button'),
                        text: t(ContentKeys.paywallManageButton),
                        onPressed: () => _manage(context, ref),
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  KyleTertiaryButton(
                    key: const ValueKey('subscription.redeem_code_button'),
                    text: t(ContentKeys.redeemCodeButton),
                    onPressed: () => openRedeemCode(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    key: const ValueKey('subscription.includes_header'),
                    t(ContentKeys.subscriptionIncludesHeader),
                    style: AppTextStyles.h3.copyWith(color: textColor),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ProFeatureList(
                    key: const ValueKey('subscription.features'),
                    content: content,
                    ticks: true,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
    );
  }
}

/// The plan's status and the date that goes with it.
class _PlanStatusCard extends StatelessWidget {
  const _PlanStatusCard({
    required this.state,
    required this.content,
    required this.textColor,
    required this.secondaryColor,
  });

  final SubscriptionScreenState state;
  final ContentService content;
  final Color textColor;
  final Color secondaryColor;

  String? _dateLine() {
    final date = state.date;
    final String key;
    switch (state.plan) {
      case PlanStatus.trial:
        if (date == null) return null;
        key = state.willRenew
            ? ContentKeys.subscriptionTrialEnds
            : ContentKeys.subscriptionTrialEndsNoRenew;
      case PlanStatus.active:
      case PlanStatus.founding:
        if (date == null) return null;
        key = state.willRenew
            ? ContentKeys.subscriptionRenews
            : ContentKeys.subscriptionEnds;
      case PlanStatus.ended:
        if (date == null) {
          return content.getValue(ContentKeys.subscriptionEndedNoDate);
        }
        key = ContentKeys.subscriptionEndedOn;
      case PlanStatus.grant:
        return _daysLeftLine();
    }
    return ContentKeys.format(content.getValue(key), {
      'date': DateFormat.yMMMMd().format(date.toLocal()),
    });
  }

  /// A Grant's days left: "12 days left", "1 day left", or its last day.
  String? _daysLeftLine() {
    final days = state.daysLeft;
    if (days == null) return null;
    if (days == 0) {
      return content.getValue(ContentKeys.subscriptionGrantLastDay);
    }
    if (days == 1) {
      return content.getValue(ContentKeys.subscriptionGrantOneDayLeft);
    }
    return ContentKeys.format(
      content.getValue(ContentKeys.subscriptionGrantDaysLeft),
      {'days': days},
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = content.getValue(switch (state.plan) {
      PlanStatus.trial => ContentKeys.subscriptionStatusTrial,
      PlanStatus.active => ContentKeys.subscriptionStatusActive,
      PlanStatus.founding => ContentKeys.subscriptionStatusFounding,
      PlanStatus.ended => ContentKeys.subscriptionStatusEnded,
      PlanStatus.grant => switch (state.grantSource) {
        GrantSource.legacyGrace => ContentKeys.subscriptionStatusGrantGrace,
        GrantSource.code || null => ContentKeys.subscriptionStatusGrantCode,
      },
    });
    final dateLine = _dateLine();
    return BaseCard(
      key: const ValueKey('subscription.status_card'),
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key: const ValueKey('subscription.status'),
            status,
            style: AppTextStyles.h3.copyWith(
              color: state.plan == PlanStatus.founding
                  ? AppColors.electrolyte
                  : textColor,
            ),
          ),
          if (dateLine != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              key: const ValueKey('subscription.date'),
              dateLine,
              style: AppTextStyles.bodyMedium.copyWith(color: secondaryColor),
            ),
          ],
        ],
      ),
    );
  }
}

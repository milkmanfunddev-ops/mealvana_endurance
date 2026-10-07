import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';

/// Coming soon card: icon tile, title and description on a BaseCard, with a
/// Notify Me that records the interest and says so (testing-wave 117-006;
/// it used to be drawn live and do nothing). The same shape as Connected
/// Apps' Notify Me: one analytics event, then a "Noted" state that stays
/// inert, so a second tap writes nothing.
class ComingSoonSectionWidget extends ConsumerStatefulWidget {
  const ComingSoonSectionWidget({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.notifyButtonKey,
  });

  final FaIconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final Key? notifyButtonKey;

  /// The event a Notify Me tap records, with the card's title as `card`.
  static const String notifyEvent = 'education_notify_me_tapped';

  @override
  ConsumerState<ComingSoonSectionWidget> createState() =>
      _ComingSoonSectionWidgetState();
}

class _ComingSoonSectionWidgetState
    extends ConsumerState<ComingSoonSectionWidget> {
  /// In-memory for this screen visit, as Connected Apps' is: the ask is a
  /// one-off signal, not a setting.
  bool _notified = false;

  void _notify() {
    if (_notified) return;
    setState(() => _notified = true);
    try {
      ref
          .read(appExternalDepsProvider)
          .analytics
          .track(
            ComingSoonSectionWidget.notifyEvent,
            properties: {'card': widget.title},
          );
    } catch (_) {
      // Analytics never blocks the confirmation.
    }
    MealvanaSnackbar.showSuccess(
      context,
      ref.read(contentServiceProvider).getValue(
        ContentKeys.learnNotifyMeConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final content = ref.watch(contentServiceProvider);

    return BaseCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(widget.icon, color: widget.iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),

              // Title + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.h5.copyWith(
                        color: isDark
                            ? AppColors.textDark
                            : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Coming Soon badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.electrolyte,
                        borderRadius: AppRadius.buttonRadius,
                      ),
                      child: Text(
                        'Coming Soon',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.description,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textDarkSecondary
                  : AppColors.textLightSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Notify Me — mirrors _NotifyButton in integration_provider_card.dart:
          // a light-variant secondary button, live until tapped, then the
          // disabled "Noted" state with a check.
          KyleSecondaryButtonSmall(
            key: widget.notifyButtonKey,
            text: content.getValue(
              _notified
                  ? ContentKeys.learnNotifyMeNoted
                  : ContentKeys.learnNotifyMe,
            ),
            onPressed: _notified ? null : _notify,
            icon: _notified ? Icons.check_circle : null,
            variant: SecondaryButtonVariant.light,
          ),
        ],
      ),
    );
  }
}

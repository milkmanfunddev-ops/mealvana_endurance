import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/secondary_button.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Card displaying an integration provider (Final Surge, TrainingPeaks, etc.)
///
/// Shows connection status and allows connect/disconnect/sync actions.
/// Logo should include the provider wordmark - no separate text label is shown.
class IntegrationProviderCard extends StatelessWidget {
  const IntegrationProviderCard({
    super.key,
    required this.name,
    required this.isAvailable,
    required this.isConnected,
    required this.isConnecting,
    this.iconPath,
    this.logoHeight = 24,
    this.athleteName,
    this.lastSyncAt,
    this.comingSoonText,
    this.statusText,
    this.onConnect,
    this.onDisconnect,
    this.onSync,
    this.onNotify,
    this.isSyncing = false,
    this.showSyncButton = true,
    this.hasSynced = false,
    this.isNotified = false,
  });

  /// Provider name (used for placeholder if no logo, not displayed as text)
  final String name;

  /// Path to provider logo image (PNG or SVG with wordmark)
  final String? iconPath;

  /// Height for the logo (default 24, adjust per provider for visual balance)
  final double logoHeight;

  /// Whether this provider is available for connection
  final bool isAvailable;

  /// Whether user is connected to this provider
  final bool isConnected;

  /// Whether connection is in progress
  final bool isConnecting;

  /// Athlete name from provider (shown when connected)
  final String? athleteName;

  /// Last sync timestamp from provider (shown when connected)
  final DateTime? lastSyncAt;

  /// Text to show if not available (e.g., "Coming Soon")
  final String? comingSoonText;

  /// Optional status text displayed below the logo (e.g., "Coming soon")
  final String? statusText;

  /// Callback when user taps Connect
  final VoidCallback? onConnect;

  /// Callback when user taps Disconnect
  final VoidCallback? onDisconnect;

  /// Callback when user taps Sync Now (when connected)
  final VoidCallback? onSync;

  /// Callback when user taps Notify Me (for coming soon integrations)
  final VoidCallback? onNotify;

  /// Whether sync is in progress
  final bool isSyncing;

  /// Whether to show "Sync Now" button when connected.
  /// If false, shows "Connected" badge instead.
  final bool showSyncButton;

  /// Whether sync has completed successfully (shows "Synced!" instead of "Sync Now").
  /// This is in-memory only and resets when navigating away.
  final bool hasSynced;

  /// Whether user has requested notification (shows "Notified!" state).
  final bool isNotified;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? AppColors.blackberryLight
        : Theme.of(context).colorScheme.surface;
    final secondaryText = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isConnected
            ? Border.all(color: AppColors.success, width: 2)
            : null,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Logo and action button
          Row(
            children: [
              // Provider logo with wordmark (no separate text label)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildLogo(context),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Action button - fixed width to prevent logo shifting during state changes
              SizedBox(
                width: 200,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildAction(context),
                ),
              ),
            ],
          ),

          if (statusText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              statusText!,
              style: AppTextStyles.bodySmall.copyWith(
                color: secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Bottom row: Athlete name and last sync timestamp (when connected)
          if (isConnected && (athleteName != null || lastSyncAt != null)) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildConnectionInfo(context),
          ],
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    if (iconPath == null) {
      return _buildPlaceholderIcon(context);
    }

    // Check if it's an SVG file
    final isSvg = iconPath!.toLowerCase().endsWith('.svg');

    return SizedBox(
      height: logoHeight,
      child: isSvg
          ? SvgPicture.asset(
              iconPath!,
              height: logoHeight,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => _buildPlaceholderIcon(context),
            )
          : Image.asset(
              iconPath!,
              height: logoHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildPlaceholderIcon(context),
            ),
    );
  }

  Widget _buildPlaceholderIcon(BuildContext context) {
    return Text(
      name,
      style: AppTextStyles.activityTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    // Coming soon badge
    if (!isAvailable) {
      if (onNotify != null) {
        return _NotifyButton(onNotify: onNotify, isNotified: isNotified);
      }
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.blackberry,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          comingSoonText ?? 'Coming Soon',
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Connecting or syncing spinner
    if (isConnecting || isSyncing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.dragonfruit,
            ),
          ),
          if (isSyncing) ...[
            const SizedBox(width: 8),
            Text(
              'Syncing...',
              style: AppTextStyles.smallLabel.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }

    // Connected - show Sync Now button or Connected badge
    if (isConnected) {
      if (showSyncButton) {
        return _SyncButton(
          onSync: onSync,
          onDisconnect: onDisconnect,
          hasSynced: hasSynced,
        );
      } else {
        return _ConnectedBadge();
      }
    }

    // Not connected - show connect button
    return _ConnectButton(onConnect: onConnect);
  }

  /// Build the connection info section showing athlete name and last sync timestamp
  Widget _buildConnectionInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Athlete name
        if (athleteName != null)
          Text(
            athleteName!,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

        // Last sync timestamp
        if (lastSyncAt != null) ...[
          if (athleteName != null) const SizedBox(height: 2),
          Text(
            _formatLastSync(lastSyncAt!),
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  /// Format the last sync timestamp
  /// Example: "Last synced: Jan 16 at 3:42 PM"
  String _formatLastSync(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // If synced today, show relative time
    if (difference.inMinutes < 1) {
      return 'Last synced: Just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return 'Last synced: $minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24 && timestamp.day == now.day) {
      final hours = difference.inHours;
      return 'Last synced: $hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }

    // For older syncs, show formatted date
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[timestamp.month - 1];
    final day = timestamp.day;

    // Format time as 12-hour with AM/PM
    final hour = timestamp.hour > 12
        ? timestamp.hour - 12
        : (timestamp.hour == 0 ? 12 : timestamp.hour);
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';

    return 'Last synced: $month $day at $hour:$minute $period';
  }
}

/// Sync button for connected providers - shows Sync Now with long-press to disconnect
/// Shows "Synced!" after successful sync (in-memory only, resets on navigation)
class _SyncButton extends StatelessWidget {
  const _SyncButton({this.onSync, this.onDisconnect, this.hasSynced = false});

  final VoidCallback? onSync;
  final VoidCallback? onDisconnect;
  final bool hasSynced;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSync,
      onLongPress: () => _showDisconnectDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.dragonfruit,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSynced ? Icons.check_circle : Icons.sync,
              size: 16,
              color: AppColors.textDark,
            ),
            const SizedBox(width: 4),
            Text(
              hasSynced ? 'Synced!' : 'Sync Now',
              style: AppTextStyles.buttonPrimary.copyWith(
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisconnectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.blackberryLight,
        title: Text(
          'Disconnect?',
          style: AppTextStyles.sectionTitle.copyWith(color: AppColors.textDark),
        ),
        content: Text(
          'Your imported workouts will remain, but no new workouts will be synced.\n\nTip: Long-press Sync Now to disconnect.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textDarkSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.buttonTertiary.copyWith(
                color: AppColors.textDarkSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDisconnect?.call();
            },
            child: Text(
              'Disconnect',
              style: AppTextStyles.buttonTertiary.copyWith(
                color: AppColors.dragonfruit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Connect button for unconnected providers
class _ConnectButton extends StatelessWidget {
  const _ConnectButton({this.onConnect});

  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onConnect,
      child: Container(
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 36, minWidth: 96),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.dragonfruit,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Connect',
          style: AppTextStyles.buttonPrimary.copyWith(
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Connected badge shown when sync button is disabled (e.g., in onboarding)
class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.dragonfruit,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: AppColors.textDark),
          const SizedBox(width: 4),
          Text(
            'Connected',
            style: AppTextStyles.buttonPrimary.copyWith(
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Notify Me button for coming soon providers
class _NotifyButton extends StatelessWidget {
  const _NotifyButton({this.onNotify, this.isNotified = false});

  final VoidCallback? onNotify;
  final bool isNotified;

  @override
  Widget build(BuildContext context) {
    return KyleSecondaryButtonSmall(
      text: isNotified ? 'Notified!' : 'Notify Me',
      onPressed: isNotified ? null : onNotify,
      icon: isNotified ? Icons.check_circle : null,
      variant: SecondaryButtonVariant.light,
    );
  }
}

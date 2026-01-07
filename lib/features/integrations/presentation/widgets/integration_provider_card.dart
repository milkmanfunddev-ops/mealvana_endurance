import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    this.comingSoonText,
    this.onConnect,
    this.onDisconnect,
    this.onSync,
    this.isSyncing = false,
    this.showSyncButton = true,
    this.hasSynced = false,
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

  /// Text to show if not available (e.g., "Coming Soon")
  final String? comingSoonText;

  /// Callback when user taps Connect
  final VoidCallback? onConnect;

  /// Callback when user taps Disconnect
  final VoidCallback? onDisconnect;

  /// Callback when user taps Sync Now (when connected)
  final VoidCallback? onSync;

  /// Whether sync is in progress
  final bool isSyncing;

  /// Whether to show "Sync Now" button when connected.
  /// If false, shows "Connected" badge instead.
  final bool showSyncButton;

  /// Whether sync has completed successfully (shows "Synced!" instead of "Sync Now").
  /// This is in-memory only and resets when navigating away.
  final bool hasSynced;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.blackberryLight,
        borderRadius: BorderRadius.circular(12),
        border: isConnected
            ? Border.all(color: AppColors.success, width: 2)
            : null,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // Provider logo with wordmark (no separate text label)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildLogo(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Action button - fixed width to prevent logo shifting during state changes
          SizedBox(
            width: 200,
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildAction(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    if (iconPath == null) {
      return _buildPlaceholderIcon();
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
              placeholderBuilder: (_) => _buildPlaceholderIcon(),
            )
          : Image.asset(
              iconPath!,
              height: logoHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
            ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Text(
      name,
      style: AppTextStyles.activityTitle.copyWith(color: AppColors.textDark, fontSize: 14),
    );
  }

  Widget _buildAction() {
    // Coming soon badge
    if (!isAvailable) {
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
          style: AppTextStyles.smallLabel.copyWith(color: AppColors.textDarkSecondary),
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
              style: AppTextStyles.smallLabel.copyWith(color: AppColors.textDarkSecondary),
            ),
          ],
        ],
      );
    }

    // Connected - show Sync Now button or Connected badge
    if (isConnected) {
      if (showSyncButton) {
        return _SyncButton(onSync: onSync, onDisconnect: onDisconnect, hasSynced: hasSynced);
      } else {
        return _ConnectedBadge();
      }
    }

    // Not connected - show connect button
    return _ConnectButton(onConnect: onConnect);
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
              style: AppTextStyles.buttonPrimary.copyWith(color: AppColors.textDark),
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
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.buttonTertiary.copyWith(color: AppColors.textDarkSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDisconnect?.call();
            },
            child: Text(
              'Disconnect',
              style: AppTextStyles.buttonTertiary.copyWith(color: AppColors.dragonfruit),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.dragonfruit,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Connect',
          style: AppTextStyles.buttonPrimary.copyWith(color: AppColors.textDark),
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
          Icon(
            Icons.check_circle,
            size: 16,
            color: AppColors.textDark,
          ),
          const SizedBox(width: 4),
          Text(
            'Connected',
            style: AppTextStyles.buttonPrimary.copyWith(color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Card displaying an integration provider (Final Surge, TrainingPeaks, etc.)
///
/// Shows connection status and allows connect/disconnect actions.
class IntegrationProviderCard extends StatelessWidget {
  const IntegrationProviderCard({
    super.key,
    required this.name,
    required this.description,
    required this.isAvailable,
    required this.isConnected,
    required this.isConnecting,
    this.iconPath,
    this.athleteName,
    this.comingSoonText,
    this.onConnect,
    this.onDisconnect,
  });

  /// Provider name (e.g., "Final Surge")
  final String name;

  /// Provider description
  final String description;

  /// Path to provider logo image
  final String? iconPath;

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
          // Provider logo
          _buildLogo(),
          const SizedBox(width: AppSpacing.md),

          // Provider info
          Expanded(child: _buildInfo()),

          // Action button
          _buildAction(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.blackberry,
        borderRadius: BorderRadius.circular(8),
      ),
      child: iconPath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                iconPath!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholderIcon(),
              ),
            )
          : _buildPlaceholderIcon(),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTextStyles.dateTime.copyWith(color: AppColors.textDark),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: AppTextStyles.activityTitle.copyWith(color: AppColors.textDark),
        ),
        const SizedBox(height: 2),
        if (isConnected && athleteName != null) ...[
          Text(
            'Connected as $athleteName',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
          ),
        ] else ...[
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDarkSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildAction() {
    // Coming soon badge
    if (!isAvailable) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
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

    // Connecting spinner
    if (isConnecting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.dragonfruit,
        ),
      );
    }

    // Connected - show disconnect option
    if (isConnected) {
      return _ConnectedBadge(onDisconnect: onDisconnect);
    }

    // Not connected - show connect button
    return _ConnectButton(onConnect: onConnect);
  }
}

/// Badge showing connected status with disconnect option
class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge({this.onDisconnect});

  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDisconnectDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 16,
              color: AppColors.success,
            ),
            const SizedBox(width: 4),
            Text(
              'Connected',
              style: AppTextStyles.smallLabel.copyWith(color: AppColors.success),
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
          'Your imported workouts will remain, but no new workouts will be synced.',
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
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
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

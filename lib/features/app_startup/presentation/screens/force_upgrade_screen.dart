import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Force Upgrade Screen
/// Blocks the app when a mandatory update is required
///
/// Displays:
/// - Current version vs required version
/// - Update required message
/// - Platform-specific app store link
/// - Blocks back navigation
class ForceUpgradeScreen extends StatelessWidget {
  const ForceUpgradeScreen({
    super.key,
    required this.currentVersion,
    required this.requiredVersion,
  });

  final String currentVersion;
  final String requiredVersion;

  // App Store URLs (replace with real values when available)
  static const String _iosAppStoreUrl =
      'https://apps.apple.com/app/id123456789';
  static const String _androidPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.mealvana.endurance';
  static const String _webAppUrl = 'https://app.mealvana.com';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Block back navigation
      canPop: false,
      child: AdaptivePageScaffold(
        backgroundColor: AppColors.blackberry,
        contentWidth: AdaptiveContentWidth.narrow,
        body: AdaptiveScrollableBody(
          safeAreaTop: true,
          safeAreaBottom: true,
          padding: AppSpacing.screenPadding,
          footer: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.lg,
            ),
            child: KylePrimaryButton(
              text: 'Update Now',
              onPressed: _openAppStore,
              isFullWidth: false,
            ),
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Update icon
        Icon(
          Icons.system_update,
          size: AppIconSizes.xxl + 16, // 80px
          color: AppColors.warning,
        ),

        const SizedBox(height: AppSpacing.xl),

        // Title
        Text(
          'Update Required',
          style: AppTextStyles.pageTitle.copyWith(color: AppColors.textDark),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.md),

        // Message
        Text(
          'Please update to version $requiredVersion or later to continue using Mealvana Endurance.',
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textDark),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.sm),

        // Current version info
        Text(
          'Your current version: $currentVersion',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textDarkSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Opens the appropriate app store based on platform
  Future<void> _openAppStore() async {
    String url;

    if (kIsWeb) {
      url = _webAppUrl;
    } else if (Platform.isIOS) {
      url = _iosAppStoreUrl;
    } else if (Platform.isAndroid) {
      url = _androidPlayStoreUrl;
    } else {
      // Fallback for other platforms
      url = _webAppUrl;
    }

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

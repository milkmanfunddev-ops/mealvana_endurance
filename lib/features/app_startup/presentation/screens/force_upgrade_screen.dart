import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/services/app_config.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Force Upgrade Screen
/// Blocks the app when a mandatory update is required
///
/// The required version comes from `app_config.min_app_version` in Supabase,
/// read by `VersionCheckService`. Dev and prod are separate Supabase projects,
/// so each flavor already reads its own minimum — the only thing this screen
/// has to get right is where it sends the user to *get* the update, and that
/// differs by flavor:
///
/// | flavor | iOS        | Android                    |
/// |--------|------------|----------------------------|
/// | dev    | TestFlight | Play (`.dev` package)      |
/// | prod   | App Store  | Play                       |
///
/// The dev build is a Shorebird/TestFlight release binary, so sending a tester
/// to the public App Store listing would offer them the *prod* app — a
/// different bundle id, which would not update the app they are stuck in.
class ForceUpgradeScreen extends ConsumerWidget {
  const ForceUpgradeScreen({
    super.key,
    required this.currentVersion,
    required this.requiredVersion,
  });

  final String currentVersion;
  final String requiredVersion;

  /// Verified live: "Mealvana Endurance", Milkman Inc, bundle
  /// `com.milkman.mealvanaendurance`.
  static const String _iosAppStoreUrl =
      'https://apps.apple.com/app/id6751113738';

  /// Public TestFlight join link for the dev build (`Mealvana Endurance Dev`,
  /// App Store id 6756683509, bundle `com.milkman.mealvanaendurance.dev`) —
  /// the "Dev Pilot Users" external group.
  ///
  /// The dev app ships via TestFlight, never the App Store, so a tester stuck
  /// behind the min-version check has to be sent here. Sending them to the
  /// public listing would offer them the *prod* app, a different bundle id,
  /// which would not update the build they are stuck in.
  ///
  /// If this is ever emptied, the code below degrades to opening the TestFlight
  /// app itself rather than following a dead link — which is how this screen
  /// shipped a placeholder `id123456789` App Store id and a broken button.
  static const String _devTestFlightJoinUrl =
      'https://testflight.apple.com/join/9rVdtRfh';

  /// Opens the TestFlight app without deep-linking to a specific build. Used
  /// only when [_devTestFlightJoinUrl] has not been configured.
  static const String _testFlightAppUrl = 'itms-beta://';

  static const String _androidPackage = 'com.milkman.mealvanaendurance';
  static const String _webAppUrl = 'https://app.mealvana.io';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The BUILD flavor, not the runtime dev-mode toggle: which store the user
    // installed from is fixed at build time and cannot be changed by a setting.
    final isDevFlavor = ref.read(appConfigProvider).appEnvironment == 'dev';

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
              onPressed: () => _openStore(context, isDevFlavor: isDevFlavor),
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
        Icon(
          Icons.system_update,
          size: AppIconSizes.xxl + 16, // 80px
          color: AppColors.warning,
        ),

        const SizedBox(height: AppSpacing.xl),

        Text(
          'Update Required',
          style: AppTextStyles.pageTitle.copyWith(color: AppColors.textDark),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.md),

        Text(
          'Please update to version $requiredVersion or later to continue using Mealvana Endurance.',
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textDark),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.sm),

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

  /// The store URL for this platform and flavor.
  @visibleForTesting
  static String storeUrlFor({
    required bool isDevFlavor,
    required bool isWeb,
    required bool isIOS,
    required bool isAndroid,
  }) {
    if (isWeb) return _webAppUrl;

    if (isIOS) {
      if (!isDevFlavor) return _iosAppStoreUrl;
      return _devTestFlightJoinUrl.isNotEmpty
          ? _devTestFlightJoinUrl
          : _testFlightAppUrl;
    }

    if (isAndroid) {
      final package = isDevFlavor ? '$_androidPackage.dev' : _androidPackage;
      return 'https://play.google.com/store/apps/details?id=$package';
    }

    return _webAppUrl;
  }

  Future<void> _openStore(
    BuildContext context, {
    required bool isDevFlavor,
  }) async {
    final url = storeUrlFor(
      isDevFlavor: isDevFlavor,
      isWeb: kIsWeb,
      isIOS: !kIsWeb && Platform.isIOS,
      isAndroid: !kIsWeb && Platform.isAndroid,
    );

    // Deliberately NOT gated on canLaunchUrl. It is unreliable for https on
    // both platforms (see privacy_links.dart, which makes the same call), and
    // the old code silently did nothing when it returned false — on a screen
    // with `canPop: false`, which left the user with no way forward at all.
    // Try the launch, and if it genuinely fails, say so.
    try {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showFailure(context);
      }
    } catch (_) {
      if (context.mounted) _showFailure(context);
    }
  }

  void _showFailure(BuildContext context) {
    MealvanaSnackbar.showError(
      context,
      "Couldn't open the store. Please update Mealvana Endurance manually.",
    );
  }
}

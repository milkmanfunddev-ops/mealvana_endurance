import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/settings_controller.dart';
import 'debug_screen.dart';

/// Settings Screen - Kyle's Design System + Database Integration RESTORED
/// Main settings screen with full controller integration for data persistence
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Triple-tap debug feature
  int _tapCount = 0;
  DateTime? _lastTapTime;

  void _handleProfileTap() {
    final now = DateTime.now();

    // Reset counter if more than 2 seconds since last tap
    if (_lastTapTime != null && now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTapTime = now;

    debugPrint('🐛 Settings tap detected! Tap count: $_tapCount');

    if (_tapCount == 3) {
      _tapCount = 0; // Reset counter
      debugPrint('🎉 Triple tap detected! Opening debug screen...');

      // Navigate to debug screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DebugScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: settingsAsync.when(
        data: (state) => _buildContent(context, state),
        loading: () => _buildLoadingState(context),
        error: (error, stack) => _buildErrorState(context, error),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Settings',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.electrolyte,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            FontAwesomeIcons.circleExclamation,
            color: AppColors.dragonfruit,
            size: 64,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Error loading settings',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.dragonfruit,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error.toString(),
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic state) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // Account section (new for Phase 2)
          _buildAccountSection(context, state),

          const SizedBox(height: AppSpacing.lg),

          // Quick links section (removed label, added preferences link)
          _buildQuickLinksSection(context),

          const SizedBox(height: AppSpacing.xl),

          // Version number
          _buildVersionInfo(context),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final userId = settingsAsync.asData?.value.userId;

    return Center(
      child: Column(
        children: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Text(
                  'Version ${snapshot.data!.version} (${snapshot.data!.buildNumber})',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          if (userId != null) ...[
            const SizedBox(height: AppSpacing.xs),
            GestureDetector(
              onTap: () {
                // Copy user ID to clipboard
                Clipboard.setData(ClipboardData(text: userId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User ID copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Text(
                'User ID: $userId',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, dynamic state) {
    final isAnonymous = state.isAnonymous ?? true;
    final authProvider = state.authProvider ?? 'anonymous';
    final email = state.email;

    // Format provider name for display
    String providerName = authProvider;
    switch (authProvider) {
      case 'apple':
        providerName = 'Apple';
        break;
      case 'google':
        providerName = 'Google';
        break;
      case 'email':
        providerName = 'Email';
        break;
      default:
        providerName = 'Anonymous';
    }

    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.accountSectionTitle ?? 'Account',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          if (isAnonymous) ...[
            // Anonymous user - show "Create Account" CTA
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.user,
                  size: AppIconSizes.md,
                  color: AppColors.orange.withValues(alpha: 0.7),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.accountStatusAnonymous ?? 'Not signed in',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Create an account to sync your data across devices',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Create Account button
            SizedBox(
              width: double.infinity,
              child: KylePrimaryButton(
                text: state.createAccountButton ?? 'Create Account',
                onPressed: () {
                  final analytics = ref.read(appExternalDepsProvider);
                  analytics.analytics.track('settings_create_account_tapped');
                  context.push('/auth/post-onboarding');
                },
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Log In button
            SizedBox(
              width: double.infinity,
              child: KyleSecondaryButton(
                text: 'Log In',
                onPressed: () {
                  final analytics = ref.read(appExternalDepsProvider);
                  analytics.analytics.track('settings_login_tapped');
                  context.push('/auth/post-onboarding?mode=login');
                },
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Sign Out button for anonymous users
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  // Show warning dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out?'),
                      content: const Text(
                        'Your data is only saved on this device. '
                        'Create an account first to back up your data and sync across devices.\n\n'
                        'If you sign out without an account, you can still sign back in later to access your data on this device.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, false);
                            // Take them to create account instead
                            context.push('/auth/post-onboarding');
                          },
                          child: const Text('Create Account'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.dragonfruit,
                          ),
                          child: const Text('Sign Out Anyway'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    final analytics = ref.read(appExternalDepsProvider);
                    analytics.analytics.track('settings_anonymous_sign_out_tapped');

                    // Sign out of Supabase (clears anonymous session)
                    // Local data is preserved - user can sign back in later
                    await ref.read(settingsControllerProvider.notifier).signOut();

                    if (context.mounted) {
                      context.go('/welcome');
                    }
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ] else ...[
            // Authenticated user - show provider and sign out
            Row(
              children: [
                Icon(
                  authProvider == 'apple' ? FontAwesomeIcons.apple :
                  authProvider == 'google' ? FontAwesomeIcons.google :
                  FontAwesomeIcons.envelope,
                  size: AppIconSizes.md,
                  color: AppColors.electrolyte,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signed in with $providerName',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (email != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          email,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Sign Out button
            SizedBox(
              width: double.infinity,
              child: KyleSecondaryButton(
                text: state.signOutButton ?? 'Sign Out',
                onPressed: () async {
                  // Show confirmation dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out?'),
                      content: const Text(
                        'You\'ll continue using the app as a guest. Your preferences will be saved on this device. Sign in again to sync across devices.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );

                  // If user confirmed, proceed with sign out
                  if (confirmed == true && context.mounted) {
                    await ref.read(settingsControllerProvider.notifier).signOut();

                    // Navigate to welcome screen after logout
                    if (context.mounted) {
                      context.go('/welcome');
                    }
                  }
                },
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Delete Account button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  // Show confirmation dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Account?'),
                      content: const Text(
                        'This will permanently delete your account and all associated data. This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: AppColors.dragonfruit),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  // If user confirmed, proceed with delete
                  if (confirmed == true && context.mounted) {
                    await ref.read(settingsControllerProvider.notifier).deleteAccount();

                    // Navigate to welcome screen after account deletion
                    if (context.mounted) {
                      context.go('/welcome');
                    }
                  }
                },
                child: Text(
                  'Delete Account',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.dragonfruit,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildQuickLinksSection(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile & Preferences (with triple-tap gesture for debug)
          GestureDetector(
            onTap: _handleProfileTap,
            behavior: HitTestBehavior.opaque,
            child: _buildQuickLink(
              context: context,
              icon: FontAwesomeIcons.user,
              title: 'Profile & Preferences',
              subtitle: 'Edit your profile, units, and preferences',
              onTap: () {
                final analytics = ref.read(appExternalDepsProvider);
                analytics.analytics.track('settings_preferences_tapped');
                context.push('/settings/preferences');
              },
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Appearance
          _buildQuickLink(
            context: context,
            icon: FontAwesomeIcons.palette,
            title: 'Appearance',
            subtitle: 'Theme mode (light/dark/system)',
            onTap: () {
              // Show theme mode dialog
              _showThemeModeDialog(context);
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Food Preferences Hub (NEW 2-tier navigation)
          _buildQuickLink(
            context: context,
            icon: FontAwesomeIcons.utensils,
            title: 'Food Preferences',
            subtitle: 'Diet, allergies, and food choices',
            onTap: () {
              final analytics = ref.read(appExternalDepsProvider);
              analytics.analytics.track('settings_food_preferences_hub_tapped');
              context.push('/settings/food-preferences-hub');
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Sport Preferences Hub (NEW 2-tier navigation)
          _buildQuickLink(
            context: context,
            icon: FontAwesomeIcons.personRunning,
            title: 'Sport Preferences',
            subtitle: 'Running, cycling, and swimming',
            onTap: () {
              final analytics = ref.read(appExternalDepsProvider);
              analytics.analytics.track('settings_sport_preferences_hub_tapped');
              context.push('/settings/sport-preferences-hub');
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Help & Feedback
          _buildQuickLink(
            context: context,
            icon: FontAwesomeIcons.circleQuestion,
            title: 'Help & Feedback',
            subtitle: 'Get help and send feedback',
            onTap: () {
              final analytics = ref.read(appExternalDepsProvider);
              analytics.analytics.track('settings_help_tapped');
              context.push('/help');
            },
          ),
        ],
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context) {
    final themeModeAsync = ref.read(kyleThemeModeProvider);

    themeModeAsync.when(
      data: (currentMode) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Theme Mode'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: ThemeMode.values.map((mode) {
                return RadioListTile<ThemeMode>(
                  title: Text(_getThemeModeName(mode)),
                  value: mode,
                  groupValue: currentMode,
                  onChanged: (selected) {
                    if (selected != null) {
                      ref.read(kyleThemeModeProvider.notifier).setThemeMode(selected);
                      Navigator.of(context).pop();
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  Widget _buildQuickLink({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppIconSizes.controlIcon,
                color: AppColors.electrolyte,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              FontAwesomeIcons.chevronRight,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/analytics/analytics_excluded_pref.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/app_config.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
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
  // Triple-tap debug feature (Profile & Preferences row → DebugScreen)
  int _tapCount = 0;
  DateTime? _lastTapTime;

  // 7-tap reveal for "Developer / Tester" analytics exclusion section
  int _versionTapCount = 0;
  DateTime? _lastVersionTapTime;
  bool _showTesterSection = false;

  @override
  void initState() {
    super.initState();
    // If this device is already marked as excluded, auto-reveal the tester
    // section so the tester can see the current state and toggle it off if
    // needed — without requiring 7 taps every time they open Settings.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final excluded = ref.read(analyticsExcludedProvider);
      if (excluded && !_showTesterSection) {
        setState(() => _showTesterSection = true);
      }
    });
  }

  void _handleProfileTap() {
    final now = DateTime.now();

    // Reset counter if more than 2 seconds since last tap
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTapTime = now;

    debugPrint('🐛 Settings tap detected! Tap count: $_tapCount');

    if (_tapCount == 3) {
      _tapCount = 0; // Reset counter
      debugPrint('🎉 Triple tap detected! Opening debug screen...');

      // Navigate to debug screen
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const DebugScreen()));
    }
  }

  /// Counts taps on the version text. Seven taps within 3-second windows
  /// reveals the hidden "Developer / Tester" section.
  void _handleVersionTap() {
    final now = DateTime.now();
    if (_lastVersionTapTime != null &&
        now.difference(_lastVersionTapTime!) > const Duration(seconds: 3)) {
      _versionTapCount = 0;
    }
    _versionTapCount++;
    _lastVersionTapTime = now;

    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      if (!_showTesterSection) {
        setState(() => _showTesterSection = true);
      }
    }
  }

  /// Handles toggling the "Exclude this device from analytics" switch.
  ///
  /// Order of operations when ENABLING exclusion:
  ///   1. Call markInternal() on the live tracker (while analytics is still
  ///      active) to flag the Mixpanel profile for dashboard filtering.
  ///   2. Persist the exclusion pref — this causes analyticsTrackerProvider
  ///      to rebuild and return NoopAnalyticsTracker.
  ///
  /// When DISABLING exclusion:
  ///   1. Clear the pref so analyticsTrackerProvider returns
  ///      MixpanelAnalyticsTracker on the next app launch.
  Future<void> _onAnalyticsExcludedToggled(bool excluded) async {
    if (excluded) {
      // Mark the profile BEFORE suppressing — order matters.
      await ref.read(analyticsTrackerProvider).markInternal();
      await ref.read(analyticsExcludedProvider.notifier).setExcluded(true);
      if (mounted) {
        MealvanaSnackbar.showSuccess(
          context,
          'This device is excluded from analytics. Mixpanel profile flagged.',
        );
      }
    } else {
      await ref.read(analyticsExcludedProvider.notifier).setExcluded(false);
      if (mounted) {
        MealvanaSnackbar.showInfo(
          context,
          'Analytics re-enabled. Changes take full effect on next app launch.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return AdaptivePageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      contentWidth: AdaptiveContentWidth.standard,
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
      leading: IconButton(
        key: const ValueKey('settings.back_button'),
        tooltip: 'Back',
        // Guard against popping when there's nothing to pop (e.g. a rapid
        // double-tap where the first tap already popped this route) — that
        // throws GoError "There is nothing to pop" (Sentry MEALVANA-ENDURANCE-8Y).
        onPressed: () {
          if (context.canPop()) context.pop();
        },
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: Theme.of(context).colorScheme.onSurface,
          size: 20,
        ),
      ),
      title: Text(
        key: const ValueKey('settings.title'),
        'Settings',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.electrolyte),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FaIcon(
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
    return AdaptiveScrollableBody(
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

          // Version number — tap 7 times to reveal the tester section below.
          _buildVersionInfo(context),

          // Hidden "Developer / Tester" section: revealed after 7 taps on the
          // version text, OR automatically when analytics is already excluded
          // (so testers can easily toggle it off on repeat visits).
          if (_showTesterSection) _buildTesterSection(context),

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
          // Tapping this 7 times reveals the Developer / Tester section.
          GestureDetector(
            onTap: _handleVersionTap,
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    key: const ValueKey('settings.version_label'),
                    'Version ${snapshot.data!.version} (${snapshot.data!.buildNumber})',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          if (userId != null) ...[
            const SizedBox(height: AppSpacing.xs),
            GestureDetector(
              key: const ValueKey('settings.user_id_label'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // Copy user ID to clipboard
                Clipboard.setData(ClipboardData(text: userId));
                MealvanaSnackbar.showSuccess(
                  context,
                  'User ID copied to clipboard',
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'User ID: $userId',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Hidden "Developer / Tester" section.
  ///
  /// Revealed after the user taps the version text 7 times (or automatically
  /// when the exclusion pref is already active). Lets internal testers exclude
  /// their device from production Mixpanel analytics without needing to know
  /// their device ID.
  Widget _buildTesterSection(BuildContext context) {
    final isExcluded = ref.watch(analyticsExcludedProvider);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: BaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Developer / Tester',
              style: AppTextStyles.subtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'These settings are only visible to internal testers.',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              title: Text(
                'Exclude this device from analytics (testers)',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                isExcluded
                    ? 'No events are sent to Mixpanel from this device.'
                    : 'Analytics are active. Toggle to stop tracking on this device.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              value: isExcluded,
              onChanged: _onAnalyticsExcludedToggled,
              activeThumbColor: AppColors.electrolyte,
              contentPadding: EdgeInsets.zero,
            ),
            // Hidden paywall entry for purchase testing. Only present when the
            // AI-credits feature flag is on; keeps it out of the normal user UI.
            if (ref.watch(appConfigProvider).aiCreditsEnabled) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bolt, color: AppColors.electrolyte),
                title: Text(
                  'Buy AI Credits (tester)',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'Opens the credits paywall for purchase testing.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/buy-credits'),
              ),
            ],
          ],
        ),
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
            key: const ValueKey('settings.account_section'),
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
                FaIcon(
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
                        key: const ValueKey('settings.account_status'),
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
                key: const ValueKey('settings.create_account_button'),
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
                key: const ValueKey('settings.log_in_button'),
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
                key: const ValueKey('settings.sign_out_button'),
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
                          key: const ValueKey('signout_dialog.cancel_button'),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          key: const ValueKey(
                            'signout_dialog.create_account_button',
                          ),
                          onPressed: () {
                            Navigator.pop(context, false);
                            // Take them to create account instead
                            context.push('/auth/post-onboarding');
                          },
                          child: const Text('Create Account'),
                        ),
                        TextButton(
                          key: const ValueKey(
                            'signout_dialog.sign_out_anyway_button',
                          ),
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
                    analytics.analytics.track(
                      'settings_anonymous_sign_out_tapped',
                    );

                    // Sign out of Supabase (clears anonymous session)
                    // Local data is preserved - user can sign back in later
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .signOut();

                    if (context.mounted) {
                      context.go('/welcome');
                    }
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ] else ...[
            // Authenticated user - show provider and sign out
            Row(
              children: [
                Icon(
                  authProvider == 'apple'
                      ? FontAwesomeIcons.apple.data
                      : authProvider == 'google'
                      ? FontAwesomeIcons.google.data
                      : FontAwesomeIcons.envelope.data,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .signOut();

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
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.dragonfruit,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  // If user confirmed, proceed with delete
                  if (confirmed == true && context.mounted) {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .deleteAccount();

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
            excludeFromSemantics: true,
            child: _buildQuickLink(
              context: context,
              rowKey: const ValueKey('settings.profile_row'),
              icon: FontAwesomeIcons.user.data,
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
            rowKey: const ValueKey('settings.appearance_row'),
            icon: FontAwesomeIcons.palette.data,
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
            rowKey: const ValueKey('settings.food_prefs_row'),
            icon: FontAwesomeIcons.utensils.data,
            title: 'Diet, Allergies & Formulas',
            subtitle: 'Dietary preference, allergies, and nutrition formulas',
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
            rowKey: const ValueKey('settings.sport_prefs_row'),
            icon: FontAwesomeIcons.personRunning.data,
            title: 'Sport Preferences',
            subtitle: 'Running, cycling, and swimming',
            onTap: () {
              final analytics = ref.read(appExternalDepsProvider);
              analytics.analytics.track(
                'settings_sport_preferences_hub_tapped',
              );
              context.push('/settings/sport-preferences-hub');
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Body Composition - weight, height, body fat, training phase, lifestyle
          _buildQuickLink(
            context: context,
            rowKey: const ValueKey('settings.body_composition_row'),
            icon: FontAwesomeIcons.chartPie.data,
            title: 'Body Composition',
            subtitle: 'Weight, height, body fat, training phase, lifestyle',
            onTap: () {
              final analytics = ref.read(appExternalDepsProvider);
              analytics.analytics.track('settings_nutrition_profile_tapped');
              context.push('/settings/nutrition-profile');
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Nutrition Targets - Default macro target overrides
          _buildQuickLink(
            context: context,
            rowKey: const ValueKey('settings.nutrition_targets_row'),
            icon: FontAwesomeIcons.bullseye.data,
            title: 'Nutrition Targets',
            subtitle: 'Set default macro targets',
            onTap: () {
              final analytics = ref.read(appExternalDepsProvider);
              analytics.analytics.track('settings_nutrition_targets_tapped');
              context.push('/settings/nutrition-targets');
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Always available: connect, review status, or message coach.
          _buildQuickLink(
            context: context,
            rowKey: const ValueKey('settings.coach_connection_row'),
            icon: FontAwesomeIcons.userGroup.data,
            title: 'Coach Connection',
            subtitle: 'Connect with your coach or manage your connection',
            onTap: () {
              final analytics = ref.read(appExternalDepsProvider);
              analytics.analytics.track('settings_coach_connection_tapped');
              context.push('/settings/coach-connection');
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Connected Apps (Final Surge, TrainingPeaks, Garmin, V.O2 integrations)
          _buildQuickLink(
            context: context,
            rowKey: const ValueKey('settings.connected_apps_row'),
            icon: FontAwesomeIcons.link.data,
            title: 'Connected Apps',
            subtitle: 'Final Surge, TrainingPeaks, Garmin, V.O2',
            onTap: () {
              final analytics = ref.read(appExternalDepsProvider);
              analytics.analytics.track('settings_connected_apps_tapped');
              context.push('/settings/connected-apps');
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Help & Feedback
          _buildQuickLink(
            context: context,
            rowKey: const ValueKey('settings.help_row'),
            icon: FontAwesomeIcons.circleQuestion.data,
            title: 'Help & Feedback',
            subtitle: 'Get help and send feedback',
            onTap: () {
              final analytics = ref.read(appExternalDepsProvider);
              analytics.analytics.track('settings_help_tapped');
              context.push('/help');
            },
          ),

          // Coach Mode - hidden for 1.15.1 release (not ready yet)
          // const SizedBox(height: AppSpacing.sm),
          // _buildCoachModeLink(context),
        ],
      ),
    );
  }

  Widget _buildCoachModeLink(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final isCoach = settingsAsync.asData?.value.isCoach ?? false;

    if (kIsWeb) {
      // WEB: Coach registration and dashboard are web-only
      if (isCoach) {
        // User is a coach - show Coach Dashboard
        return _buildQuickLink(
          context: context,
          icon: FontAwesomeIcons.userTie.data,
          title: 'Coach Dashboard',
          subtitle: 'Manage your athletes',
          onTap: () {
            final analytics = ref.read(appExternalDepsProvider);
            analytics.analytics.track('settings_coach_dashboard_tapped');
            context.push('/coach');
          },
        );
      } else {
        // User is not a coach - show Apply to Coach option (web only)
        return _buildQuickLink(
          context: context,
          icon: FontAwesomeIcons.userPlus.data,
          title: 'Apply to Coach',
          subtitle: 'Register as a coach',
          onTap: () {
            final analytics = ref.read(appExternalDepsProvider);
            analytics.analytics.track('settings_apply_coach_tapped');
            context.push('/coach/apply');
          },
        );
      }
    } else {
      // MOBILE: Athletes can view their coaches
      return _buildQuickLink(
        context: context,
        icon: FontAwesomeIcons.userGroup.data,
        title: 'My Coaches',
        subtitle: 'View and chat with your coaches',
        onTap: () {
          final analytics = ref.read(appExternalDepsProvider);
          analytics.analytics.track('settings_my_coaches_tapped');
          context.push('/my-coaches');
        },
      );
    }
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
                final modeKey = switch (mode) {
                  ThemeMode.system => 'appearance.system_button',
                  ThemeMode.light => 'appearance.light_button',
                  ThemeMode.dark => 'appearance.dark_button',
                };
                return RadioListTile<ThemeMode>(
                  key: ValueKey(modeKey),
                  title: Text(_getThemeModeName(mode)),
                  value: mode,
                  groupValue: currentMode,
                  onChanged: (selected) {
                    if (selected != null) {
                      ref
                          .read(kyleThemeModeProvider.notifier)
                          .setThemeMode(selected);
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
    Key? rowKey,
  }) {
    return InkWell(
      key: rowKey,
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

            FaIcon(
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

// ARCHIVED 2026-09-21 (paywall ticket 08, mp-459 / mp-417).
// From lib/features/settings/presentation/screens/settings_screen.dart,
// `_buildAccountSection`: the branch shown to an anonymous profile
// ("Not signed in", Create Account, Log In, and the sign-out dialog for a
// user with no account). The app no longer makes anonymous users; an install
// left anonymous from before the paywall is sent to the account screen
// instead (mp-455, ticket 09). Not compiled: this folder is excluded from
// analysis. The `state.accountStatusAnonymous` / `state.createAccountButton`
// labels it read were removed from SettingsState with it.

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
          ],

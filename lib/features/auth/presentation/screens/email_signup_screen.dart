import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../content/application/content_service.dart';
import '../../../app_startup/application/app_startup_service.dart';
import '../providers/post_onboarding_auth_controller.dart';
import '../../application/email_auth_service.dart';
import '../../domain/auth_exceptions.dart';

/// Email Signup Screen
/// Allows users to create an account with email and password
/// Links email to existing anonymous account (preserves data)
class EmailSignupScreen extends ConsumerStatefulWidget {
  const EmailSignupScreen({super.key});

  @override
  ConsumerState<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends ConsumerState<EmailSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasTrackedScreenView = false;

  @override
  void initState() {
    super.initState();
    // Analytics tracking moved to didChangeDependencies for safety
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Track screen view only once
    if (!_hasTrackedScreenView) {
      _hasTrackedScreenView = true;
      ref.read(appExternalDepsProvider).analytics.track('screen_viewed', properties: {
        'screen_name': 'Email Signup',
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Get trimmed values
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Additional validation as safety check
    if (email.isEmpty) {
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Please enter your email address',
        );
      }
      return;
    }

    if (password.isEmpty) {
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Please enter your password',
        );
      }
      return;
    }

    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final contentService = ref.read(contentServiceProvider);
    final supabase = ref.read(appExternalDepsProvider).supabaseClient;
    final appStartupService = ref.read(appStartupServiceProvider);

    // IMPORTANT: During onboarding signup, we ALWAYS create a NEW user.
    // If there's an existing session (from a previous attempt or old login),
    // sign out first to start fresh.
    // Mark this as an onboarding sign-out to preserve cached onboarding data.
    if (supabase.auth.currentUser != null) {
      appStartupService.markOnboardingSignOut();
      await supabase.auth.signOut();
    }

    // Always use signUp during onboarding - creates a fresh new user
    final bool success = await controller.signUpWithEmail(
      email: email,
      password: password,
    );

    if (success && mounted) {
      // Show success message
      MealvanaSnackbar.showSuccess(
        context,
        contentService.getValue(
          'auth.post_onboarding.success_linked',
          defaultValue: 'Account created successfully!',
        ),
      );

      // Return to post-onboarding auth screen which will navigate to main
      context.pop(true);
    } else if (!success && mounted) {
      // Check if the error is because the account already exists
      final state = ref.read(postOnboardingAuthControllerProvider);
      if (state.hasError && state.error is AccountAlreadyExistsException) {
        final exception = state.error as AccountAlreadyExistsException;
        await _showAccountExistsDialog(context, email, exception.email);
        return;
      }

      // Show generic error message
      MealvanaSnackbar.showError(
        context,
        contentService.getValue(
          'auth.post_onboarding.error_email_failed',
          defaultValue: 'Account creation failed. Please try again.',
        ),
      );
    }
  }

  Future<void> _showAccountExistsDialog(BuildContext context, String attemptedEmail, String? existingEmail) async {
    final contentService = ref.read(contentServiceProvider);
    final displayEmail = existingEmail ?? attemptedEmail;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(contentService.getValue('auth.error.account_exists_title', defaultValue: 'Account Already Exists')),
        content: Text(
          contentService.getValue(
            'auth.error.email_already_registered',
            defaultValue: 'An account with $displayEmail already exists. Would you like to sign in instead?'
          )
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cancel
            },
            child: Text(contentService.getValue('common.cancel', defaultValue: 'Cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to email login screen
              context.push('/auth/email-login');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.electrolyte),
            child: Text(contentService.getValue('auth.error.sign_in_instead', defaultValue: 'Sign In')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(postOnboardingAuthControllerProvider);
    final contentService = ref.watch(contentServiceProvider);
    final emailAuthService = ref.watch(emailAuthServiceProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPaddingHorizontal,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // Title
                Text(
                  contentService.getValue(
                    'auth.email_signup.title',
                    defaultValue: 'Sign Up with Email',
                  ),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.sm),

                // Subtitle
                Text(
                  contentService.getValue(
                    'auth.email_signup.subtitle',
                    defaultValue: 'Create your account to get started',
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: contentService.getValue(
                      'auth.email_signup.email_label',
                      defaultValue: 'Email Address',
                    ),
                    hintText: contentService.getValue(
                      'auth.email_signup.email_hint',
                      defaultValue: 'you@example.com',
                    ),
                    prefixIcon: Icon(
                      FontAwesomeIcons.envelope,
                      size: AppIconSizes.controlIcon,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputRadius,
                    ),
                  ),
                  style: AppTextStyles.bodyMedium,
                  validator: (value) {
                    final trimmedValue = value?.trim() ?? '';
                    return emailAuthService.validateEmail(trimmedValue);
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: contentService.getValue(
                      'auth.email_signup.password_label',
                      defaultValue: 'Password',
                    ),
                    hintText: contentService.getValue(
                      'auth.email_signup.password_hint',
                      defaultValue: 'At least 8 characters',
                    ),
                    prefixIcon: Icon(
                      FontAwesomeIcons.lock,
                      size: AppIconSizes.controlIcon,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                          ? FontAwesomeIcons.eye
                          : FontAwesomeIcons.eyeSlash,
                        size: AppIconSizes.controlIcon,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputRadius,
                    ),
                  ),
                  style: AppTextStyles.bodyMedium,
                  validator: (value) {
                    return emailAuthService.validatePassword(value ?? '');
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: contentService.getValue(
                      'auth.email_signup.password_confirm_label',
                      defaultValue: 'Confirm Password',
                    ),
                    hintText: contentService.getValue(
                      'auth.email_signup.password_confirm_hint',
                      defaultValue: 'Re-enter your password',
                    ),
                    prefixIcon: Icon(
                      FontAwesomeIcons.lock,
                      size: AppIconSizes.controlIcon,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                          ? FontAwesomeIcons.eye
                          : FontAwesomeIcons.eyeSlash,
                        size: AppIconSizes.controlIcon,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputRadius,
                    ),
                  ),
                  style: AppTextStyles.bodyMedium,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return contentService.getValue(
                        'auth.email_signup.password_mismatch',
                        defaultValue: 'Passwords do not match',
                      );
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Email verification notice
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.electrolyte.withOpacity(0.1),
                    borderRadius: AppRadius.cardRadius,
                    border: Border.all(
                      color: AppColors.electrolyte.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        FontAwesomeIcons.circleInfo,
                        size: AppIconSizes.sm,
                        color: AppColors.electrolyte,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contentService.getValue(
                                'auth.email_signup.email_verification_notice',
                                defaultValue: 'We\'ll send a confirmation email to verify your address',
                              ),
                              style: AppTextStyles.smallLabel.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              contentService.getValue(
                                'auth.email_signup.email_verification_optional',
                                defaultValue: '(Optional - you can use the app immediately)',
                              ),
                              style: AppTextStyles.smallLabel.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // Create account button
                KylePrimaryButton(
                  text: contentService.getValue(
                    asyncState.isLoading
                      ? 'auth.email_signup.creating_button'
                      : 'auth.email_signup.create_button',
                    defaultValue: asyncState.isLoading
                      ? 'Creating Account...'
                      : 'Create Account',
                  ),
                  onPressed: asyncState.isLoading ? null : _handleCreateAccount,
                ),

                const SizedBox(height: AppSpacing.md),

                // Back button
                KyleSecondaryButton(
                  text: contentService.getValue(
                    'auth.email_signup.back_button',
                    defaultValue: 'Back',
                  ),
                  onPressed: asyncState.isLoading ? null : () => context.pop(),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Custom back button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                FontAwesomeIcons.arrowLeft,
                size: AppIconSizes.controlIcon,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}

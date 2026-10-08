import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/auth/auth_listener_service.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../providers/post_onboarding_auth_controller.dart';
import '../../application/email_auth_service.dart';
import '../../domain/auth_exceptions.dart';
import '../../domain/pending_signup.dart';
import 'verify_email_screen.dart';

/// What the email-signup route pops besides `true` (account created and
/// verified) and null (left): the athlete logged in to an existing account
/// instead, from Verify's hint or the account-exists dialog (ticket 57,
/// 48-003). The screen beneath finishes it as a login, not a signup.
enum EmailSignupResult { loggedIn }

/// Email Signup Screen
/// Allows users to create an account with email and password
/// Links email to existing anonymous account (preserves data)
///
/// [resume] is a signup quit on Verify your email (ticket 42, 30-007): the
/// form fills its address and reopens Verify for the code already sent.
class EmailSignupScreen extends ConsumerStatefulWidget {
  const EmailSignupScreen({super.key, this.resume});

  final PendingSignup? resume;

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

  /// Seconds until Create Account may be tapped again after GoTrue's 429
  /// (30-008); 0 when it may.
  int _createIn = 0;
  Timer? _createTimer;

  @override
  void initState() {
    super.initState();
    // Analytics tracking moved to didChangeDependencies for safety
    final resume = widget.resume;
    if (resume != null) {
      _emailController.text = resume.email;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_reopenVerify(resume));
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Track screen view only once
    if (!_hasTrackedScreenView) {
      _hasTrackedScreenView = true;
      ref
          .read(appExternalDepsProvider)
          .analytics
          .track('screen_viewed', properties: {'screen_name': 'Email Signup'});
    }
  }

  @override
  void dispose() {
    _createTimer?.cancel();
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
        MealvanaSnackbar.showError(context, 'Please enter your email address');
      }
      return;
    }

    if (password.isEmpty) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Please enter your password');
      }
      return;
    }

    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final contentService = ref.read(contentServiceProvider);
    final supabase = ref.read(appExternalDepsProvider).supabaseClient;
    final authListenerService = ref.read(authListenerServiceProvider);

    // Two genuinely different flows share this form:
    //
    // 1. UPGRADE — there is already an anonymous Supabase session. Its uid IS
    //    `public.users.id`, and (since anonymous data is synced) that row and
    //    everything keyed to it exists in Supabase. Signing out and calling
    //    signUp() would mint a NEW uid and orphan all of it, so link the email
    //    onto the existing session instead and keep the uid.
    //
    // 2. FRESH SIGNUP — no session at all. Nothing to preserve; signUp().
    //
    // A non-anonymous session means a real account is already signed in (stale
    // login / retry): sign out and treat it as a fresh signup.
    final currentUser = supabase.auth.currentUser;
    final isAnonymousUpgrade = currentUser != null && currentUser.isAnonymous;

    if (currentUser != null && !isAnonymousUpgrade) {
      // Mark this as an onboarding sign-out to preserve cached onboarding data.
      authListenerService.markOnboardingSignOut();
      await supabase.auth.signOut();
    }

    bool success = isAnonymousUpgrade
        ? await controller.linkEmailAccount(email: email, password: password)
        : await controller.signUpWithEmail(email: email, password: password);

    // Email confirmation is on: the address is attached but not yet proven, so
    // the upgrade/signup is incomplete. Collect the code first — everything
    // downstream (onboarding data migration, every RLS-protected write) needs
    // a settled, authenticated session.
    if (!success && mounted) {
      final state = ref.read(postOnboardingAuthControllerProvider);
      if (state.error case final EmailVerificationRequiredException pending) {
        final exit = await _openVerify(
          email: email,
          // A fresh signup's user, so leaving without a code can discard
          // it (121-003); the upgrade path keeps its uid.
          pendingUserId: isAnonymousUpgrade ? null : pending.userId,
          // GoTrue models "attach an email to an existing user" as an
          // email change, so the upgrade code is not a signup code.
          otpType: isAnonymousUpgrade ? OtpType.emailChange : OtpType.signup,
          // Deferred on the upgrade path only: GoTrue rejects a password
          // on an anonymous user whose email is still unconfirmed.
          pendingPassword: isAnonymousUpgrade ? password : null,
        );
        if (exit == VerifyEmailExit.logIn) {
          await _logInInstead(email);
          return;
        }
        if (exit != VerifyEmailExit.verified) {
          // User backed out to change address — leave them on the form. The
          // anonymous account is untouched and still fully usable.
          return;
        }
        success = true;
      }
    }

    if (success && mounted) {
      _finishCreated();
    } else if (!success && mounted) {
      final state = ref.read(postOnboardingAuthControllerProvider);
      // GoTrue's gap between two emails to one address (30-008): a wait,
      // not a failure. The button counts it down; no snackbar.
      if (state.error case final ResendRateLimitedException wait) {
        _startCreateCooldown(wait.retryAfterSeconds);
        return;
      }

      // Check if the error is because the account already exists
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

  /// Verify your email for a code that went out; says which way it was left
  /// (null for a system back).
  Future<VerifyEmailExit?> _openVerify({
    required String email,
    required OtpType otpType,
    String? pendingUserId,
    String? pendingPassword,
    DateTime? codeSentAt,
  }) {
    return Navigator.of(context).push<VerifyEmailExit>(
      MaterialPageRoute(
        builder: (_) => VerifyEmailScreen(
          email: email,
          pendingUserId: pendingUserId,
          otpType: otpType,
          pendingPassword: pendingPassword,
          codeSentAt: codeSentAt,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// The account exists and is verified: back to the post-onboarding screen,
  /// which saves the answers and goes on.
  void _finishCreated() {
    final contentService = ref.read(contentServiceProvider);
    MealvanaSnackbar.showSuccess(
      context,
      contentService.getValue(
        'auth.post_onboarding.success_linked',
        defaultValue: 'Account created successfully!',
      ),
    );

    // Return to post-onboarding auth screen which will navigate to main
    context.pop(true);
  }

  /// Log In for [email], opened from here so its result comes back to this
  /// screen (ticket 57, 48-003): a login hands [EmailSignupResult.loggedIn]
  /// to the screen beneath, which finishes it as a login. Log In left
  /// without signing in: stay on the form.
  ///
  /// This screen gone meanwhile (a system back while Log In is open): the
  /// result is dropped; the athlete is signed in on whatever screen is left,
  /// as a login with no parent always was.
  Future<void> _logInInstead(String? email) async {
    if (!mounted) return;
    final loggedIn = await context.push<bool>(
      '/auth/email-login',
      extra: email == null ? null : {'email': email},
    );
    if (loggedIn == true && mounted) {
      context.pop(EmailSignupResult.loggedIn);
    }
  }

  /// A signup quit on Verify your email (ticket 42): reopen Verify for the
  /// code the record names, with the upgrade path's deferred password from
  /// secure storage. Used: on as after a fresh code. Left: stay on the form.
  Future<void> _reopenVerify(PendingSignup record) async {
    final password = await ref
        .read(postOnboardingAuthControllerProvider.notifier)
        .resumedPassword(record);
    if (!mounted) return;
    final exit = await _openVerify(
      email: record.email,
      otpType: record.isEmailChange ? OtpType.emailChange : OtpType.signup,
      pendingUserId: record.isEmailChange ? null : record.pendingUserId,
      pendingPassword: password,
      codeSentAt: record.codeSentAt.toLocal(),
    );
    if (!mounted) return;
    switch (exit) {
      case VerifyEmailExit.verified:
        _finishCreated();
      case VerifyEmailExit.logIn:
        await _logInInstead(record.email);
      case VerifyEmailExit.differentEmail || null:
        break;
    }
  }

  /// Create Account waits [seconds] (30-008). Across a rebuild the timer
  /// lives in this state; a new countdown replaces a running one.
  void _startCreateCooldown(int seconds) {
    _createTimer?.cancel();
    setState(() => _createIn = seconds);
    if (seconds <= 0) return;
    _createTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _createIn--);
      if (_createIn <= 0) t.cancel();
    });
  }

  Future<void> _showAccountExistsDialog(
    BuildContext context,
    String attemptedEmail,
    String? existingEmail,
  ) async {
    final contentService = ref.read(contentServiceProvider);
    final displayEmail = existingEmail ?? attemptedEmail;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          contentService.getValue(
            'auth.error.account_exists_title',
            defaultValue: 'Account Already Exists',
          ),
        ),
        content: Text(
          contentService.getValue(
            'auth.error.email_already_registered',
            defaultValue:
                'An account with $displayEmail already exists. Would you like to sign in instead?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cancel
            },
            child: Text(
              contentService.getValue('common.cancel', defaultValue: 'Cancel'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Log In from here, so a login reaches the screen beneath
              // (ticket 57).
              unawaited(_logInInstead(null));
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.electrolyte),
            child: Text(
              contentService.getValue(
                'auth.error.sign_in_instead',
                defaultValue: 'Sign In',
              ),
            ),
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

    return AdaptivePageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      contentWidth: AdaptiveContentWidth.narrow,
      body: AdaptiveScrollableBody(
        padding: AppSpacing.screenPaddingHorizontal,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                key: const ValueKey('signup_email.title'),
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
                key: const ValueKey('signup_email.subtitle'),
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
                key: const ValueKey('signup_email.email_field'),
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
                    FontAwesomeIcons.envelope.data,
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
                key: const ValueKey('signup_email.password_field'),
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
                    FontAwesomeIcons.lock.data,
                    size: AppIconSizes.controlIcon,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: IconButton(
                    key: const ValueKey(
                      'signup_email.password_visibility_button',
                    ),
                    // Named as Log In's is (118-005, 119-005).
                    tooltip: _obscurePassword
                        ? contentService.getValue(
                            ContentKeys.authShowPassword,
                            defaultValue: 'Show password',
                          )
                        : contentService.getValue(
                            ContentKeys.authHidePassword,
                            defaultValue: 'Hide password',
                          ),
                    icon: Icon(
                      _obscurePassword
                          ? FontAwesomeIcons.eye.data
                          : FontAwesomeIcons.eyeSlash.data,
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
                key: const ValueKey('signup_email.confirm_password_field'),
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
                    FontAwesomeIcons.lock.data,
                    size: AppIconSizes.controlIcon,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: IconButton(
                    key: const ValueKey(
                      'signup_email.confirm_password_visibility_button',
                    ),
                    tooltip: _obscureConfirmPassword
                        ? contentService.getValue(
                            ContentKeys.authShowPassword,
                            defaultValue: 'Show password',
                          )
                        : contentService.getValue(
                            ContentKeys.authHidePassword,
                            defaultValue: 'Hide password',
                          ),
                    icon: Icon(
                      _obscureConfirmPassword
                          ? FontAwesomeIcons.eye.data
                          : FontAwesomeIcons.eyeSlash.data,
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

              const SizedBox(height: AppSpacing.xxxl),

              // Create account button
              KylePrimaryButton(
                key: const ValueKey('signup_email.create_account_button'),
                text: _createIn > 0
                    ? ContentKeys.format(
                        contentService.getValue(
                          ContentKeys.emailSignupCreateIn,
                        ),
                        {'n': _createIn},
                      )
                    : contentService.getValue(
                        asyncState.isLoading
                            ? 'auth.email_signup.creating_button'
                            : 'auth.email_signup.create_button',
                        defaultValue: asyncState.isLoading
                            ? 'Creating Account...'
                            : 'Create Account',
                      ),
                onPressed: asyncState.isLoading || _createIn > 0
                    ? null
                    : _handleCreateAccount,
              ),

              const SizedBox(height: AppSpacing.md),

              // Back button
              KyleSecondaryButton(
                key: const ValueKey('signup_email.back_button'),
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
          CustomAppBarBackButton(
            key: const ValueKey('signup_email.back_button_appbar'),
            onPressed: () => context.pop(),
            margin: EdgeInsets.zero,
            iconColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../../coach_mode/application/coach_service.dart';
import '../../../onboarding/presentation/providers/onboarding_controller.dart';
import '../providers/post_onboarding_auth_controller.dart';
import '../../application/email_auth_service.dart';
import '../../domain/auth_exceptions.dart';
import '../../../subscription/application/pro_gate.dart';
import '../../application/email_auth_handoff.dart';
import 'verify_email_screen.dart';

/// Email Login Screen
/// Allows users to sign in with email and password
///
/// A failed Log In says why in one line under the form, which stays until
/// the next edit (testing-wave 125-002, 125-007): the email or password is
/// wrong, there is no connection, or it failed. An address that never entered
/// its signup code is not a failure: the code is resent and Verify your
/// email opens for it (124-001).
class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key, this.initialEmail});

  /// An address to start with: the one Verify your email's "Log in" offered
  /// (124-002).
  final String? initialEmail;

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  /// The line under the form after a failed Log In; cleared by the next edit.
  String? _errorLine;

  /// True from the Log In tap until this screen is left. The controller's
  /// state stops loading as soon as the session lands, but the screen still
  /// has work before it navigates (the controller's trailing analytics, the
  /// pop, or settling the app gate); reading busy from the controller alone
  /// showed the form enabled for about a second (Finding 12-003). Cleared
  /// only when the login fails, never on success.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track('screen_viewed', properties: {'screen_name': 'Email Login'});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_submitting) return;
    setState(() => _submitting = true);

    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final contentService = ref.read(contentServiceProvider);

    final success = await controller.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      // If we can pop, return result to the parent (e.g. post-onboarding auth screen)
      // If we can't pop (e.g. arrived via context.go() from password reset), go to main directly
      if (context.canPop()) {
        // The Log In screen beneath listens for this; the pop result is not
        // reliable (see emailAuthHandoffProvider).
        ref
            .read(emailAuthHandoffProvider.notifier)
            .succeeded(EmailAuthKind.login);
        context.pop(true);
      } else {
        // On web, check if user is a coach and redirect to coach portal
        if (kIsWeb) {
          try {
            final isCoach = await ref
                .read(coachServiceProvider)
                .isCurrentUserCoach();
            if (!mounted) return;
            if (isCoach) {
              context.go('/coach-portal');
              return;
            }
          } catch (_) {
            // Fall through to /main
          }
        }
        if (!mounted) return;
        try {
          await ref.read(appGateProvider.notifier).settle();
        } catch (_) {
          // Never leave the form stuck busy on a gate failure.
          if (mounted) setState(() => _submitting = false);
          rethrow;
        }
        if (!mounted) return;
        context.go('/main');
      }
    } else if (!success && mounted) {
      setState(() => _submitting = false);
      final error = ref.read(postOnboardingAuthControllerProvider).error;
      if (error is EmailNotConfirmedException) {
        await _finishVerifying(error.email);
        return;
      }
      // One line under the form, until the next edit (125-002, 125-007).
      setState(() {
        _errorLine = switch (error) {
          WrongCredentialsException() => contentService.getValue(
            ContentKeys.loginErrorWrongCredentials,
          ),
          NoConnectionException() => contentService.getValue(
            ContentKeys.loginErrorNoConnection,
          ),
          _ => contentService.getValue(ContentKeys.loginErrorFailed),
        };
      });
    }
  }

  /// The account exists but never entered its signup code (124-001): resend
  /// it (best effort; the server may say the last one is recent) and open
  /// Verify your email. A verified code continues the way a signup does when
  /// the onboarding answers are still in memory; after a relaunch they are
  /// not (the draft lives in memory only), and the account continues as a
  /// login, which the startup flow routes to onboarding if it has no profile.
  Future<void> _finishVerifying(String email) async {
    final emailAuth = ref.read(emailAuthServiceProvider.notifier);
    try {
      await emailAuth.resendVerificationCode(email: email);
    } catch (_) {
      // A recent code may still be in the inbox; the screen can Resend.
    }
    if (!mounted) return;
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VerifyEmailScreen(email: email),
        fullscreenDialog: true,
      ),
    );
    if (verified != true || !mounted) return;
    final hasDraft = ref
        .read(onboardingControllerProvider.notifier)
        .hasCompletedProfileDraft;
    ref
        .read(emailAuthHandoffProvider.notifier)
        .succeeded(hasDraft ? EmailAuthKind.signup : EmailAuthKind.login);
    if (context.canPop()) {
      context.pop(true);
    } else {
      await ref.read(appGateProvider.notifier).settle();
      if (mounted) context.go('/main');
    }
  }

  void _clearErrorLine() {
    if (_errorLine != null) setState(() => _errorLine = null);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(postOnboardingAuthControllerProvider);
    final isBusy = asyncState.isLoading || _submitting;
    final contentService = ref.watch(contentServiceProvider);
    final emailAuthService = ref.watch(emailAuthServiceProvider.notifier);

    return AdaptivePageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, isLoading: isBusy),
      contentWidth: AdaptiveContentWidth.narrow,
      body: Stack(
        children: [
          // Main content
          AdaptiveScrollableBody(
            padding: AppSpacing.screenPaddingHorizontal,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),

                  // Title
                  Text(
                    key: const ValueKey('login.title'),
                    contentService.getValue(
                      'auth.login.title',
                      defaultValue: 'Log In',
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
                    key: const ValueKey('login.subtitle'),
                    contentService.getValue(
                      'auth.login.subtitle',
                      defaultValue: 'Welcome back',
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Email field
                  TextFormField(
                    key: const ValueKey('login.email_field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
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
                    onChanged: (_) => _clearErrorLine(),
                    validator: (value) {
                      return emailAuthService.validateEmail(value ?? '');
                    },
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Password field
                  TextFormField(
                    key: const ValueKey('login.password_field'),
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
                        defaultValue: 'Enter your password',
                      ),
                      prefixIcon: Icon(
                        FontAwesomeIcons.lock.data,
                        size: AppIconSizes.controlIcon,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      suffixIcon: IconButton(
                        key: const ValueKey('login.password_visibility_button'),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
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
                    onChanged: (_) => _clearErrorLine(),
                    validator: (value) {
                      if ((value ?? '').isEmpty) return 'Password is required';
                      return null;
                    },
                  ),

                  // Why the last Log In failed (125-002, 125-007).
                  if (_errorLine != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _errorLine!,
                      key: const ValueKey('login.error_line'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.md),

                  // Forgot Password link
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      key: const ValueKey('login.forgot_password_button'),
                      behavior: HitTestBehavior.opaque,
                      onTap: isBusy
                          ? null
                          : () => context.push('/auth/forgot-password'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 4,
                        ),
                        child: Text(
                          contentService.getValue(
                            'auth.login.forgot_password',
                            defaultValue: 'Forgot Password?',
                          ),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.electrolyte,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Login button
                  KylePrimaryButton(
                    key: const ValueKey('login.log_in_button'),
                    text: contentService.getValue(
                      isBusy
                          ? 'auth.login.logging_in_button'
                          : 'auth.login.button',
                      defaultValue: isBusy ? 'Logging in...' : 'Log In',
                    ),
                    onPressed: isBusy ? null : _handleLogin,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Back button
                  KyleSecondaryButton(
                    key: const ValueKey('login.back_button'),
                    text: contentService.getValue(
                      'auth.email_signup.back_button',
                      defaultValue: 'Back',
                    ),
                    onPressed: isBusy ? null : () => context.pop(),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (isBusy)
            Container(
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: 0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.electrolyte,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Text(
                    //   contentService.getValue(
                    //     'auth.login.syncing_message',
                    //     defaultValue: 'Signing in and syncing your data...',
                    //   ),
                    //   style: AppTextStyles.bodyMedium.copyWith(
                    //     color: Theme.of(context).colorScheme.onSurface,
                    //   ),
                    //   textAlign: TextAlign.center,
                    // ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    bool isLoading = false,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Custom back button (disabled during loading)
          Opacity(
            opacity: isLoading ? 0.5 : 1.0,
            child: CustomAppBarBackButton(
              key: const ValueKey('login.back_button_appbar'),
              onPressed: () => context.pop(),
              enabled: !isLoading,
              margin: EdgeInsets.zero,
              iconColor: Theme.of(context).colorScheme.onSurface,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

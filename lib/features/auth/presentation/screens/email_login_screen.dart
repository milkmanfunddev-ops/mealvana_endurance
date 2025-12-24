import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../content/application/content_service.dart';
import '../providers/post_onboarding_auth_controller.dart';
import '../../application/email_auth_service.dart';

/// Email Login Screen
/// Allows users to sign in with email and password
class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    ref.read(appExternalDepsProvider).analytics.track('screen_viewed', properties: {
      'screen_name': 'Email Login',
    });
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

    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final contentService = ref.read(contentServiceProvider);

    final success = await controller.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            contentService.getValue(
              'auth.login.success',
              defaultValue: 'Logged in successfully!',
            ),
          ),
          backgroundColor: AppColors.electrolyte,
        ),
      );

      // Return to post-onboarding auth screen which will navigate to main
      context.pop(true);
    } else if (!success && mounted) {
      // Error message shown by controller via snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            contentService.getValue(
              'auth.login.error_failed',
              defaultValue: 'Login failed. Please check your credentials.',
            ),
          ),
          backgroundColor: AppColors.dragonfruit,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(postOnboardingAuthControllerProvider);
    final contentService = ref.watch(contentServiceProvider);
    final emailAuthService = ref.watch(emailAuthServiceProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, isLoading: asyncState.isLoading),
      body: Stack(
        children: [
          // Main content
          SafeArea(
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
                    return emailAuthService.validateEmail(value ?? '');
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
                      defaultValue: 'Enter your password',
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
                    if ((value ?? '').isEmpty) return 'Password is required';
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // Login button
                KylePrimaryButton(
                  text: contentService.getValue(
                    asyncState.isLoading
                      ? 'auth.login.logging_in_button'
                      : 'auth.login.button',
                    defaultValue: asyncState.isLoading
                      ? 'Logging in...'
                      : 'Log In',
                  ),
                  onPressed: asyncState.isLoading ? null : _handleLogin,
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

          // Loading overlay
          if (asyncState.isLoading)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
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

  PreferredSizeWidget _buildAppBar(BuildContext context, {bool isLoading = false}) {
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
            child: Container(
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
                onPressed: isLoading ? null : () => context.pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


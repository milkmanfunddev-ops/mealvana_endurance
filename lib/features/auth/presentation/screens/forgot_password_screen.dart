import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../application/email_auth_service.dart';
import '../providers/password_recovery_controller.dart';

/// Forgot Password Screen
/// User enters their email to receive a 6-digit OTP reset code
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final controller = ref.read(passwordRecoveryControllerProvider.notifier);

    final success = await controller.sendResetCode(email);

    if (success && mounted) {
      MealvanaSnackbar.showSuccess(
        context,
        'Check your email for a reset code',
      );
      context.push('/auth/verify-reset-code', extra: {'email': email});
    } else if (!success && mounted) {
      MealvanaSnackbar.showError(
        context,
        'Failed to send reset code. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(passwordRecoveryControllerProvider);
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
                    'auth.forgot_password.title',
                    defaultValue: 'Forgot Password',
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
                    'auth.forgot_password.subtitle',
                    defaultValue:
                        'Enter your email and we\'ll send you a reset code',
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
                  textInputAction: TextInputAction.done,
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
                    return emailAuthService.validateEmail(value?.trim() ?? '');
                  },
                  onFieldSubmitted: (_) => _handleSendCode(),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // Send code button
                KylePrimaryButton(
                  text: asyncState.isLoading ? 'Sending...' : 'Send Reset Code',
                  onPressed: asyncState.isLoading ? null : _handleSendCode,
                ),

                const SizedBox(height: AppSpacing.md),

                // Back button
                KyleSecondaryButton(
                  text: 'Back',
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
          CustomAppBarBackButton(
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

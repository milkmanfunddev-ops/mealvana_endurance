import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../application/email_auth_service.dart';
import '../providers/password_recovery_controller.dart';

/// Set New Password Screen
/// User sets a new password after verifying the OTP code
class SetNewPasswordScreen extends ConsumerStatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  ConsumerState<SetNewPasswordScreen> createState() =>
      _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends ConsumerState<SetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(passwordRecoveryControllerProvider.notifier);

    final success = await controller.setNewPassword(_passwordController.text);

    if (success && mounted) {
      MealvanaSnackbar.showSuccess(context, 'Password reset successfully');
      // Pop all recovery screens back to login
      context.go('/auth/email-login');
    } else if (!success && mounted) {
      MealvanaSnackbar.showError(
        context,
        'Failed to reset password. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(passwordRecoveryControllerProvider);
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
                contentService.getValue(
                  'auth.set_password.title',
                  defaultValue: 'Set New Password',
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
                  'auth.set_password.subtitle',
                  defaultValue: 'Choose a strong password for your account',
                ),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // New password field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: contentService.getValue(
                    'auth.set_password.password_label',
                    defaultValue: 'New Password',
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
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: contentService.getValue(
                    'auth.set_password.confirm_label',
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
                onFieldSubmitted: (_) => _handleSetPassword(),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Set password button
              KylePrimaryButton(
                text: asyncState.isLoading ? 'Resetting...' : 'Reset Password',
                onPressed: asyncState.isLoading ? null : _handleSetPassword,
              ),

              const SizedBox(height: AppSpacing.md),

              // Cancel button
              KyleSecondaryButton(
                text: 'Cancel',
                onPressed: asyncState.isLoading
                    ? null
                    : () => context.go('/auth/email-login'),
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

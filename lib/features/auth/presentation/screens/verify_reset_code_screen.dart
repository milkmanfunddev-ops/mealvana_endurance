import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../providers/password_recovery_controller.dart';

/// Verify Reset Code Screen
/// User enters the 6-digit OTP code received by email
class VerifyResetCodeScreen extends ConsumerStatefulWidget {
  const VerifyResetCodeScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyResetCodeScreen> createState() =>
      _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState
    extends ConsumerState<VerifyResetCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text.trim();
    final controller =
        ref.read(passwordRecoveryControllerProvider.notifier);

    final success =
        await controller.verifyResetCode(widget.email, code);

    if (success && mounted) {
      context.push('/auth/set-new-password');
    } else if (!success && mounted) {
      MealvanaSnackbar.showError(
        context,
        'Invalid or expired code. Please try again.',
      );
    }
  }

  Future<void> _handleResendCode() async {
    final controller =
        ref.read(passwordRecoveryControllerProvider.notifier);

    final success = await controller.sendResetCode(widget.email);

    if (success && mounted) {
      MealvanaSnackbar.showSuccess(
        context,
        'A new code has been sent to your email',
      );
    } else if (!success && mounted) {
      MealvanaSnackbar.showError(
        context,
        'Failed to resend code. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(passwordRecoveryControllerProvider);
    final contentService = ref.watch(contentServiceProvider);

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
                    'auth.verify_code.title',
                    defaultValue: 'Enter Reset Code',
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
                    'auth.verify_code.subtitle',
                    defaultValue:
                        'Enter the 6-digit code sent to ${widget.email}',
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // Code input field
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sectionTitle.copyWith(
                    letterSpacing: 8,
                    fontSize: 24,
                  ),
                  decoration: InputDecoration(
                    labelText: contentService.getValue(
                      'auth.verify_code.code_label',
                      defaultValue: 'Reset Code',
                    ),
                    hintText: '000000',
                    counterText: '',
                    prefixIcon: Icon(
                      FontAwesomeIcons.key,
                      size: AppIconSizes.controlIcon,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputRadius,
                    ),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Code is required';
                    if (trimmed.length != 6) return 'Code must be 6 digits';
                    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
                      return 'Code must be numbers only';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleVerifyCode(),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Resend code link
                GestureDetector(
                  onTap: asyncState.isLoading ? null : _handleResendCode,
                  child: Text(
                    contentService.getValue(
                      'auth.verify_code.resend',
                      defaultValue: 'Didn\'t receive a code? Resend',
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.electrolyte,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // Verify button
                KylePrimaryButton(
                  text: asyncState.isLoading ? 'Verifying...' : 'Verify Code',
                  onPressed:
                      asyncState.isLoading ? null : _handleVerifyCode,
                ),

                const SizedBox(height: AppSpacing.md),

                // Back button
                KyleSecondaryButton(
                  text: 'Back',
                  onPressed:
                      asyncState.isLoading ? null : () => context.pop(),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.1),
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

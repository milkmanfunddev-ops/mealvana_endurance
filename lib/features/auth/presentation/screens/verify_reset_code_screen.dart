import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../domain/auth_exceptions.dart';
import '../providers/password_recovery_controller.dart';

/// Verify Reset Code Screen
/// User enters the 6-digit OTP code received by email
///
/// Resend waits as long as the server does (testing-wave 124-004): one email
/// per address per 60 s (`smtp_max_frequency`), so the link counts down from
/// the code Forgot Password just sent, and a 429 counts down the wait GoTrue
/// names instead of saying the resend failed.
class VerifyResetCodeScreen extends ConsumerStatefulWidget {
  const VerifyResetCodeScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyResetCodeScreen> createState() =>
      _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends ConsumerState<VerifyResetCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  /// Seconds until Resend becomes available again; a code was just sent.
  int _resendIn = ResendRateLimitedException.serverGapSeconds;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCooldown([
    int seconds = ResendRateLimitedException.serverGapSeconds,
  ]) {
    _resendTimer?.cancel();
    setState(() => _resendIn = seconds);
    if (seconds <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _handleVerifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text.trim();
    final controller = ref.read(passwordRecoveryControllerProvider.notifier);

    final success = await controller.verifyResetCode(widget.email, code);

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
    if (_resendIn > 0) return;
    final controller = ref.read(passwordRecoveryControllerProvider.notifier);
    final content = ref.read(contentServiceProvider);

    final success = await controller.sendResetCode(widget.email);
    if (!mounted) return;

    if (success) {
      _startResendCooldown();
      MealvanaSnackbar.showSuccess(
        context,
        content.getValue(ContentKeys.verifyCodeResent),
      );
    } else if (controller.lastRetryAfterSeconds case final wait?) {
      // The server's gap has not passed (124-004): count it down, say
      // nothing else.
      _startResendCooldown(wait);
    } else {
      MealvanaSnackbar.showError(
        context,
        content.getValue(ContentKeys.verifyCodeResendFailed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(passwordRecoveryControllerProvider);
    final contentService = ref.watch(contentServiceProvider);

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
                // iOS and Android surface the emailed code above the keyboard.
                autofillHints: const [AutofillHints.oneTimeCode],
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
                    FontAwesomeIcons.key.data,
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
                // The sixth digit submits, typed, pasted or autofilled
                // (32-007): no reach for Verify Code.
                onChanged: (value) {
                  if (value.trim().length == 6 && !asyncState.isLoading) {
                    _handleVerifyCode();
                  }
                },
                onFieldSubmitted: (_) => _handleVerifyCode(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Resend code link, disabled while the server would refuse.
              GestureDetector(
                key: const ValueKey('auth.reset_resend'),
                onTap: asyncState.isLoading || _resendIn > 0
                    ? null
                    : _handleResendCode,
                child: Text(
                  _resendIn > 0
                      ? ContentKeys.format(
                          contentService.getValue(
                            ContentKeys.verifyCodeResendIn,
                          ),
                          {'n': _resendIn},
                        )
                      : contentService.getValue(
                          'auth.verify_code.resend',
                          defaultValue: 'Didn\'t receive a code? Resend',
                        ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _resendIn > 0
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : AppColors.electrolyte,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Verify button
              KylePrimaryButton(
                text: asyncState.isLoading ? 'Verifying...' : 'Verify Code',
                onPressed: asyncState.isLoading ? null : _handleVerifyCode,
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

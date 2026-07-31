import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../application/email_auth_service.dart';
import '../../domain/auth_exceptions.dart';

/// Collects the 6-digit signup verification code.
///
/// Reached when [EmailAuthService.signUpWithEmail] or
/// [EmailAuthService.linkEmailAccount] throws
/// [EmailVerificationRequiredException] — the address exists on the account but
/// Supabase withheld/withholds the upgrade until it is proven. Popping `true`
/// means the pending flow completed and the caller may continue.
///
/// The screen deliberately cannot be dismissed by the back gesture: leaving
/// here strands a created-but-unverified account with no way back to this
/// step. "Use a different email" is the explicit escape hatch.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.otpType = OtpType.signup,
    this.pendingPassword,
  });

  final String email;

  /// [OtpType.signup] for a brand-new account, [OtpType.emailChange] when an
  /// anonymous account is being upgraded in place (uid preserved).
  final OtpType otpType;

  /// Upgrade path only. GoTrue refuses to set a password while the address is
  /// still unconfirmed, so it is carried here and applied once the code is
  /// accepted. Null on the signup path, where the password is already set.
  final String? pendingPassword;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _codeCtrl = TextEditingController();
  bool _verifying = false;
  String? _error;

  /// Seconds until Resend becomes available again. Starts non-zero because a
  /// code was just sent by the signup itself.
  int _resendIn = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      await ref
          .read(emailAuthServiceProvider.notifier)
          .verifyEmailOtp(
            email: widget.email,
            token: _codeCtrl.text,
            type: widget.otpType,
            pendingPassword: widget.pendingPassword,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on InvalidVerificationCodeException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'Could not verify that code. Please try again.';
      });
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref
          .read(emailAuthServiceProvider.notifier)
          .resendVerificationCode(email: widget.email, type: widget.otpType);
      if (!mounted) return;
      _startResendCooldown();
      MealvanaSnackbar.showSuccess(context, 'New code sent to ${widget.email}');
    } on InvalidVerificationCodeException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    final canVerify = _codeCtrl.text.trim().length == 6 && !_verifying;

    return PopScope(
      // Backing out would strand an unverified account with no route back.
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            content.getValue(
              'auth.verify_email.title',
              defaultValue: 'Verify your email',
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPaddingHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 48,
                  color: AppColors.orange,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  content.getValue(
                    'auth.verify_email.body',
                    defaultValue: 'We sent a 6-digit code to',
                  ),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  key: const ValueKey('auth.verify_code_field'),
                  controller: _codeCtrl,
                  autofocus: true,
                  enabled: !_verifying,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  // iOS surfaces the emailed code above the keyboard.
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.dataNumberLarge.copyWith(
                    color: onSurface,
                    letterSpacing: 10,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => canVerify ? _verify() : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                KylePrimaryButton(
                  key: const ValueKey('auth.verify_submit'),
                  text: content.getValue(
                    'auth.verify_email.cta',
                    defaultValue: 'Verify',
                  ),
                  isLoading: _verifying,
                  onPressed: canVerify ? _verify : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  key: const ValueKey('auth.verify_resend'),
                  onPressed: _resendIn > 0 || _verifying ? null : _resend,
                  child: Text(
                    _resendIn > 0
                        ? 'Resend code in ${_resendIn}s'
                        : 'Resend code',
                  ),
                ),
                TextButton(
                  onPressed: _verifying
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(
                    content.getValue(
                      'auth.verify_email.change_email',
                      defaultValue: 'Use a different email',
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

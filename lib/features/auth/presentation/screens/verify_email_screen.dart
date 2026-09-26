import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
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
/// step. "Use a different email" is the explicit escape hatch; on a fresh
/// signup it also asks the server to delete the abandoned login
/// (testing-wave 121-003).
///
/// When the address already belongs to a confirmed account, GoTrue answers
/// the signup with a decoy user and sends nothing, so this screen can never
/// succeed. It always carries the hint "No code? This address may already
/// have an account" with Log in, and never says whether the account exists
/// (124-002, Lee 2026-09-26).
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.otpType = OtpType.signup,
    this.pendingPassword,
    this.pendingUserId,
  });

  final String email;

  /// The auth user a fresh signup created, for `discard-signup` when the
  /// athlete leaves without a code (121-003). Null on the upgrade path and
  /// when the code was reached from Log In (124-001), where the account is
  /// theirs to keep.
  final String? pendingUserId;

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

  /// Whether a Resend went out from this screen: a refused code after that
  /// most likely came from the earlier email (121-002).
  bool _resent = false;

  /// Seconds until Resend becomes available again. Starts at the server's
  /// own gap between two emails (60 s, `smtp_max_frequency`) because a code
  /// was just sent by the signup itself; a shorter countdown let an enabled
  /// Resend hit a 429 (121-001).
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
    _codeCtrl.dispose();
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

  /// A fresh signup the athlete is walking away from leaves no unconfirmed
  /// login behind (121-003). Fire-and-forget: the screen does not wait.
  void _discardAbandonedSignup() {
    final userId = widget.pendingUserId;
    if (userId == null || widget.otpType != OtpType.signup) return;
    unawaited(
      ref
          .read(emailAuthServiceProvider.notifier)
          .discardSignup(userId: userId, email: widget.email),
    );
  }

  void _useDifferentEmail() {
    _discardAbandonedSignup();
    Navigator.of(context).pop(false);
  }

  /// The hint's Log in (124-002): the address may already be an account, so
  /// Log In opens with it filled in. The abandoned signup, if this was one,
  /// is discarded like "Use a different email".
  void _logIn() {
    final router = GoRouter.of(context);
    _discardAbandonedSignup();
    Navigator.of(context).pop(false);
    router.push('/auth/email-login', extra: {'email': widget.email});
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
      final content = ref.read(contentServiceProvider);
      setState(() {
        _verifying = false;
        // After a Resend, GoTrue's one refusal most likely means the code
        // from the earlier email (121-002): point at the newest one, never
        // at Resend, which would send a third.
        _error = _resent && e.isWrongOrExpired
            ? content.getValue(ContentKeys.verifyEmailCodeSuperseded)
            : e.message;
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
    final content = ref.read(contentServiceProvider);
    try {
      await ref
          .read(emailAuthServiceProvider.notifier)
          .resendVerificationCode(email: widget.email, type: widget.otpType);
      if (!mounted) return;
      _resent = true;
      _startResendCooldown();
      MealvanaSnackbar.showSuccess(
        context,
        ContentKeys.format(content.getValue(ContentKeys.verifyEmailResent), {
          'email': widget.email,
        }),
      );
    } on ResendRateLimitedException catch (e) {
      // The server's gap has not passed (121-001): count down what it asked
      // for, and say nothing else.
      if (!mounted) return;
      _startResendCooldown(e.retryAfterSeconds);
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
                  onChanged: (value) {
                    setState(() => _error = null);
                    // The sixth digit submits, typed, pasted or autofilled
                    // (32-007): no reach for Verify.
                    if (value.trim().length == 6 && !_verifying) _verify();
                  },
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
                        ? ContentKeys.format(
                            content.getValue(ContentKeys.verifyEmailResendIn),
                            {'n': _resendIn},
                          )
                        : content.getValue(ContentKeys.verifyEmailResend),
                  ),
                ),
                TextButton(
                  key: const ValueKey('auth.verify_change_email'),
                  onPressed: _verifying ? null : _useDifferentEmail,
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
                const SizedBox(height: AppSpacing.lg),
                // Always shown, never a verdict on the account (124-002).
                Text(
                  content.getValue(ContentKeys.verifyEmailMaybeAccountHint),
                  key: const ValueKey('auth.verify_maybe_account_hint'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: onSurface.withValues(alpha: 0.7),
                  ),
                ),
                TextButton(
                  key: const ValueKey('auth.verify_log_in'),
                  onPressed: _verifying ? null : _logIn,
                  child: Text(content.getValue(ContentKeys.verifyEmailLogIn)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

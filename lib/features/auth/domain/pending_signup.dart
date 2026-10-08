/// A signup whose emailed code has not been entered yet (testing-wave
/// develop-2026-10 ticket 42, 30-007).
///
/// `PostOnboardingAuthController` writes it when GoTrue answers Create
/// Account with "code sent", `EmailAuthService` moves it on a Resend and
/// clears it when the code is used or the signup is abandoned, and
/// `AppStartupService.pendingSignupAtLaunch` reads it once at launch so a
/// relaunch reopens Verify your email instead of Welcome. The screens never
/// write it.
///
/// It carries the onboarding answers ([draft], the `OnboardingDraft` JSON)
/// so a resumed signup completes through the same save as an unbroken one.
/// It never carries the password: the upgrade path's deferred password lives
/// in secure storage (`PendingSignupStore`).
library;

class PendingSignup {
  const PendingSignup({
    required this.email,
    required this.otpType,
    required this.codeSentAt,
    this.pendingUserId,
    this.anonymousUserId,
    this.draft = const {},
  });

  /// GoTrue's `OtpType.signup`: a brand-new account (no session at send).
  static const otpSignup = 'signup';

  /// GoTrue's `OtpType.emailChange`: an anonymous account being upgraded in
  /// place (uid preserved).
  static const otpEmailChange = 'emailChange';

  final String email;

  /// [otpSignup] or [otpEmailChange].
  final String otpType;

  /// When the code being waited on was sent, in UTC.
  final DateTime codeSentAt;

  /// The plain path's new auth user, for `discard-signup` (121-003).
  final String? pendingUserId;

  /// The upgrade path's anonymous uid: the code can only complete the
  /// upgrade of this session.
  final String? anonymousUserId;

  /// `OnboardingDraft.toJson()` at the time the code went out. Empty when
  /// the signup came from Settings, where onboarding finished long ago.
  final Map<String, dynamic> draft;

  bool get isEmailChange => otpType == otpEmailChange;

  PendingSignup copyWith({DateTime? codeSentAt}) => PendingSignup(
    email: email,
    otpType: otpType,
    codeSentAt: (codeSentAt ?? this.codeSentAt).toUtc(),
    pendingUserId: pendingUserId,
    anonymousUserId: anonymousUserId,
    draft: draft,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'email': email,
    'otp_type': otpType,
    'code_sent_at': codeSentAt.toUtc().toIso8601String(),
    'pending_user_id': pendingUserId,
    'anonymous_user_id': anonymousUserId,
    'draft': draft,
  };

  /// The record [json] describes, or null when any field is missing or
  /// malformed. Never throws: an unreadable record is cleared at launch,
  /// not crashed on.
  static PendingSignup? fromJson(Object? json) {
    try {
      if (json is! Map) return null;
      final email = json['email'];
      final otpType = json['otp_type'];
      final sentAt = json['code_sent_at'];
      final pendingUserId = json['pending_user_id'];
      final anonymousUserId = json['anonymous_user_id'];
      final draft = json['draft'];
      if (email is! String || email.trim().isEmpty) return null;
      if (otpType != otpSignup && otpType != otpEmailChange) return null;
      if (sentAt is! String) return null;
      final codeSentAt = DateTime.tryParse(sentAt);
      if (codeSentAt == null) return null;
      if (pendingUserId != null && pendingUserId is! String) return null;
      if (anonymousUserId != null && anonymousUserId is! String) return null;
      // The upgrade's code is bound to one anonymous session: without its
      // uid the launch cannot tell whether that session survived.
      if (otpType == otpEmailChange && anonymousUserId == null) return null;
      if (draft != null && draft is! Map) return null;
      return PendingSignup(
        email: email,
        otpType: otpType as String,
        codeSentAt: codeSentAt.toUtc(),
        pendingUserId: pendingUserId as String?,
        anonymousUserId: anonymousUserId as String?,
        draft: draft == null
            ? const {}
            : Map<String, dynamic>.from(draft as Map),
      );
    } catch (_) {
      return null;
    }
  }
}

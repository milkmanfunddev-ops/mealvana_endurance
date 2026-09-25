import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/kyle_design/materials/glass_sheet.dart';
import '../../../../shared/widgets/kyle_design/sheets/kyle_sheet_header.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../application/code_entry_controller.dart';
import '../../domain/code_redemption.dart';

/// Redeem code, from the paywall's ⋯ menu (mp-494) and the Subscription
/// screen (mp-495): opens our own Code entry on the glass sheet, never the
/// App Store's offer-code sheet (mp-458).
///
/// What a Code did is said once the sheet closes. It is said through the
/// root navigator's context, captured before the Code is sent: a coach's own
/// Code or a giveaway opens the gate, and the router may replace the paywall
/// (and the sheet with it) before the answer is back.
///
/// [messageClearance] is how much of the screen's bottom the message must
/// stay above, asked for when the message is said: the paywall's plans and
/// Continue (11-005). Nothing is kept clear without it.
Future<void> openRedeemCode(
  BuildContext context,
  WidgetRef ref, {
  double Function()? messageClearance,
}) async {
  ref.read(codeEntryControllerProvider.notifier).reset();
  await showGlassSheet<void>(
    context,
    builder: (_) => RedeemCodeSheet(
      host: Navigator.of(context, rootNavigator: true).context,
      messageClearance: messageClearance,
    ),
  );
}

/// The words for what [redeemed] did.
String redeemedMessage(ContentService content, CodeRedeemed redeemed) {
  final key = switch (redeemed.kind) {
    RedeemedKind.coach => ContentKeys.redeemCodeSuccessCoach,
    RedeemedKind.giveaway => ContentKeys.redeemCodeSuccessGiveaway,
    RedeemedKind.paired => ContentKeys.redeemCodeSuccessPaired,
    RedeemedKind.attributed => ContentKeys.redeemCodeSuccessAttributed,
  };
  return ContentKeys.format(content.getValue(key), {'days': redeemed.proDays});
}

/// The words for why a Code was refused, or why no answer came back; null
/// while there is nothing to say.
String? redeemProblem(
  ContentService content,
  AsyncValue<CodeRedemption?> state,
) {
  if (state.isLoading) return null;
  final error = state.error;
  if (error != null) {
    return content.getValue(
      error is CodeRedeemFailure &&
              error.kind == CodeRedeemFailureKind.signInRequired
          ? ContentKeys.redeemCodeFailedSignIn
          : ContentKeys.redeemCodeFailedUnavailable,
    );
  }
  final value = state.value;
  if (value is! CodeRefused) return null;
  return switch (value.reason) {
    CodeRefusal.notFound => content.getValue(
      ContentKeys.redeemCodeRefusedNotFound,
    ),
    CodeRefusal.notYetValid => content.getValue(
      ContentKeys.redeemCodeRefusedNotYetValid,
    ),
    CodeRefusal.expired => content.getValue(
      ContentKeys.redeemCodeRefusedExpired,
    ),
    CodeRefusal.used => content.getValue(ContentKeys.redeemCodeRefusedUsed),
    CodeRefusal.alreadyRedeemed => content.getValue(
      ContentKeys.redeemCodeRefusedAlreadyRedeemed,
    ),
    CodeRefusal.ownCode => content.getValue(
      ContentKeys.redeemCodeRefusedOwnCode,
    ),
    CodeRefusal.alreadyPaired => content.getValue(
      ContentKeys.redeemCodeRefusedAlreadyPaired,
    ),
    CodeRefusal.tooLong => content.getValue(
      ContentKeys.redeemCodeRefusedTooLong,
    ),
    CodeRefusal.other =>
      value.serverMessage ??
          content.getValue(ContentKeys.redeemCodeRefusedOther),
  };
}

/// The Code entry: one field and Redeem. A refusal or a failure is said
/// under the field and the sheet stays open for another try; a Code that did
/// something closes it.
class RedeemCodeSheet extends ConsumerStatefulWidget {
  const RedeemCodeSheet({super.key, required this.host, this.messageClearance});

  /// Where the success is said: outlives the sheet and the screen under it.
  final BuildContext host;

  /// The bottom space the success message keeps clear (see [openRedeemCode]).
  final double Function()? messageClearance;

  /// The longest Code there is: `codes_code_format` in the codes migration
  /// and `MAX_CODE_LENGTH` in redeem-code both say 32 (11-004).
  static const maxCodeLength = 32;

  static const fieldKey = ValueKey('redeem_code.field');
  static const submitKey = ValueKey('redeem_code.submit');
  static const problemKey = ValueKey('redeem_code.problem');

  @override
  ConsumerState<RedeemCodeSheet> createState() => _RedeemCodeSheetState();
}

class _RedeemCodeSheetState extends ConsumerState<RedeemCodeSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty) return;
    if (ref.read(codeEntryControllerProvider).isLoading) return;
    final content = ref.read(contentServiceProvider);
    final host = widget.host;
    final result = await ref
        .read(codeEntryControllerProvider.notifier)
        .redeem(_code.text);
    if (result is! CodeRedeemed) return;
    if (host.mounted) {
      MealvanaSnackbar.showSuccess(
        host,
        redeemedMessage(content, result),
        bottomClearance: widget.messageClearance?.call() ?? 0,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentServiceProvider);
    final state = ref.watch(codeEntryControllerProvider);
    final problem = redeemProblem(content, state);
    String t(String key) => content.getValue(key);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        key: const ValueKey('redeem_code.sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KyleSheetHeader(
            title: t(ContentKeys.redeemCodeTitle),
            onClose: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            t(ContentKeys.redeemCodeBody),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.cream.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          KyleInputField(
            key: RedeemCodeSheet.fieldKey,
            controller: _code,
            hintText: t(ContentKeys.redeemCodeHint),
            autofocus: true,
            enabled: !state.isLoading,
            keyboardType: TextInputType.visiblePassword,
            inputFormatters: [
              LengthLimitingTextInputFormatter(RedeemCodeSheet.maxCodeLength),
              _UpperCase(),
            ],
            onChanged: (_) {
              // A new Code: the last one's refusal no longer applies.
              if (problem != null) {
                ref.read(codeEntryControllerProvider.notifier).reset();
              }
              setState(() {});
            },
            onSubmitted: (_) => _submit(),
          ),
          if (problem != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              key: RedeemCodeSheet.problemKey,
              problem,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.dragonfruit,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          KylePrimaryButton(
            key: RedeemCodeSheet.submitKey,
            text: t(ContentKeys.redeemCodeSubmit),
            isLoading: state.isLoading,
            onPressed: state.isLoading || _code.text.trim().isEmpty
                ? null
                : _submit,
          ),
        ],
      ),
    );
  }
}

/// Codes are printed upper-case; typing them so saves a doubt.
class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

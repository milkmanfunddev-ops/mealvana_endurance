import 'package:flutter/material.dart';
import '../../../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';

/// Generate Plan button for the New Activity screen
///
/// Fixed position button at the bottom of the screen that triggers
/// macro generation and navigation to the adjust macros screen.
///
/// Features:
/// - Primary button styling via KylePrimaryButton
/// - Loading state support
/// - Horizontal padding (40px) and vertical padding
/// - Disabled state when generating
class NewActivityGenerateButton extends StatelessWidget {
  const NewActivityGenerateButton({
    super.key,
    required this.isGenerating,
    required this.onPressed,
  });

  final bool isGenerating;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 40,
        vertical: AppSpacing.lg,
      ),
      child: KylePrimaryButton(
        text: 'Generate Plan',
        onPressed: isGenerating ? null : onPressed,
        isLoading: isGenerating,
      ),
    );
  }
}

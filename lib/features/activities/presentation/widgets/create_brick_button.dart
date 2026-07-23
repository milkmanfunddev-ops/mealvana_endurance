import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';

/// Create Brick button widget
///
/// Orange outline button with chain link icon.
/// Appears when 2+ activities of different sports exist on the same day.
/// Tapping enters selection mode to choose activities for brick creation.
class CreateBrickButton extends ConsumerWidget {
  const CreateBrickButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Create brick workout button',
      button: true,
      child: SizedBox(
        height: 44, // Ensure minimum touch target height
        child: KyleSecondaryButtonSmall(
          text: "Create Brick",
          icon: FontAwesomeIcons.link.data,
          onPressed: onPressed,
          variant: SecondaryButtonVariant.orange,
        ),
      ),
    );
  }
}

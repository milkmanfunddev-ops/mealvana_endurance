import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// Tone of a [VanaTag] — the prototype's `.v-tag` / `--orange` / `--pink`.
enum VanaTagTone { electrolyte, orange, pink }

/// Small pill label used across the catalog ("Yours", "No recipe", "Batch"):
/// a tinted fill with a matching hairline border and the tone's own text
/// colour. Mirrors `.v-tag` in the prototype.
class VanaTag extends StatelessWidget {
  const VanaTag({
    super.key,
    required this.label,
    this.tone = VanaTagTone.electrolyte,
  });

  final String label;
  final VanaTagTone tone;

  Color get _color => switch (tone) {
    VanaTagTone.electrolyte => AppColors.electrolyte,
    VanaTagTone.orange => AppColors.orange,
    VanaTagTone.pink => AppColors.dragonfruit,
  };

  Color get _text => switch (tone) {
    VanaTagTone.electrolyte => AppColors.electrolyteDark,
    VanaTagTone.orange => AppColors.orange,
    VanaTagTone.pink => AppColors.dragonfruitLight,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.45), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _text,
          height: 1.2,
        ),
      ),
    );
  }
}

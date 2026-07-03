import 'package:flutter/material.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Dialog for saving an activity's nutrition plan as a reusable template
class SaveTemplateDialog extends StatefulWidget {
  const SaveTemplateDialog({
    super.key,
    required this.defaultName,
    required this.activityTypeDisplay,
  });

  final String defaultName;
  final String activityTypeDisplay;

  /// Show the dialog and return the template name, or null if cancelled
  static Future<String?> show(
    BuildContext context, {
    required String defaultName,
    required String activityTypeDisplay,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => SaveTemplateDialog(
        defaultName: defaultName,
        activityTypeDisplay: activityTypeDisplay,
      ),
    );
  }

  @override
  State<SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends State<SaveTemplateDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
    _nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.defaultName.length,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Save as Routine',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Save your food selections as a reusable ${widget.activityTypeDisplay.toLowerCase()} routine.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 50,
            decoration: InputDecoration(
              labelText: 'Routine Name',
              hintText: 'e.g., Saturday Long Run',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              counterText: '',
            ),
            onSubmitted: (_) => _onSave(),
          ),
        ],
      ),
      actions: [
        KyleSecondaryButton(
          text: 'Cancel',
          isFullWidth: false,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        const SizedBox(width: AppSpacing.sm),
        KylePrimaryButton(
          text: 'Save Routine',
          isFullWidth: false,
          onPressed: _onSave,
        ),
      ],
    );
  }

  void _onSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }
}

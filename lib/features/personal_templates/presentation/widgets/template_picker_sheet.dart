import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/personal_template.dart';
import 'template_list_item.dart';

/// Result returned from the template picker
class TemplatePickerResult {
  const TemplatePickerResult({
    required this.template,
    required this.scaleToFit,
  });

  final PersonalTemplate template;
  final bool scaleToFit;
}

/// Bottom sheet for selecting a personal template to apply
class TemplatePickerSheet extends StatefulWidget {
  const TemplatePickerSheet({super.key, required this.templates});

  final List<PersonalTemplate> templates;

  /// Show the picker and return the selected template + scale preference
  static Future<TemplatePickerResult?> show(
    BuildContext context, {
    required List<PersonalTemplate> templates,
  }) {
    return showModalBottomSheet<TemplatePickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TemplatePickerSheet(templates: templates),
    );
  }

  @override
  State<TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<TemplatePickerSheet> {
  bool _scaleToFit = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Routines',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Scale toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scale to fit this activity',
                  style: theme.textTheme.bodyMedium,
                ),
                KyleSwitch(
                  value: _scaleToFit,
                  onChanged: (value) => setState(() => _scaleToFit = value),
                  activeTrackColor: AppColors.electrolyte,
                ),
              ],
            ),
          ),

          const Divider(),

          // Template list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              itemCount: widget.templates.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final template = widget.templates[index];
                return TemplateListItem(
                  template: template,
                  onTap: () {
                    Navigator.of(context).pop(
                      TemplatePickerResult(
                        template: template,
                        scaleToFit: _scaleToFit,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Manage templates link
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop(); // Close sheet
                context.push('/settings/templates');
              },
              child: Text(
                'Manage routines \u{2192}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.electrolyte,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

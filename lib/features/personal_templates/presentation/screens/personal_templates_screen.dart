import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../providers/personal_templates_controller.dart';
import '../widgets/template_list_item.dart';
import '../../domain/personal_template.dart';

/// Management screen for personal nutrition plan templates
/// Accessed from Settings > My Templates
class PersonalTemplatesScreen extends ConsumerWidget {
  const PersonalTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(personalTemplatesControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(),
        title: Text(
          'My Templates',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: templatesAsync.when(
        data: (templates) => _buildContent(context, ref, templates),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Error loading templates: $error')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<PersonalTemplate> templates,
  ) {
    if (templates.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final template = templates[index];
              return TemplateListItem(
                template: template,
                showOverflowMenu: true,
                onMorePressed: () =>
                    _showTemplateActions(context, ref, template),
              );
            },
          ),
        ),
        // Template count footer
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            '${templates.length} of $kMaxTemplateCount templates used',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_outline,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Templates Yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Save your first template from any activity with a nutrition plan',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateActions(
    BuildContext context,
    WidgetRef ref,
    PersonalTemplate template,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showRenameDialog(context, ref, template);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.dragonfruit),
              title: Text(
                'Delete',
                style: TextStyle(color: AppColors.dragonfruit),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showDeleteConfirmation(context, ref, template);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    PersonalTemplate template,
  ) async {
    final controller = TextEditingController(text: template.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Template'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: InputDecoration(
            labelText: 'Template Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(dialogContext).pop(name);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.electrolyte,
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newName != null && newName != template.name) {
      await ref
          .read(personalTemplatesControllerProvider.notifier)
          .renameTemplate(template.id, newName);
    }
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    PersonalTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text(
          'Are you sure you want to delete "${template.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.dragonfruit),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(personalTemplatesControllerProvider.notifier)
          .deleteTemplate(template.id);
      if (context.mounted) {
        MealvanaSnackbar.showSuccess(context, 'Template deleted');
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../providers/macro_targets_controller.dart';
import '../../../domain/macro_targets.dart' as domain;
import '../../utils/unit_formatter.dart';

/// Edit Macros Dialog
/// Allows user to manually edit all macro targets
class EditMacrosDialogWidget extends ConsumerStatefulWidget {
  const EditMacrosDialogWidget({
    super.key,
    required this.macros,
    this.activityId,
    this.useMetric = false,
  });

  final domain.MacroTargets macros;
  final String? activityId;
  final bool useMetric;

  @override
  ConsumerState<EditMacrosDialogWidget> createState() =>
      _EditMacrosDialogWidgetState();
}

class _EditMacrosDialogWidgetState
    extends ConsumerState<EditMacrosDialogWidget> {
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'preCarbs': TextEditingController(
        text: widget.macros.preRun.carbsG.round().toString(),
      ),
      'duringCarbs': TextEditingController(
        text: widget.macros.duringRun.carbTotalG.round().toString(),
      ),
      'postCarbs': TextEditingController(
        text: widget.macros.postRun.carbsG.round().toString(),
      ),
      'preProtein': TextEditingController(
        text: widget.macros.preRun.proteinG.round().toString(),
      ),
      'duringProtein': TextEditingController(text: '0'),
      'postProtein': TextEditingController(
        text: widget.macros.postRun.proteinG.round().toString(),
      ),
      'preFluids': TextEditingController(
        text: widget.macros.preRun.fluidsMl.round().toString(),
      ),
      'duringFluids': TextEditingController(
        text: widget.macros.duringRun.fluidTotalMl.round().toString(),
      ),
      'postFluids': TextEditingController(
        text: widget.macros.postRun.fluidsMl.round().toString(),
      ),
      'preSodium': TextEditingController(
        text: widget.macros.preRun.sodiumMg.round().toString(),
      ),
      'duringSodium': TextEditingController(
        text: widget.macros.duringRun.sodiumTotalMg.round().toString(),
      ),
      'postSodium': TextEditingController(
        text: widget.macros.postRun.sodiumMg.round().toString(),
      ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fluidLabel =
        'FLUIDS (${UnitFormatter.fluidUnitLabel(useMetric: widget.useMetric)})';

    return AlertDialog(
      title: Text(
        key: const ValueKey('edit_macros.title'),
        'Edit Macro Targets',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMacroSection(
              'CARBS (g)',
              'preCarbs',
              'duringCarbs',
              'postCarbs',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildMacroSection(
              'PROTEIN (g)',
              'preProtein',
              'duringProtein',
              'postProtein',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildMacroSection(
              fluidLabel,
              'preFluids',
              'duringFluids',
              'postFluids',
            ),
            const SizedBox(height: AppSpacing.md),
            _buildMacroSection(
              'SODIUM (mg)',
              'preSodium',
              'duringSodium',
              'postSodium',
            ),
          ],
        ),
      ),
      actions: [
        KyleSecondaryButton(
          key: const ValueKey('edit_macros.cancel_button'),
          text: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: AppSpacing.lg),
        KylePrimaryButton(
          key: const ValueKey('edit_macros.save_button'),
          text: 'Save Changes',
          onPressed: _saveChanges,
        ),
      ],
    );
  }

  Widget _buildMacroSection(
    String label,
    String preKey,
    String duringKey,
    String postKey,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: _buildTextField('PRE', preKey)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _buildTextField('DURING', duringKey)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _buildTextField('POST', postKey)),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String key) {
    // Derive the ValueKey from the controller key string.
    // e.g. 'preCarbs' -> 'edit_macros.carbs_pre_field'
    final String fieldKeyStr;
    switch (key) {
      case 'preCarbs':
        fieldKeyStr = 'edit_macros.carbs_pre_field';
        break;
      case 'duringCarbs':
        fieldKeyStr = 'edit_macros.carbs_during_field';
        break;
      case 'postCarbs':
        fieldKeyStr = 'edit_macros.carbs_post_field';
        break;
      case 'preProtein':
        fieldKeyStr = 'edit_macros.protein_pre_field';
        break;
      case 'duringProtein':
        fieldKeyStr = 'edit_macros.protein_during_field';
        break;
      case 'postProtein':
        fieldKeyStr = 'edit_macros.protein_post_field';
        break;
      case 'preFluids':
        fieldKeyStr = 'edit_macros.fluids_pre_field';
        break;
      case 'duringFluids':
        fieldKeyStr = 'edit_macros.fluids_during_field';
        break;
      case 'postFluids':
        fieldKeyStr = 'edit_macros.fluids_post_field';
        break;
      case 'preSodium':
        fieldKeyStr = 'edit_macros.sodium_pre_field';
        break;
      case 'duringSodium':
        fieldKeyStr = 'edit_macros.sodium_during_field';
        break;
      case 'postSodium':
        fieldKeyStr = 'edit_macros.sodium_post_field';
        break;
      default:
        fieldKeyStr = 'edit_macros.${key}_field';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          key: ValueKey(fieldKeyStr),
          controller: _controllers[key],
          keyboardType: TextInputType.number,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    try {
      // Parse values
      final preCarbs = double.parse(_controllers['preCarbs']!.text);
      final duringCarbs = double.parse(_controllers['duringCarbs']!.text);
      final postCarbs = double.parse(_controllers['postCarbs']!.text);
      final preProtein = double.parse(_controllers['preProtein']!.text);
      final postProtein = double.parse(_controllers['postProtein']!.text);
      final preFluids = double.parse(_controllers['preFluids']!.text);
      final duringFluids = double.parse(_controllers['duringFluids']!.text);
      final postFluids = double.parse(_controllers['postFluids']!.text);
      final preSodium = double.parse(_controllers['preSodium']!.text);
      final duringSodium = double.parse(_controllers['duringSodium']!.text);
      final postSodium = double.parse(_controllers['postSodium']!.text);

      // Save to controller
      await ref
          .read(macroTargetsControllerProvider.notifier)
          .saveAllMacroChanges(
            preRunCarbs: preCarbs,
            duringRunCarbs: duringCarbs,
            postRunCarbs: postCarbs,
            preRunProtein: preProtein,
            postRunProtein: postProtein,
            preRunFluids: preFluids,
            duringRunFluids: duringFluids,
            postRunFluids: postFluids,
            preRunSodium: preSodium,
            duringRunSodium: duringSodium,
            postRunSodium: postSodium,
          );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Show error
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Invalid input: ${e.toString()}');
      }
    }
  }
}

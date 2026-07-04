import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/meal_component.dart';
import '../providers/draft_meal_controller.dart';

/// "Manual" tab body for the build-a-meal sheet.
///
/// Unlike the legacy [ManualLogForm] (which writes a terminal `meal_logs` row
/// directly — still used by the standalone `ManualLogScreen` route), this
/// form builds one [MealComponent] from freeform macro fields and adds it to
/// the build-a-meal draft (item 1), so it composes with everything else the
/// user has added from other tabs.
class ManualComponentForm extends ConsumerStatefulWidget {
  const ManualComponentForm({
    super.key,
    required this.logDate,
    this.scrollController,
  });

  /// `yyyy-MM-dd` date the draft is scoped to.
  final String logDate;

  final ScrollController? scrollController;

  @override
  ConsumerState<ManualComponentForm> createState() =>
      _ManualComponentFormState();
}

class _ManualComponentFormState extends ConsumerState<ManualComponentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _portionCtrl = TextEditingController(text: '1 serving');
  final _calCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _sodiumCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _portionCtrl.dispose();
    _calCtrl.dispose();
    _carbCtrl.dispose();
    _protCtrl.dispose();
    _fatCtrl.dispose();
    _sodiumCtrl.dispose();
    super.dispose();
  }

  void _addToMeal() {
    if (!_formKey.currentState!.validate()) return;

    final component = MealComponent(
      name: _nameCtrl.text.trim(),
      portion: _portionCtrl.text.trim().isEmpty
          ? '1 serving'
          : _portionCtrl.text.trim(),
      calories: int.tryParse(_calCtrl.text),
      carbG: double.tryParse(_carbCtrl.text),
      proteinG: double.tryParse(_protCtrl.text),
      fatG: double.tryParse(_fatCtrl.text),
      sodiumMg: double.tryParse(_sodiumCtrl.text),
    );

    ref
        .read(draftMealControllerProvider(widget.logDate).notifier)
        .addComponent(component);

    MealvanaSnackbar.showSuccess(context, 'Added ${component.name}');

    setState(() {
      _nameCtrl.clear();
      _portionCtrl.text = '1 serving';
      _calCtrl.clear();
      _carbCtrl.clear();
      _protCtrl.clear();
      _fatCtrl.clear();
      _sodiumCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Food name',
              hintText: 'e.g. Homemade chili',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _portionCtrl,
            decoration: const InputDecoration(
              labelText: 'Portion',
              hintText: 'e.g. 1 cup',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _numField('Calories (kcal)', _calCtrl),
          const SizedBox(height: AppSpacing.sm),
          _numField('Carbs (g)', _carbCtrl),
          const SizedBox(height: AppSpacing.sm),
          _numField('Protein (g)', _protCtrl),
          const SizedBox(height: AppSpacing.sm),
          _numField('Fat (g)', _fatCtrl),
          const SizedBox(height: AppSpacing.sm),
          _numField('Sodium (mg)', _sodiumCtrl),
          const SizedBox(height: AppSpacing.xl),
          KylePrimaryButton(text: 'Add to meal', onPressed: _addToMeal),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: AppSpacing.screenPaddingHorizontal,
      child: form,
    );
  }

  Widget _numField(String label, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

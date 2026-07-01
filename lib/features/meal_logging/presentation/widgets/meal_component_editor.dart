import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/meal_component.dart';

/// An editable list of [MealComponent]s for use in the edit-meal-log flow.
///
/// Mirrors the structure of [MealItemsEditor] but operates on [MealComponent]
/// objects (stored in [MealLog.components]) rather than [MealAnalysisItem]s.
/// Exposes [onComponentsChanged] so the parent screen tracks the current list.
class MealComponentEditor extends StatefulWidget {
  const MealComponentEditor({
    super.key,
    required this.initialComponents,
    required this.onComponentsChanged,
  });

  final List<MealComponent> initialComponents;
  final ValueChanged<List<MealComponent>> onComponentsChanged;

  @override
  State<MealComponentEditor> createState() => _MealComponentEditorState();
}

class _MealComponentEditorState extends State<MealComponentEditor> {
  late List<MealComponent> _items;

  @override
  void initState() {
    super.initState();
    _items = List<MealComponent>.from(widget.initialComponents);
  }

  Future<void> _editItem(int index) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditComponentDialog(
        component: _items[index],
        onSave: (updated) {
          setState(() {
            _items[index] = updated;
          });
          widget.onComponentsChanged(List.unmodifiable(_items));
        },
      ),
    );
  }

  int get _totalCalories =>
      _items.fold(0, (sum, item) => sum + (item.calories ?? 0));
  double get _totalCarbG =>
      _items.fold(0.0, (sum, item) => sum + (item.carbG ?? 0));
  double get _totalProteinG =>
      _items.fold(0.0, (sum, item) => sum + (item.proteinG ?? 0));
  double get _totalFatG =>
      _items.fold(0.0, (sum, item) => sum + (item.fatG ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Items', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  item.portion,
                  if (item.calories != null) '${item.calories} kcal',
                  if (item.carbG != null)
                    'C ${item.carbG!.toStringAsFixed(0)}g',
                  if (item.proteinG != null)
                    'P ${item.proteinG!.toStringAsFixed(0)}g',
                  if (item.fatG != null)
                    'F ${item.fatG!.toStringAsFixed(0)}g',
                ].join('  ·  '),
                style: theme.textTheme.bodySmall,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _editItem(i),
                tooltip: 'Edit item',
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: theme.textTheme.labelLarge),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$_totalCalories kcal  '
                  'C ${_totalCarbG.toStringAsFixed(0)}g  '
                  'P ${_totalProteinG.toStringAsFixed(0)}g  '
                  'F ${_totalFatG.toStringAsFixed(0)}g',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Per-item "Edit Item" dialog for a [MealComponent].
///
/// Owns its own [TextEditingController]s (disposed in [dispose]). Macros are
/// absolute for [MealComponent.portion]; the **Quantity** field scales each
/// known macro proportionally. Unknown (null) macros stay blank rather than
/// being fabricated.
class _EditComponentDialog extends StatefulWidget {
  const _EditComponentDialog({required this.component, required this.onSave});

  final MealComponent component;
  final ValueChanged<MealComponent> onSave;

  @override
  State<_EditComponentDialog> createState() => _EditComponentDialogState();
}

class _EditComponentDialogState extends State<_EditComponentDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _portionCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _carbCtrl;
  late final TextEditingController _protCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _sodiumCtrl;

  late final double _baseQty;
  late final String _basePortion;
  late final int? _baseCal;
  late final double? _baseCarb;
  late final double? _baseProt;
  late final double? _baseFat;
  late final double? _baseSodium;

  @override
  void initState() {
    super.initState();
    final item = widget.component;
    _nameCtrl = TextEditingController(text: item.name);
    _portionCtrl = TextEditingController(text: item.portion);
    _calCtrl = TextEditingController(text: item.calories?.toString() ?? '');
    _carbCtrl =
        TextEditingController(text: item.carbG?.toStringAsFixed(1) ?? '');
    _protCtrl =
        TextEditingController(text: item.proteinG?.toStringAsFixed(1) ?? '');
    _fatCtrl = TextEditingController(text: item.fatG?.toStringAsFixed(1) ?? '');
    _sodiumCtrl =
        TextEditingController(text: item.sodiumMg?.toStringAsFixed(0) ?? '');

    _baseQty = _parseLeadingQuantity(item.portion) ?? 1.0;
    _basePortion = item.portion;
    _baseCal = item.calories;
    _baseCarb = item.carbG;
    _baseProt = item.proteinG;
    _baseFat = item.fatG;
    _baseSodium = item.sodiumMg;
    _qtyCtrl = TextEditingController(text: _fmtQty(_baseQty));
    _qtyCtrl.addListener(_recompute);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _portionCtrl.dispose();
    _qtyCtrl.dispose();
    _calCtrl.dispose();
    _carbCtrl.dispose();
    _protCtrl.dispose();
    _fatCtrl.dispose();
    _sodiumCtrl.dispose();
    super.dispose();
  }

  void _recompute() {
    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0) return;
    final ratio = qty / _baseQty;
    final baseCal = _baseCal;
    final baseCarb = _baseCarb;
    final baseProt = _baseProt;
    final baseFat = _baseFat;
    final baseSodium = _baseSodium;
    if (baseCal != null) _calCtrl.text = (baseCal * ratio).round().toString();
    if (baseCarb != null) {
      _carbCtrl.text = (baseCarb * ratio).toStringAsFixed(1);
    }
    if (baseProt != null) {
      _protCtrl.text = (baseProt * ratio).toStringAsFixed(1);
    }
    if (baseFat != null) _fatCtrl.text = (baseFat * ratio).toStringAsFixed(1);
    if (baseSodium != null) {
      _sodiumCtrl.text = (baseSodium * ratio).toStringAsFixed(0);
    }
    final rewritten = _replaceLeadingQuantity(_basePortion, qty);
    if (rewritten != null) _portionCtrl.text = rewritten;
  }

  void _save() {
    final item = widget.component;
    final updated = MealComponent(
      name: _nameCtrl.text.trim().isEmpty ? item.name : _nameCtrl.text.trim(),
      portion: _portionCtrl.text.trim().isEmpty
          ? item.portion
          : _portionCtrl.text.trim(),
      calories: int.tryParse(_calCtrl.text) ?? item.calories,
      carbG: double.tryParse(_carbCtrl.text) ?? item.carbG,
      proteinG: double.tryParse(_protCtrl.text) ?? item.proteinG,
      fatG: double.tryParse(_fatCtrl.text) ?? item.fatG,
      sodiumMg: double.tryParse(_sodiumCtrl.text) ?? item.sodiumMg,
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('Name', _nameCtrl),
            const SizedBox(height: 8),
            _field('Portion', _portionCtrl),
            const SizedBox(height: 8),
            _numField('Quantity', _qtyCtrl,
                helperText: 'Scales the nutrients below'),
            const SizedBox(height: 8),
            _numField('Calories', _calCtrl),
            const SizedBox(height: 8),
            _numField('Carbs (g)', _carbCtrl),
            const SizedBox(height: 8),
            _numField('Protein (g)', _protCtrl),
            const SizedBox(height: 8),
            _numField('Fat (g)', _fatCtrl),
            const SizedBox(height: 8),
            _numField('Sodium (mg)', _sodiumCtrl),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl,
      {String? helperText}) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  /// Parses the leading numeric quantity from a portion string, e.g. "2 cups"
  /// → 2.0, "1.5 oz" → 1.5. Returns null when there is no leading number.
  double? _parseLeadingQuantity(String portion) {
    final match = RegExp(r'^\s*(\d+(?:\.\d+)?)').firstMatch(portion);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  /// Rewrites the leading number of [portion] to [qty], preserving the unit
  /// suffix (e.g. "1 cup" + 2 → "2 cup"). Returns null when there is no leading
  /// number to replace.
  String? _replaceLeadingQuantity(String portion, double qty) {
    final match =
        RegExp(r'^(\s*)(\d+(?:\.\d+)?)(.*)$').firstMatch(portion);
    if (match == null) return null;
    return '${match.group(1)}${_fmtQty(qty)}${match.group(3)}';
  }

  /// Formats a quantity without a trailing ".0" for whole numbers.
  String _fmtQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toString();
  }
}

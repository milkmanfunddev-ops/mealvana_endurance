import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Plus/Minus control for Kyle's design system
/// 36px circular buttons with Orange borders
class KylePlusMinusControl extends ConsumerStatefulWidget {
  const KylePlusMinusControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.step = 1,
    this.label,
    this.unit,
    this.enabled = true,
    this.tappable = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;
  final int step;
  final String? label;
  final String? unit;
  final bool enabled;
  final bool tappable;

  @override
  ConsumerState<KylePlusMinusControl> createState() =>
      _KylePlusMinusControlState();
}

class _KylePlusMinusControlState extends ConsumerState<KylePlusMinusControl> {
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(KylePlusMinusControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  void _increment() {
    if (!widget.enabled) return;

    final newValue = _currentValue + widget.step;
    if (widget.max == null || newValue <= widget.max!) {
      setState(() {
        _currentValue = newValue;
      });
      widget.onChanged(newValue);
    }
  }

  void _decrement() {
    if (!widget.enabled) return;

    final newValue = _currentValue - widget.step;
    if (newValue >= widget.min) {
      setState(() {
        _currentValue = newValue;
      });
      widget.onChanged(newValue);
    }
  }

  Future<void> _showEditDialog() async {
    final controller = TextEditingController(text: _currentValue.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.label ?? 'Enter Value'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter ${widget.unit ?? 'value'}',
            suffixText: widget.unit?.toUpperCase(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null) {
                // Clamp value to min/max
                final clampedValue = value.clamp(
                  widget.min,
                  widget.max ?? value,
                );
                Navigator.pop(context, clampedValue);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _currentValue = result;
      });
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canIncrement =
        widget.max == null || _currentValue + widget.step <= widget.max!;
    final canDecrement = _currentValue - widget.step >= widget.min;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label (left-aligned)
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTextStyles.descriptor.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // Control (full width)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minus button
            _ControlButton(
              icon: FontAwesomeIcons.minus,
              onPressed: canDecrement ? _decrement : null,
              enabled: widget.enabled && canDecrement,
              semanticLabel: _semanticLabel(decrement: true),
            ),

            const SizedBox(width: AppSpacing.xl),

            // Value display (flexible to expand)
            Expanded(
              child: widget.tappable
                  ? GestureDetector(
                      onTap: widget.enabled ? _showEditDialog : null,
                      child: Text(
                        widget.unit != null
                            ? '$_currentValue ${widget.unit!.toUpperCase()}'
                            : '$_currentValue',
                        style: AppTextStyles.dataNumber.copyWith(
                          color: widget.enabled
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Text(
                      widget.unit != null
                          ? '$_currentValue ${widget.unit!.toUpperCase()}'
                          : '$_currentValue',
                      style: AppTextStyles.dataNumber.copyWith(
                        color: widget.enabled
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),

            const SizedBox(width: AppSpacing.xl),

            // Plus button
            _ControlButton(
              icon: FontAwesomeIcons.plus,
              onPressed: canIncrement ? _increment : null,
              enabled: widget.enabled && canIncrement,
              semanticLabel: _semanticLabel(decrement: false),
            ),
          ],
        ),
      ],
    );
  }
}

/// Individual control button
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onPressed,
    required this.enabled,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabledIconColor = isDark ? AppColors.cream : AppColors.orange;
    final disabledIconColor = enabledIconColor.withValues(alpha: 0.4);

    return SizedBox(
      width: AppSizes.controlSize,
      height: AppSizes.controlSize,
      child: Tooltip(
        message: semanticLabel,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: enabled
                ? Colors.orange
                : Colors.orange.withOpacity(0.4),
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.orange.withOpacity(0.4),
            elevation: 0,
            shadowColor: Colors.transparent,
            side: BorderSide(
              color: enabled ? Colors.orange : Colors.orange.withOpacity(0.4),
              width: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.circularRadius,
            ),
            padding: EdgeInsets.zero,
          ),
          child: Semantics(
            label: semanticLabel,
            button: true,
            excludeSemantics: true,
            child: Icon(
              icon,
              size: AppIconSizes.controlIcon,
              color: enabled ? enabledIconColor : disabledIconColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Plus/Minus control with decimal values
class KylePlusMinusDecimalControl extends ConsumerStatefulWidget {
  const KylePlusMinusDecimalControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max,
    this.step = 1.0,
    this.decimalPlaces = 1,
    this.label,
    this.unit,
    this.enabled = true,
    this.tappable = false,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double? max;
  final double step;
  final int decimalPlaces;
  final String? label;
  final String? unit;
  final bool enabled;
  final bool tappable;

  @override
  ConsumerState<KylePlusMinusDecimalControl> createState() =>
      _KylePlusMinusDecimalControlState();
}

class _KylePlusMinusDecimalControlState
    extends ConsumerState<KylePlusMinusDecimalControl> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(KylePlusMinusDecimalControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  void _increment() {
    if (!widget.enabled) return;

    final newValue = _currentValue + widget.step;
    if (widget.max == null || newValue <= widget.max!) {
      setState(() {
        _currentValue = newValue;
      });
      widget.onChanged(newValue);
    }
  }

  void _decrement() {
    if (!widget.enabled) return;

    final newValue = _currentValue - widget.step;
    if (newValue >= widget.min) {
      setState(() {
        _currentValue = newValue;
      });
      widget.onChanged(newValue);
    }
  }

  Future<void> _showEditDialog() async {
    final controller = TextEditingController(
      text: _currentValue.toStringAsFixed(widget.decimalPlaces),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.label ?? 'Enter Value'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter ${widget.unit ?? 'value'}',
            suffixText: widget.unit?.toUpperCase(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                // Clamp value to min/max
                final clampedValue = value.clamp(
                  widget.min,
                  widget.max ?? value,
                );
                Navigator.pop(context, clampedValue);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _currentValue = result;
      });
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canIncrement =
        widget.max == null || _currentValue + widget.step <= widget.max!;
    final canDecrement = _currentValue - widget.step >= widget.min;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label (left-aligned)
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTextStyles.descriptor.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // Control (full width)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minus button
            _ControlButton(
              icon: FontAwesomeIcons.minus,
              onPressed: canDecrement ? _decrement : null,
              enabled: widget.enabled && canDecrement,
            ),

            const SizedBox(width: AppSpacing.xl),

            // Value display (flexible to expand)
            Expanded(
              child: widget.tappable
                  ? GestureDetector(
                      onTap: widget.enabled ? _showEditDialog : null,
                      child: Text(
                        widget.unit != null
                            ? '${_currentValue.toStringAsFixed(widget.decimalPlaces)} ${widget.unit!.toUpperCase()}'
                            : _currentValue.toStringAsFixed(
                                widget.decimalPlaces,
                              ),
                        style: AppTextStyles.dataNumber.copyWith(
                          color: widget.enabled
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Text(
                      widget.unit != null
                          ? '${_currentValue.toStringAsFixed(widget.decimalPlaces)} ${widget.unit!.toUpperCase()}'
                          : _currentValue.toStringAsFixed(widget.decimalPlaces),
                      style: AppTextStyles.dataNumber.copyWith(
                        color: widget.enabled
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),

            const SizedBox(width: AppSpacing.xl),

            // Plus button
            _ControlButton(
              icon: FontAwesomeIcons.plus,
              onPressed: canIncrement ? _increment : null,
              enabled: widget.enabled && canIncrement,
            ),
          ],
        ),
      ],
    );
  }
}

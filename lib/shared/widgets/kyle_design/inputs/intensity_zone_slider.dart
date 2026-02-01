import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// A single intensity zone slider for Kyle's design system
///
/// Two-row layout matching Figma design:
/// - Row 1: Colored dot (10px) + Zone label ............... Percentage box (48px) + %
/// - Row 2: Full-width slider (6px track height, 8px thumb radius)
///
/// Row 1 uses MainAxisAlignment.spaceBetween for proper spacing.
/// Zone label uses AppTextStyles.bodyMedium (Apercu 14px, normal weight).
/// Percentage box has light purple background with no border.
///
/// Used in the intensity distribution widget to adjust the percentage
/// distribution across different training zones.
class IntensityZoneSlider extends ConsumerStatefulWidget {
  const IntensityZoneSlider({
    super.key,
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// Zone label (e.g., "Conversational (Z1-Z2)")
  final String label;

  /// Zone color for dot and slider track
  final Color color;

  /// Current percentage value (0-100)
  final int value;

  /// Callback when value changes (from slider or text field)
  final ValueChanged<int> onChanged;

  /// Whether the slider is enabled
  final bool enabled;

  @override
  ConsumerState<IntensityZoneSlider> createState() => _IntensityZoneSliderState();
}

class _IntensityZoneSliderState extends ConsumerState<IntensityZoneSlider> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  int _lastHapticValue = 0; // Track last value for haptic feedback

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode();
    _lastHapticValue = widget.value;

    // Update text field when focus is lost
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(IntensityZoneSlider oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update text field if value changed externally and field is not focused
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _textController.text = widget.value.toString();
    }

    // Update last haptic value when widget value changes externally
    if (oldWidget.value != widget.value) {
      _lastHapticValue = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // When focus is lost, ensure text field shows current value
      _textController.text = widget.value.toString();
    }
  }

  void _handleTextChanged(String text) {
    // Parse and validate input
    final parsed = int.tryParse(text);
    if (parsed != null && parsed >= 0 && parsed <= 100) {
      // Trigger haptic feedback on value change
      if (parsed != _lastHapticValue) {
        _triggerHapticFeedback(parsed);
        _lastHapticValue = parsed;
      }
      widget.onChanged(parsed);
    }
  }

  void _handleTextSubmitted(String text) {
    // On submit, parse value or revert to current
    final parsed = int.tryParse(text);
    if (parsed != null && parsed >= 0 && parsed <= 100) {
      widget.onChanged(parsed);
    } else {
      // Invalid input - revert to current value
      _textController.text = widget.value.toString();
    }

    // Dismiss keyboard
    _focusNode.unfocus();
  }

  /// Triggers haptic feedback based on the new value
  ///
  /// Uses light impact for min (0) or max (100) values,
  /// selection click for normal value changes
  void _triggerHapticFeedback(int newValue) {
    if (newValue == 0 || newValue == 100) {
      // Stronger feedback at boundaries
      HapticFeedback.lightImpact();
    } else {
      // Subtle feedback for normal changes
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1: Label and percentage
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side: dot + label
            Row(
              children: [
                // Colored dot indicator (10px)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.enabled ? widget.color : widget.color.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),

                const SizedBox(width: AppSpacing.xs),

                // Zone label
                Text(
                  widget.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: widget.enabled
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),

            // Right side: percentage box + %
            Row(
              children: [
                // Editable percentage text field (56px wide, 36px tall)
                Semantics(
                  label: '${widget.label} percentage',
                  hint: 'Enter a value between 0 and 100',
                  textField: true,
                  enabled: widget.enabled,
                  child: Container(
                    width: 56,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground, // Brighter purple for visibility
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      style: AppTextStyles.inputText.copyWith(
                        color: AppColors.cream,
                        fontSize: 16,
                      ),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      onChanged: _handleTextChanged,
                      onSubmitted: _handleTextSubmitted,
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.xxs),

                // "%" suffix
                Text(
                  '%',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: widget.enabled
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xs),

        // Row 2: Full-width slider
        Semantics(
          label: '${widget.label} intensity: ${widget.value} percent',
          slider: true,
          value: '${widget.value}%',
          enabled: widget.enabled,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: widget.enabled ? widget.color : widget.color.withValues(alpha: 0.4),
              inactiveTrackColor: widget.enabled
                  ? widget.color.withValues(alpha: 0.2)
                  : widget.color.withValues(alpha: 0.1),
              thumbColor: widget.enabled ? widget.color : widget.color.withValues(alpha: 0.4),
              overlayColor: widget.color.withValues(alpha: 0.2),
              trackHeight: 6.0,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8.0,
                elevation: 2.0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: widget.value.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: widget.enabled
                  ? (value) {
                      final roundedValue = value.round();
                      // Only trigger haptic feedback when integer value changes
                      if (roundedValue != _lastHapticValue) {
                        _triggerHapticFeedback(roundedValue);
                        _lastHapticValue = roundedValue;
                      }
                      widget.onChanged(roundedValue);
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

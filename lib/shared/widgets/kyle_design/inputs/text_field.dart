import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';


/// Text field for Kyle's design system
/// 46px height with 15px radius and transparent background
class KyleTextField extends ConsumerStatefulWidget {
  const KyleTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final int maxLines;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  ConsumerState<KyleTextField> createState() => _KyleTextFieldState();
}

class _KyleTextFieldState extends ConsumerState<KyleTextField> {
  late bool _obscureText;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              widget.label!,
              style: AppTextStyles.smallLabel.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
        
        // Text field
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          style: AppTextStyles.inputText.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: AppSpacing.inputPadding,
            hintText: widget.hint,
            hintStyle: AppTextStyles.inputText.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    size: AppIconSizes.controlIcon,
                  )
                : null,
            suffixIcon: _buildSuffixIcon(),
            border: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: const BorderSide(
                color: Colors.orange,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: const BorderSide(
                color: AppColors.dragonfruit,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: const BorderSide(
                color: AppColors.dragonfruit,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.obscureText) {
      return IconButton(
        icon: Icon(
          _obscureText ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          size: AppIconSizes.controlIcon,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }
    
    return widget.suffixIcon;
  }
}

/// Search text field variant
class KyleSearchField extends ConsumerStatefulWidget {
  const KyleSearchField({
    super.key,
    this.controller,
    this.hint = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  ConsumerState<KyleSearchField> createState() => _KyleSearchFieldState();
}

class _KyleSearchFieldState extends ConsumerState<KyleSearchField> {
  late FocusNode _focusNode;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    if (widget.controller != null) {
      _hasText = widget.controller!.text.isNotEmpty;
      widget.controller!.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    if (widget.controller != null) {
      widget.controller!.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller!.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      style: AppTextStyles.inputText.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: AppSpacing.inputPadding,
        hintText: widget.hint,
        hintStyle: AppTextStyles.inputText.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
        prefixIcon: Icon(
          FontAwesomeIcons.magnifyingGlass,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          size: AppIconSizes.controlIcon,
        ),
        suffixIcon: _hasText
            ? IconButton(
                icon: Icon(
                  FontAwesomeIcons.xmark,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  size: AppIconSizes.controlIcon,
                ),
                onPressed: () {
                  widget.controller?.clear();
                  widget.onClear?.call();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(
            color: Colors.orange,
            width: 2,
          ),
        ),
      ),
    );
  }
}
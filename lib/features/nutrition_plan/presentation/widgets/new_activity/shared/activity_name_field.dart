import 'package:flutter/material.dart';
import '../../../../../../shared/widgets/kyle_design/inputs/text_field.dart';

/// Editable activity name field used on the New Activity screen tabs.
class ActivityNameField extends StatefulWidget {
  const ActivityNameField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Workout Name',
    this.hint = 'Enter workout name',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final String hint;

  @override
  State<ActivityNameField> createState() => _ActivityNameFieldState();
}

class _ActivityNameFieldState extends State<ActivityNameField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant ActivityNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    if (_focusNode.hasFocus) return;
    if (_controller.text == widget.value) return;
    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection.collapsed(offset: widget.value.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KyleTextField(
      controller: _controller,
      focusNode: _focusNode,
      label: widget.label,
      hint: widget.hint,
      textInputAction: TextInputAction.next,
      onChanged: widget.onChanged,
    );
  }
}

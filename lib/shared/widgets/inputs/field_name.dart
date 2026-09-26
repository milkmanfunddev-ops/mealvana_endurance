import 'package:flutter/material.dart';

/// Keeps a text field named for a screen reader.
///
/// A field named only by its hint loses the name the moment it holds a
/// value: the hidden hint leaves the semantics tree, and VoiceOver hears
/// "Xuan" with no idea which field that is (testing-wave 118-005, 119-006).
/// This adds [name] to the field's own node once the hint is gone, or all
/// the time with [always] (a field whose hint is a placeholder like "Auto",
/// not its name). The label merges into the field node, so the field stays
/// one editable element.
class FieldName extends StatelessWidget {
  const FieldName({
    super.key,
    required this.name,
    required this.controller,
    required this.child,
    this.always = false,
  });

  /// What the field is for, as its hint says while it is empty.
  final String name;

  /// The field's controller: the name is added once its text is non-empty.
  final TextEditingController controller;

  /// Name the field whether or not it is empty.
  final bool always;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      child: child,
      builder: (context, value, child) => Semantics(
        label: always || value.text.isNotEmpty ? name : null,
        child: child,
      ),
    );
  }
}

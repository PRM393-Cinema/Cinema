import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.labelAbove = false,
    this.isRequired = false,
    this.labelAction,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool labelAbove;
  final bool isRequired;
  final Widget? labelAction;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    Widget buildField(bool hasValue) {
      final field = TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        enabled: enabled,
        maxLines: obscureText ? 1 : maxLines,
        decoration: InputDecoration(
          labelText: labelAbove ? null : label,
          hintText: hint,
          prefixIcon: prefixIcon,
          suffixIcon: isRequired && !hasValue
              ? SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        '*',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
              : suffixIcon,
        ),
      );

      if (!labelAbove) return field;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?labelAction,
            ],
          ),
          const SizedBox(height: 6),
          Semantics(label: label, child: field),
        ],
      );
    }

    if (!isRequired || controller == null) return buildField(false);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller!,
      builder: (context, value, _) => buildField(value.text.trim().isNotEmpty),
    );
  }
}

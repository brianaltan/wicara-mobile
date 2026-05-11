import 'package:flutter/material.dart';

import '../../../../core/theme/wicara_colors.dart';

class WicaraTextField extends StatelessWidget {
  const WicaraTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.textInputAction,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      validator: validator,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: WicaraColors.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        helperText: ' ',
        helperMaxLines: 1,
        errorMaxLines: 1,
        helperStyle: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.transparent, height: 1.1),
        errorStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFFE57373),
          fontWeight: FontWeight.w400,
          height: 1.1,
        ),
        filled: true,
        fillColor: WicaraColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: WicaraColors.softMuted, size: 22),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 46,
          minHeight: 20,
        ),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: WicaraColors.line, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: WicaraColors.secondary,
            width: 1.7,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE57373), width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE57373), width: 1.7),
        ),
      ),
    );
  }
}

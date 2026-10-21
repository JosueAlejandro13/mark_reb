import 'package:flutter/material.dart';

/// Título de sección en estilo Apple Inset Grouped (pequeño, mayúsculas sutiles, espaciado)
class AppleSectionTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;
  final TextStyle? style;

  const AppleSectionTitle(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(left: 4, bottom: 8, top: 12),
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: style ??
            const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

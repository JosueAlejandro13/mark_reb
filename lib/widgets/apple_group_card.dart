import 'package:flutter/material.dart';

/// Contenedor agrupado estilo Apple Inset Grouped con bordes redondeados y sombra suave
class AppleGroupCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;
  final CrossAxisAlignment crossAxisAlignment;

  const AppleGroupCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFE2E8F0),
    this.borderRadius = 18,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

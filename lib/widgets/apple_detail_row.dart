import 'package:flutter/material.dart';

/// Fila de detalle estilo Apple (icono squircle, etiqueta y valor alineados)
class AppleDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isHighlight;
  final Color? highlightColor;
  final Widget? trailing;

  const AppleDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.highlightColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final activeHighlight = highlightColor ?? const Color(0xFF0284C7);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isHighlight
                ? activeHighlight.withOpacity(0.12)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isHighlight ? activeHighlight : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              color: isHighlight
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF475569),
            ),
          ),
        ),
        if (trailing != null)
          trailing!
        else
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 14.5 : 13,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight ? activeHighlight : const Color(0xFF0F172A),
              letterSpacing: isHighlight ? -0.2 : 0,
            ),
          ),
      ],
    );
  }
}

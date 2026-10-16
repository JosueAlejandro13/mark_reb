import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// Botón de acción principal reutilizable con estado de carga integrado
/// y diseño ejecutivo estilo Apple iOS (degradado sutil, sombra suave y bordes redondeados).
class LoadingActionButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color foregroundColor;
  final Color disabledBackgroundColor;
  final Color disabledForegroundColor;
  final double? width;
  final double height;
  final double borderRadius;
  final double fontSize;
  final double loadingSize;

  const LoadingActionButton({
    super.key,
    required this.text,
    required this.isLoading,
    required this.onPressed,
    this.icon,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor = Colors.white,
    this.disabledBackgroundColor = const Color(0xFFE2E8F0),
    this.disabledForegroundColor = const Color(0xFF94A3B8),
    this.width = double.infinity,
    this.height = 50,
    this.borderRadius = 16,
    this.fontSize = 14.5,
    this.loadingSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ??
        (backgroundColor == null
            ? const LinearGradient(
                colors: [
                  Color(0xFF0284C7),
                  Color(0xFF0369A1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null);

    final isInteractive = !isLoading && onPressed != null;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: isInteractive ? effectiveGradient : null,
          color: isInteractive
              ? (effectiveGradient == null ? backgroundColor : null)
              : disabledBackgroundColor,
          boxShadow: isInteractive
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: foregroundColor,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: disabledForegroundColor,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: isLoading
              ? Center(
                  child: LoadingAnimationWidget.threeRotatingDots(
                    color: foregroundColor,
                    size: loadingSize,
                  ),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: foregroundColor, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

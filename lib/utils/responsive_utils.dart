// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';

/// Utilidades de responsividad para la app Mark V3.
///
/// Breakpoints:
/// - Móvil: < 600px de ancho lógico
/// - Tablet: >= 600px de ancho lógico
/// - Desktop: >= 1024px de ancho lógico
abstract class AppBreakpoints {
  /// Ancho mínimo para considerar el dispositivo como tablet.
  static const double tabletBreak = 600.0;

  /// Ancho mínimo para considerar el dispositivo como desktop.
  static const double desktopBreak = 1024.0;

  /// Retorna `true` si el ancho disponible es de tablet o mayor.
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreak;

  /// Retorna `true` si el ancho disponible es de desktop.
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreak;

  /// Retorna `true` si es exclusivamente móvil (< tabletBreak).
  static bool isMobile(BuildContext context) => !isTablet(context);

  /// Retorna el ancho lógico de la pantalla.
  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  /// Retorna el alto lógico de la pantalla.
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// Devuelve un valor distinto según si es móvil o tablet/desktop.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    required T tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  /// Padding horizontal estándar según tamaño de pantalla.
  /// Móvil: 16 | Tablet: 28 | Desktop: 48
  static double horizontalPadding(BuildContext context) =>
      value(context, mobile: 16.0, tablet: 28.0, desktop: 48.0);
}

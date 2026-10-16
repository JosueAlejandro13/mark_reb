import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

/// Estilos disponibles para el SnackbarTop
enum SnackbarTopStyle {
  /// Color sólido con gradiente elegante del sistema (Verde, Rojo, Azul)
  systemColor,

  /// Estilo Apple Frosted Card (Blanco puro con detalles y cápsula de color)
  appleCard,
}

/// Tipo de notificación del sistema
enum SnackbarTopType {
  /// Éxito / Operación correcta (Verde esmeralda Apple con checkmark)
  success,

  /// Error / Falla (Rojo reservado únicamente por semántica)
  error,

  /// Información (Azul corporativo del sistema)
  info,

  /// Advertencia / Aviso (Ámbar / Naranja)
  warning,
}

/// Widget y utilitario de Snackbar Top estilo Apple para toda la aplicación.
///
/// Uso rápido:
/// ```dart
/// // Éxito con título automático "Correcto":
/// SnackbarTop.showSuccess(context, "Operación realizada correctamente.");
///
/// // Error con título automático "Error":
/// SnackbarTop.showError(context, "No se pudo conectar al servidor.");
///
/// // Información con título automático "Información":
/// SnackbarTop.showInfo(context, "Sincronizando información...");
///
/// // Aviso con título automático "Aviso":
/// SnackbarTop.showWarning(context, "Tienes datos pendientes por guardar.");
/// ```
class SnackbarTop {
  SnackbarTop._();

  /// Muestra un snackbar superior de **Éxito / Correcto**.
  ///
  /// El título predeterminado es `'Correcto'`. Solo necesitas pasar el [message].
  static void showSuccess(
    BuildContext context,
    String message, {
    String title = 'Correcto',
    Duration duration = const Duration(milliseconds: 3000),
    SnackbarTopStyle style = SnackbarTopStyle.appleCard,
    VoidCallback? onTap,
  }) {
    _show(
      context: context,
      type: SnackbarTopType.success,
      title: title,
      message: message,
      duration: duration,
      style: style,
      onTap: onTap,
    );
  }

  /// Alias corto para [showSuccess].
  static void success(
    BuildContext context,
    String message, {
    String title = 'Correcto',
    Duration duration = const Duration(milliseconds: 3000),
    SnackbarTopStyle style = SnackbarTopStyle.appleCard,
    VoidCallback? onTap,
  }) =>
      showSuccess(context, message,
          title: title, duration: duration, style: style, onTap: onTap);

  /// Alias explícito para feedback de operación correcta
  static void showCorrect(
    BuildContext context,
    String message, {
    String title = 'Correcto',
    Duration duration = const Duration(milliseconds: 3000),
    SnackbarTopStyle style = SnackbarTopStyle.appleCard,
    VoidCallback? onTap,
  }) =>
      showSuccess(context, message,
          title: title, duration: duration, style: style, onTap: onTap);

  /// Muestra un snackbar superior de **Error**.
  ///
  /// El título predeterminado es `'Error'`. Solo necesitas pasar el [message].
  static void showError(
    BuildContext context,
    String message, {
    String title = 'Error',
    Duration duration = const Duration(milliseconds: 3500),
    SnackbarTopStyle style = SnackbarTopStyle.appleCard,
    VoidCallback? onTap,
  }) {
    _show(
      context: context,
      type: SnackbarTopType.error,
      title: title,
      message: message,
      duration: duration,
      style: style,
      onTap: onTap,
    );
  }

  /// Alias corto para [showError].
  static void error(
    BuildContext context,
    String message, {
    String title = 'Error',
    Duration duration = const Duration(milliseconds: 3500),
    SnackbarTopStyle style = SnackbarTopStyle.appleCard,
    VoidCallback? onTap,
  }) =>
      showError(context, message,
          title: title, duration: duration, style: style, onTap: onTap);

  /// Muestra un snackbar superior de **Información**.
  ///
  /// El título predeterminado es `'Información'`. Solo necesitas pasar el [message].
  static void showInfo(
    BuildContext context,
    String message, {
    String title = 'Información',
    Duration duration = const Duration(milliseconds: 3000),
    SnackbarTopStyle style = SnackbarTopStyle.appleCard,
    VoidCallback? onTap,
  }) {
    _show(
      context: context,
      type: SnackbarTopType.info,
      title: title,
      message: message,
      duration: duration,
      style: style,
      onTap: onTap,
    );
  }

  /// Alias corto para [showInfo].
  static void info(
    BuildContext context,
    String message, {
    String title = 'Información',
    Duration duration = const Duration(milliseconds: 3000),
    SnackbarTopStyle style = SnackbarTopStyle.appleCard,
    VoidCallback? onTap,
  }) =>
      showInfo(context, message,
          title: title, duration: duration, style: style, onTap: onTap);

  /// Muestra un snackbar superior de **Advertencia / Aviso**.
  ///
  /// El título predeterminado es `'Aviso'`. Solo necesitas pasar el [message].
  static void showWarning(
    BuildContext context,
    String message, {
    String title = 'Aviso',
    Duration duration = const Duration(milliseconds: 3000),
    SnackbarTopStyle style = SnackbarTopStyle.appleCard,
    VoidCallback? onTap,
  }) {
    _show(
      context: context,
      type: SnackbarTopType.warning,
      title: title,
      message: message,
      duration: duration,
      style: style,
      onTap: onTap,
    );
  }

  /// Alias corto para [showWarning].
  static void warning(
    BuildContext context,
    String message, {
    String title = 'Aviso',
    Duration duration = const Duration(milliseconds: 3000),
    SnackbarTopStyle style = SnackbarTopStyle.appleCard,
    VoidCallback? onTap,
  }) =>
      showWarning(context, message,
          title: title, duration: duration, style: style, onTap: onTap);

  /// Método interno centralizado para mostrar el Overlay
  static void _show({
    required BuildContext context,
    required SnackbarTopType type,
    required String title,
    required String message,
    required Duration duration,
    required SnackbarTopStyle style,
    VoidCallback? onTap,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    showTopSnackBar(
      overlay,
      SnackbarTopWidget(
        type: type,
        title: title,
        message: message,
        style: style,
        onTap: onTap,
      ),
      displayDuration: duration,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

/// Widget visual del Snackbar Top con estética Apple HIG (fondo blanco pulido).
class SnackbarTopWidget extends StatelessWidget {
  final SnackbarTopType type;
  final String title;
  final String message;
  final SnackbarTopStyle style;
  final VoidCallback? onTap;

  const SnackbarTopWidget({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.style = SnackbarTopStyle.appleCard,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Todos los snackbars se muestran en tarjeta blanca pulida Apple Card
    return _buildAppleCardStyle(context);
  }

  // --- CONFIGURACIÓN DE COLORES E ÍCONOS SEGÚN TIPO ---
  _SnackbarConfig get _config {
    switch (type) {
      case SnackbarTopType.success:
        return const _SnackbarConfig(
          icon: Icons.check_circle_rounded,
          // Verde Apple / Éxito / Correcto
          gradientColors: [Color(0xFF059669), Color(0xFF10B981)],
          accentColor: Color(0xFF10B981),
          lightBgColor: Color(0xFFECFDF5),
          lightBorderColor: Color(0xFFA7F3D0),
          shadowColor: Color(0xFF10B981),
        );
      case SnackbarTopType.info:
        return const _SnackbarConfig(
          icon: Icons.info_rounded,
          // Azul corporativo informativo
          gradientColors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
          accentColor: Color(0xFF0284C7),
          lightBgColor: Color(0xFFF0F9FF),
          lightBorderColor: Color(0xFFBAE6FD),
          shadowColor: Color(0xFF0284C7),
        );
      case SnackbarTopType.warning:
        return const _SnackbarConfig(
          icon: Icons.warning_amber_rounded,
          // Naranja Apple: cálido, visible y de advertencia sutil
          gradientColors: [Color(0xFFEA580C), Color(0xFFF97316)],
          accentColor: Color(0xFFF97316),
          lightBgColor: Color(0xFFFFF7ED),
          lightBorderColor: Color(0xFFFED7AA),
          shadowColor: Color(0xFFF97316),
        );
      case SnackbarTopType.error:
        return const _SnackbarConfig(
          icon: Icons.error_rounded,
          // Rojo Apple: reservado estrictamente para fallas y errores
          gradientColors: [Color(0xFFDC2626), Color(0xFFEF4444)],
          accentColor: Color(0xFFEF4444),
          lightBgColor: Color(0xFFFEF2F2),
          lightBorderColor: Color(0xFFFECACA),
          shadowColor: Color(0xFFEF4444),
        );
    }
  }

  // --- ESTILO 1: COLOR DEL SISTEMA (Gradiente vibrante ejecutivo) ---
  Widget _buildSystemColorStyle(BuildContext context) {
    final cfg = _config;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: cfg.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.22),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: cfg.shadowColor.withOpacity(0.35),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cápsula de ícono estilo cristal
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.32),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Icon(
                    cfg.icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Mensaje personalizado (sin título redundante)
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ESTILO 2: APPLE PILL (Cápsula flotante blanca pulida con badge circular y sombra suave) ---
  Widget _buildAppleCardStyle(BuildContext context) {
    final cfg = _config;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.09),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: cfg.accentColor.withOpacity(0.08),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge circular con color suave del sistema Apple
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cfg.lightBgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cfg.lightBorderColor.withOpacity(0.7),
                    width: 0.9,
                  ),
                ),
                child: Center(
                  child: Icon(
                    cfg.icon,
                    color: cfg.accentColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Mensaje limpio en píldora
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnackbarConfig {
  final IconData icon;
  final List<Color> gradientColors;
  final Color accentColor;
  final Color lightBgColor;
  final Color lightBorderColor;
  final Color shadowColor;

  const _SnackbarConfig({
    required this.icon,
    required this.gradientColors,
    required this.accentColor,
    required this.lightBgColor,
    required this.lightBorderColor,
    required this.shadowColor,
  });
}

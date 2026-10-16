import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class LocationDisclosureSheet extends StatelessWidget {
  const LocationDisclosureSheet({super.key});

  /// Muestra el modal de divulgación prominente y solicita los permisos paso a paso si el usuario acepta.
  ///
  /// Retorna `true` si el usuario aceptó y los permisos fueron concedidos, o `false` en caso contrario.
  static Future<bool> checkAndRequestLocationPermission(
      BuildContext context) async {
    // 1. Verificar si el servicio de GPS está activo
    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      if (context.mounted) {
        _showGpsDisabledDialog(context);
      }
      return false;
    }

    // 2. Comprobar si ya cuenta con permisos
    final currentPermission = await Geolocator.checkPermission();
    if (currentPermission == LocationPermission.always ||
        currentPermission == LocationPermission.whileInUse) {
      return true;
    }

    if (!context.mounted) return false;

    // 3. Mostrar la divulgación destacada ANTES de invocar el diálogo nativo
    final bool userAccepted = await show(context);
    if (!userAccepted) {
      return false;
    }

    // 4. Solicitar permiso de ubicación
    HapticFeedback.mediumImpact();
    LocationPermission requestedPerm = await Geolocator.requestPermission();

    if (requestedPerm == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showDeniedForeverDialog(context);
      }
      return false;
    }

    if (requestedPerm == LocationPermission.denied) {
      return false;
    }

    return true;
  }

  /// Despliega el BottomSheet con diseño Apple
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => const LocationDisclosureSheet(),
    );
    return result ?? false;
  }

  static void _showGpsDisabledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('GPS Desactivado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Para registrar tus recorridos de entrega y visitas es necesario activar el GPS del dispositivo.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Geolocator.openLocationSettings();
            },
            child: const Text('Abrir Ajustes'),
          ),
        ],
      ),
    );
  }

  static void _showDeniedForeverDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.settings_suggest_rounded, color: Color(0xFF0284C7)),
            SizedBox(width: 10),
            Text('Permiso Requerido',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'El acceso a la ubicación fue denegado de forma permanente. Puedes habilitarlo manualmente en la configuración de la app.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ahora no',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Geolocator.openAppSettings();
            },
            child: const Text('Configuración'),
          ),
        ],
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isTablet = mediaQuery.size.width >= 600;

    // viewPadding.bottom contiene la altura de la barra gestual/botones
    final bottomInset = mediaQuery.viewPadding.bottom;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      // 1. Alineamos abajo (Alignment.bottomCenter) en lugar de Center
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 520 : double.infinity,
            minHeight: mediaQuery.size.height * 0.88,
          ),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            // Padding general con buen espacio en el fondo
            padding: EdgeInsets.fromLTRB(
              22,
              28,
              22,
              bottomInset > 0 ? bottomInset + 16 : 28,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── 1. Icono oficial ──
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withOpacity(0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        'assets/iconik.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── 2. Título y descripción ──
                  const Text(
                    'Permiso de Ubicación y Rastreo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Mark V3 requiere acceso a tu posición para coordinar el despacho logístico, entregas de pedidos y registro de visitas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 3. Caja de Divulgación Prominente ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFBAE6FD),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Uso de Ubicación en Operaciones',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Mark V3 utiliza tu ubicación únicamente mientras utilizas la aplicación para registrar paradas de entrega, crear pedidos, validar visitas a clientes y calcular distancias de ruta.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF0C4A6E),
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 4. Beneficios ──
                  _buildBenefitItem(
                    icon: Icons.alt_route_rounded,
                    title: 'Trazabilidad de la Ruta',
                    description:
                        'Registra tus paradas y calcula tiempos de arribo a clientes.',
                  ),
                  const SizedBox(height: 10),
                  _buildBenefitItem(
                    icon: Icons.shield_outlined,
                    title: 'Uso Exclusivo Empresarial',
                    description:
                        'Tus datos están protegidos y solo se usan para fines operativos.',
                  ),
                  const SizedBox(height: 26),

                  // ── 5. Botones ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0284C7),
                            Color(0xFF0369A1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Continuar y Configurar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Ahora no',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF475569)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

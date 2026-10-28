import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/pages/Routes_/routes_page.dart';
import 'package:mark_v3/pages/ServiceStation_/ServiceStationPage.dart';
import 'package:mark_v3/pages/Trackingpage.dart';
import 'package:mark_v3/pages/Vehicles_/vehicles_page.dart';
import 'package:mark_v3/pages/reports_page.dart';
import 'package:mark_v3/pages/tasks_page.dart';
import 'package:mark_v3/pages/Custodia_/custodia_page.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/services/mark_api_client.dart';

class MenuPage extends ConsumerWidget {
  final String idCollaborator;
  final String circulationCardPermission;
  final String taxesPermission;
  final String verificationsPermission;
  final String insurancePermission;
  final String creditPermission;
  final String userId;
  final String additionalPermissions;
  final String inspectionsPermission;
  final String uuid;
  final String idMainAccount;
  final String creationId;

  const MenuPage({
    super.key,
    required this.idCollaborator,
    required this.circulationCardPermission,
    required this.taxesPermission,
    required this.verificationsPermission,
    required this.insurancePermission,
    required this.creditPermission,
    required this.userId,
    required this.inspectionsPermission,
    required this.additionalPermissions,
    required this.uuid,
    required this.idMainAccount,
    required this.creationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 360;

    // Obtener sesión activa para validar roles y permisos (Ronda 133)
    final apiSession = MarkApiClient.instance.currentSession;
    final session = ref.watch(routesProvider).session ?? apiSession;
    final rol = (session?.rol ?? '').trim().toLowerCase();
    final isUsuarioOnly = rol == 'usuario';
    final isPreventa =
        session?.isPreventa == true || rol == 'preventa' || rol == 'vendedor';
    final isChofer =
        rol == 'chofer' || (!isPreventa && !isUsuarioOnly && rol.isNotEmpty);
    final canSeeRutas = !isUsuarioOnly &&
        (session?.permisos.rutas == true ||
            isPreventa ||
            isChofer ||
            (session?.permisos.pedidos ?? false));
    final canSeeTareas = session?.flota.can('tareas', 'ver') ?? true;
    final canSeeReportes = session?.flota.can('reportes', 'ver') ?? true;
    final canManageVehicles =
        (session?.flota.can('vehiculo', 'editar') ?? false) || isUsuarioOnly;
    final canRegisterFuel = !isPreventa &&
        (isChofer || isUsuarioOnly || (session?.flota.can('combustible', 'crear') ?? true));

    // =========================================================================
    // 1. SECCIÓN: GESTIÓN Y MONITOREO DE FLOTA (Rastreo, Vehículos y Tareas)
    // =========================================================================
    final List<Widget> flotaTiles = [
      _buildAppleListTile(
        icon: Icons.satellite_alt_rounded,
        iconGradient: const [
          Color(0xFF0284C7),
          Color(0xFF38BDF8),
        ],
        title: 'Rastreo Satelital',
        subtitle: isUsuarioOnly
            ? 'Localización GPS en vivo de toda la flota'
            : 'Localización GPS en vivo y estado telemático',
        badgeText: 'GPS',
        badgeColor: const Color(0xFFE0F2FE),
        badgeTextColor: const Color(0xFF0369A1),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrackingPage(userId: userId),
            ),
          );
        },
      ),
      _buildAppleListTile(
        icon: Icons.directions_car_rounded,
        iconGradient: const [
          Color(0xFF4F46E5),
          Color(0xFF818CF8),
        ],
        title: isChofer ? 'Mi Vehículo' : 'Mis Vehículos',
        subtitle: isUsuarioOnly
            ? 'Padrón de unidades, ficha técnica y pólizas'
            : 'Ficha técnica, tarjeta, póliza e inspecciones',
        badgeText: 'Flota',
        badgeColor: const Color(0xFFEEF2FF),
        badgeTextColor: const Color(0xFF4338CA),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VehiclesPage(
                circulationCardPermission: circulationCardPermission,
                taxesPermission: taxesPermission,
                inspectionsPermission: inspectionsPermission,
                idCollaborator: idCollaborator,
                verificationsPermission: verificationsPermission,
                insurancePermission: insurancePermission,
                creditPermission: creditPermission,
                idMainAccount: idMainAccount,
                additionalPermissions: additionalPermissions,
                userId: userId,
              ),
            ),
          );
        },
      ),
      if (canSeeTareas)
        _buildAppleListTile(
          icon: Icons.assignment_turned_in_rounded,
          iconGradient: const [
            Color(0xFF0D9488),
            Color(0xFF14B8A6),
          ],
          title: 'Tareas de Flota',
          subtitle: isUsuarioOnly
              ? 'Órdenes de trabajo, revisiones y asignaciones'
              : 'Órdenes de trabajo y revisiones asignadas',
          badgeText: 'Tareas',
          badgeColor: const Color(0xFFCCFBF1),
          badgeTextColor: const Color(0xFF0F766E),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TasksPage(),
              ),
            );
          },
        ),
    ];

    // =========================================================================
    // 2. SECCIÓN: OPERACIÓN Y LOGÍSTICA / REPORTES (Rutas, Combustible, Reportes)
    // =========================================================================
    final List<Widget> operacionTiles = [
      if (canSeeRutas)
        _buildAppleListTile(
          icon: isPreventa ? Icons.storefront_rounded : Icons.alt_route_rounded,
          iconGradient: isPreventa
              ? const [
                  Color(0xFF0284C7),
                  Color(0xFF0369A1),
                ]
              : const [
                  Color(0xFF0369A1),
                  Color(0xFF0284C7),
                ],
          title: isPreventa ? 'Rutas de Preventa' : 'Rutas y Trayectos',
          subtitle: isPreventa
              ? 'Visitas a clientes, catálogo y levantamiento de pedidos'
              : 'Historial de recorridos, paradas y entregas',
          badgeText: isPreventa ? 'Preventa' : 'Rutas',
          badgeColor: const Color(0xFFE0F2FE),
          badgeTextColor: const Color(0xFF0369A1),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RoutesPage(
                  idCollaborator: idCollaborator,
                  idMainAccount: idMainAccount,
                ),
              ),
            );
          },
        ),
      _buildAppleListTile(
        icon: Icons.shield_outlined,
        iconGradient: const [
          Color(0xFF0284C7),
          Color(0xFF38BDF8),
        ],
        title: 'Custodia y Rondines',
        subtitle: 'Servicios de custodia en convoy y rondines de vigilancia',
        badgeText: 'Custodia',
        badgeColor: const Color(0xFFE0F2FE),
        badgeTextColor: const Color(0xFF0369A1),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CustodiaPage(),
            ),
          );
        },
      ),
      if (canRegisterFuel)
        _buildAppleListTile(
          icon: Icons.local_gas_station_rounded,
          iconGradient: const [
            Color(0xFF0891B2),
            Color(0xFF06B6D4),
          ],
          title: 'Reabastecimiento',
          subtitle: isUsuarioOnly
              ? 'Control de carga de combustible'
              : 'Costos de combustible',
          badgeText: 'Combustible',
          badgeColor: const Color(0xFFECFEFF),
          badgeTextColor: const Color(0xFF0E7490),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceStationForm(
                  idMainAccount: idMainAccount,
                  idCollaborator: idCollaborator,
                ),
              ),
            );
          },
        ),
      if (canSeeReportes)
        _buildAppleListTile(
          icon: Icons.insert_chart_rounded,
          iconGradient: const [
            Color(0xFF2563EB),
            Color(0xFF60A5FA),
          ],
          title: 'Reportes Operativos',
          subtitle: 'Rendimiento, distancias, viajes e incidencias',
          badgeText: 'Métricas',
          badgeColor: const Color(0xFFEFF6FF),
          badgeTextColor: const Color(0xFF1D4ED8),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReportsPage(),
              ),
            );
          },
        ),
    ];

    final totalModules = flotaTiles.length + operacionTiles.length;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        // Fondo gris/plata suave estilo iOS System Grouped Background
        backgroundColor: const Color(0xFFF2F4F7),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 14.0 : 18.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Encabezado Estilo Apple (Large Title + Subtítulo Adaptativo) ──
                _buildAnimatedItem(
                  _buildAppleHeader(
                    isUsuarioOnly: isUsuarioOnly,
                    isChofer: isChofer,
                  ),
                  0,
                ),
                const SizedBox(height: 14),

                // ── 2. Hero Card Estilo Apple (Dinamizado por Rol) ───────────
                _buildAnimatedItem(
                  _buildAppleHeroCard(
                    session: session,
                    isUsuarioOnly: isUsuarioOnly,
                    isChofer: isChofer,
                    totalModules: totalModules,
                  ),
                  1,
                ),
                const SizedBox(height: 22),

                // ── 3. Sección Gestión y Monitoreo de Flota ─────────────────
                _buildAnimatedItem(
                  _buildAppleSectionHeader(
                    title: 'GESTIÓN Y MONITOREO DE FLOTA',
                    badge: '${flotaTiles.length} MÓDULOS',
                  ),
                  2,
                ),
                const SizedBox(height: 7),
                _buildAnimatedItem(
                  _buildAppleGroupedCard(
                    children: flotaTiles,
                  ),
                  3,
                ),
                _buildAppleSectionFooter(
                  isUsuarioOnly
                      ? 'Supervisa la ubicación en vivo de las unidades, revisa pólizas y asigna tareas.'
                      : 'Consulta la telemetría de tu unidad, documentación oficial y tareas asignadas.',
                ),
                const SizedBox(height: 20),

                // ── 4. Sección Operación / Logística (Adaptativa por rol) ─────
                if (operacionTiles.isNotEmpty) ...[
                  _buildAnimatedItem(
                    _buildAppleSectionHeader(
                      title: canSeeRutas
                          ? 'LOGÍSTICA Y OPERACIÓN'
                          : 'OPERACIÓN Y REPORTES',
                      badge: '${operacionTiles.length} MÓDULOS',
                    ),
                    4,
                  ),
                  const SizedBox(height: 7),
                  _buildAnimatedItem(
                    _buildAppleGroupedCard(
                      children: operacionTiles,
                    ),
                    5,
                  ),
                  _buildAppleSectionFooter(
                    canSeeRutas
                        ? 'Monitorea el avance de ruta, abastecimiento de combustible e indicadores telemáticos.'
                        : 'Registro de combustible, control de gastos y análisis de desempeño de la flota.',
                  ),
                ],

                // Espacio inferior para evitar solapamiento con la barra de navegación flotante
                const SizedBox(height: 95),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. ENCABEZADO APPLE (LARGE TITLE + SUBTÍTULO ADAPTATIVO POR ROL) ────────
  Widget _buildAppleHeader({
    required bool isUsuarioOnly,
    required bool isChofer,
  }) {
    final subtitle = isUsuarioOnly
        ? 'Supervisión de flota y telemetría'
        : (isChofer
            ? 'Centro de operación y chofer'
            : 'Centro de operaciones y flota');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menú',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.6,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w400,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 2. HERO CARD APPLE DINAMIZADO SEGÚN EL ROL (CONTROL CENTER / WALLET) ──
  Widget _buildAppleHeroCard({
    required DriverSession? session,
    required bool isUsuarioOnly,
    required bool isChofer,
    required int totalModules,
  }) {
    // Configuración visual y descriptiva según el rol del usuario
    final IconData heroIcon;
    final String tagText;
    final String titleText;
    final String descriptionText;
    final String rolePillText;
    final IconData rolePillIcon;

    if (isUsuarioOnly) {
      heroIcon = Icons.local_shipping_rounded;
      tagText = 'SUPERVISIÓN Y CONTROL';
      titleText = 'Control Central de Flota';
      descriptionText =
          'Supervisión telemática en tiempo real, administración de unidades, combustible y tareas de mantenimiento.';
      rolePillText = 'Supervisor';
      rolePillIcon = Icons.admin_panel_settings_rounded;
    } else if (isChofer) {
      heroIcon = Icons.alt_route_rounded;
      tagText = 'OPERACIÓN EN RUTA';
      titleText = 'Mi Jornada y Unidad';
      descriptionText =
          'Gestión de rutas de reparto, abastecimiento de combustible y telemetría de tu unidad asignada.';
      rolePillText = 'Chofer';
      rolePillIcon = Icons.badge_rounded;
    } else {
      // Preventa u otro perfil comercial
      heroIcon = Icons.storefront_rounded;
      tagText = 'OPERACIÓN COMERCIAL';
      titleText = 'Gestión Comercial';
      descriptionText =
          'Levantamiento de pedidos, prospección de clientes y catálogo de productos disponibles.';
      rolePillText = 'Preventa';
      rolePillIcon = Icons.shopping_bag_rounded;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A1E34),
            Color(0xFF0E3259),
            Color(0xFF0284C7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Círculos difusos orgánicos estilo iOS
            Positioned(
              top: -35,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38BDF8).withOpacity(0.12),
                ),
              ),
            ),

            // Contenido principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Squircle translúcido para el ícono principal adaptativo
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          heroIcon,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  tagText,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFBAE6FD)
                                        .withOpacity(0.95),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF38BDF8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'MARK v3',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.85),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              titleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    descriptionText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withOpacity(0.90),
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Píldoras de métricas estilo Apple adaptativas
                  Row(
                    children: [
                      _buildAppleStatCapsule(
                        icon: Icons.gps_fixed_rounded,
                        label: isUsuarioOnly ? 'GPS Flota' : 'GPS Activo',
                      ),
                      const SizedBox(width: 7),
                      _buildAppleStatCapsule(
                        icon: Icons.grid_view_rounded,
                        label: '$totalModules Módulos',
                      ),
                      const SizedBox(width: 7),
                      _buildAppleStatCapsule(
                        icon: rolePillIcon,
                        label: rolePillText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cápsula de estadística estilo Apple
  Widget _buildAppleStatCapsule({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.20),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFFBAE6FD)),
          const SizedBox(width: 4.5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. ENCABEZADO DE SECCIÓN APPLE ──────────────────────────────────────────
  Widget _buildAppleSectionHeader({
    required String title,
    required String badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0).withOpacity(0.7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Pie de sección al estilo Apple HIG
  Widget _buildAppleSectionFooter(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 6, right: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF94A3B8),
          height: 1.25,
        ),
      ),
    );
  }

  // ── 4. GRUPO INSET ESTILO APPLE (ROUNDED CARD CONTENEDOR) ───────────────────
  Widget _buildAppleGroupedCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0).withOpacity(0.85),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  // ── 5. FILA DE LISTA ESTILO APPLE (SQUIRCLE BADGE + CHEVRON) ────────────────
  Widget _buildAppleListTile({
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFF0284C7).withOpacity(0.06),
        highlightColor: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Ícono Squircle estilo iOS con degradado azul
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: iconGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: iconGradient.first.withOpacity(0.28),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Textos del elemento
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badge opcional (ej: "GPS", "Control")
                  if (badgeText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor ?? const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: badgeTextColor ?? const Color(0xFF475569),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(width: 10),

                  // Chevron estilo iOS (Disclosure indicator)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 20,
                  ),
                ],
              ),
            ),
            // Línea divisoria hairline identada estilo iOS
            if (!isLast)
              const Divider(
                height: 1,
                thickness: 0.6,
                indent: 66,
                endIndent: 0,
                color: Color(0xFFF1F5F9),
              ),
          ],
        ),
      ),
    );
  }

  // ── 7. ANIMACIÓN SUAVE STAGGERED ─────────────────────────────────────────────
  Widget _buildAnimatedItem(Widget child, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 260 + (index * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1.0 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

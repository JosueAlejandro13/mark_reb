import 'package:flutter/material.dart';
import 'package:mark_v3/pages/MyVehicle_/MyVehiclePage.dart';
import 'package:mark_v3/pages/Routes_/routes_page.dart';
import 'package:mark_v3/pages/ServiceStation_/ServiceStationPage.dart';
import 'package:mark_v3/pages/Trackingpage.dart';
import 'package:mark_v3/pages/Vehicles_/vehicles_page.dart';

class MenuPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 250, 250, 250),
            Color.fromARGB(255, 205, 240, 255),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header superior del Menú
                _buildHeader(),
                const SizedBox(height: 14),

                // Hero Banner Operativo
                _buildHeroBanner(),
                const SizedBox(height: 20),

                // Sección 1: Monitoreo y Logística
                _buildSectionHeader(
                  title: 'TELEMETRÍA Y LOGÍSTICA',
                  subtitle: 'Seguimiento de unidades y gestión en ruta',
                  badge: 'OPERACIÓN',
                  badgeColor: const Color(0xFF0284C7),
                  badgeBg: const Color(0xFFE0F2FE),
                ),
                const SizedBox(height: 10),

                // 1. Rastreo Satelital
                _buildAnimatedItem(
                  _buildActionMenuCard(
                    icon: Icons.satellite_alt_rounded,
                    iconColor: const Color(0xFF0284C7),
                    iconBg: const Color(0xFFE0F2FE),
                    title: 'Rastreo Satelital',
                    subtitle: 'Monitoreo GPS en tiempo real y ubicación de unidades',
                    pillText: 'GPS ACTIVO',
                    pillColor: const Color(0xFF0284C7),
                    pillBg: const Color(0xFFE0F2FE),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackingPage(userId: userId),
                        ),
                      );
                    },
                  ),
                  0,
                ),
                const SizedBox(height: 10),

                // 2. Rutas y Trayectos
                _buildAnimatedItem(
                  _buildActionMenuCard(
                    icon: Icons.alt_route_rounded,
                    iconColor: const Color(0xFFEA580C),
                    iconBg: const Color(0xFFFFF7ED),
                    title: 'Rutas y Trayectos',
                    subtitle: 'Planificación, historial de navegación y recorridos',
                    pillText: 'RUTAS',
                    pillColor: const Color(0xFFEA580C),
                    pillBg: const Color(0xFFFFF7ED),
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
                  1,
                ),
                const SizedBox(height: 10),

                // 3. Reabastecimiento de Combustible
                _buildAnimatedItem(
                  _buildActionMenuCard(
                    icon: Icons.local_gas_station_rounded,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFFFEF3C7),
                    title: 'Reabastecimiento',
                    subtitle: 'Registro de carga de combustible, litros y precios',
                    pillText: 'COMBUSTIBLE',
                    pillColor: const Color(0xFFD97706),
                    pillBg: const Color(0xFFFEF3C7),
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
                  2,
                ),
                const SizedBox(height: 20),

                // Sección 2: Gestión de Flota y Vehículos
                _buildSectionHeader(
                  title: 'GESTIÓN DE VEHÍCULOS',
                  subtitle: 'Control vehicular, fichas técnicas y permisos',
                  badge: 'FLOTA',
                  badgeColor: const Color(0xFF4F46E5),
                  badgeBg: const Color(0xFFEEF2FF),
                ),
                const SizedBox(height: 10),

                // 4. Mi Vehículo
                _buildAnimatedItem(
                  _buildActionMenuCard(
                    icon: Icons.directions_car_rounded,
                    iconColor: const Color(0xFF0886B5),
                    iconBg: const Color(0xFFE0F2FE),
                    title: 'Mi Vehículo',
                    subtitle: 'Ficha técnica asignada, estatus y mantenimiento',
                    pillText: 'ASIGNADO',
                    pillColor: const Color(0xFF0886B5),
                    pillBg: const Color(0xFFE0F2FE),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyVehiclePage(
                            idCollaborator: idCollaborator,
                            idMainAccount: idMainAccount,
                            inspectionsPermission: inspectionsPermission,
                            userId: userId,
                          ),
                        ),
                      );
                    },
                  ),
                  3,
                ),
                const SizedBox(height: 10),

                // 5. Administrar Vehículos
                _buildAnimatedItem(
                  _buildActionMenuCard(
                    icon: Icons.airport_shuttle_rounded,
                    iconColor: const Color(0xFF4F46E5),
                    iconBg: const Color(0xFFEEF2FF),
                    title: 'Administrar Vehículos',
                    subtitle: 'Gestión integral de flota, tarjetas y verificaciones',
                    pillText: 'CONTROL',
                    pillColor: const Color(0xFF4F46E5),
                    pillBg: const Color(0xFFEEF2FF),
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
                  4,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HEADER SUPERIOR ---
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menú Principal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Módulos de logística, flota y control',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ), 
      ],
    );
  }

  // --- HERO BANNER OPERATIVO ---
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F2B48),
            Color(0xFF0886B5),
            Color(0xFF0369A1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0886B5).withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Círculos decorativos
            Positioned(
              top: -30,
              right: -25,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -20,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),

            // Contenido del Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.hub_rounded,
                      color: Colors.white,
                      size: 24,
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
                              'CENTRO OPERATIVO',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withOpacity(0.85),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Módulos y Gestión de Campo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Acceso rápido a telemetría GPS, recorridos, combustible y unidades.',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ENCABEZADO DE SECCIÓN ---
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required Color badgeBg,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: badgeColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  // --- TARJETA DE ACCIÓN DE MENÚ ---
  Widget _buildActionMenuCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String pillText,
    required Color pillColor,
    required Color pillBg,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                // Squircle Icon Container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                ),
                const SizedBox(width: 12),

                // Textos del ítem
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: pillBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pillText,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: pillColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chevron
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ANIMACIÓN DE ENTRADA STAGGERED ---
  Widget _buildAnimatedItem(Widget child, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index * 70)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 16 * (1.0 - value)),
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

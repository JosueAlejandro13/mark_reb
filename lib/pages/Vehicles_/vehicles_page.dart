import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/vehicle_model.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/VehicleErrorPage.dart';
import 'package:mark_v3/pages/Vehicles_/VehicleDetailPage.dart';
import 'package:mark_v3/providers/Vehicles_/vehicles_provider.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';

/// Pantalla de Vehículos Registrados — Diseño Apple Inset Grouped Ejecutivo
class VehiclesPage extends ConsumerStatefulWidget {
  final String userId;
  final String circulationCardPermission;
  final String taxesPermission;
  final String verificationsPermission;
  final String insurancePermission;
  final String creditPermission;
  final String additionalPermissions;
  final String idMainAccount;
  final String inspectionsPermission;
  final String idCollaborator;

  const VehiclesPage({
    super.key,
    required this.userId,
    required this.circulationCardPermission,
    required this.taxesPermission,
    required this.verificationsPermission,
    required this.insurancePermission,
    required this.creditPermission,
    required this.additionalPermissions,
    required this.idMainAccount,
    required this.inspectionsPermission,
    required this.idCollaborator,
  });

  @override
  ConsumerState<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends ConsumerState<VehiclesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(vehiclesProvider.notifier).loadVehicles(
            userId: widget.userId,
            idMainAccount: widget.idMainAccount,
          );
    });
  }

  void _navigateToDetail(Vehicle vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleDetailPage(
          vehicle: vehicle.toMap(),
          additionalPermissions: widget.additionalPermissions,
          userId: widget.userId,
          circulationCardPermission: widget.circulationCardPermission,
          taxesPermission: widget.taxesPermission,
          verificationsPermission: widget.verificationsPermission,
          insurancePermission: widget.insurancePermission,
          creditPermission: widget.creditPermission,
          idMainAccount: widget.idMainAccount,
          inspectionsPermission: widget.inspectionsPermission,
          idCollaborator: widget.idCollaborator,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehiclesProvider);

    // Manejo de errores de conexión / servidor / error de vehículos
    if (state.isConnectionError) {
      return ConnectionErrorPage(
        onRetry: () => ref.read(vehiclesProvider.notifier).loadVehicles(
              userId: widget.userId,
              idMainAccount: widget.idMainAccount,
            ),
      );
    }

    if (state.isServerError) {
      return ServerErrorPage(
        onRetry: () => ref.read(vehiclesProvider.notifier).loadVehicles(
              userId: widget.userId,
              idMainAccount: widget.idMainAccount,
            ),
      );
    }

    if (state.isUnexpectedError) {
      return VehicleErrorPage(
        onRetry: () => ref.read(vehiclesProvider.notifier).loadVehicles(
              userId: widget.userId,
              idMainAccount: widget.idMainAccount,
            ),
      );
    }

    if (!state.isLoading && state.vehicles.isEmpty) {
      return VehicleErrorPage(
        onRetry: () => ref.read(vehiclesProvider.notifier).loadVehicles(
              userId: widget.userId,
              idMainAccount: widget.idMainAccount,
            ),
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor:
            const Color(0xFFF2F4F7), // iOS System Grouped Background
        body: SafeArea(
          child: state.isLoading
              ? AppSkeleton.vehiclesList()
              : RefreshIndicator(
                  color: const Color(0xFF0284C7),
                  backgroundColor: Colors.white,
                  onRefresh: () => ref.read(vehiclesProvider.notifier).refresh(
                        userId: widget.userId,
                        idMainAccount: widget.idMainAccount,
                      ),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 14.0 : 18.0,
                      vertical: 10.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. Encabezado Apple ─────────────────────────────
                        _buildAnimatedItem(
                          _buildAppleHeader(context),
                          0,
                        ),
                        const SizedBox(height: 16),

                        // ── 2. Título de Sección ────────────────────────────
                        _buildAnimatedItem(
                          _buildSectionTitle('UNIDADES REGISTRADAS'),
                          1,
                        ),
                        const SizedBox(height: 8),

                        ...state.vehicles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final vehicle = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildAnimatedItem(
                              _buildVehicleCard(vehicle),
                              2 + index,
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ── ENCABEZADO APPLE DESIGN (SIN SOMBRAS) ──────────────────────────────────
  Widget _buildAppleHeader(BuildContext context) {
    return Row(
      children: [
        if (Navigator.canPop(context))
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF0F172A),
                    size: 15,
                  ),
                ),
              ),
            ),
          ),
        if (Navigator.canPop(context)) const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mis Vehículos',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Flota y unidades asignadas para gestión',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── TÍTULO DE SECCIÓN INSET GROUPED ─────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ── TARJETA DE VEHÍCULO (APPLE DESIGN PREMIUM) ─────────────────────────────
  Widget _buildVehicleCard(Vehicle vehicle) {
    final displayName = vehicle.make.isNotEmpty || vehicle.model.isNotEmpty
        ? '${vehicle.make} ${vehicle.model}'.trim()
        : (vehicle.placas.isNotEmpty ? vehicle.placas : 'Vehículo');

    final metaSubtitle = [
      if (vehicle.year.isNotEmpty) vehicle.year,
      if (vehicle.color.isNotEmpty) vehicle.color,
      if (vehicle.tipoVehiculoNombre.isNotEmpty) vehicle.tipoVehiculoNombre,
    ].join(' • ');

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _navigateToDetail(vehicle),
          highlightColor: const Color(0xFFF8FAFC),
          splashColor: const Color(0xFF0284C7).withOpacity(0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar / Imagen del Vehículo (con foto de API o icono por defecto)
                    _buildVehicleAvatar(vehicle),
                    const SizedBox(width: 14),

                    // Título y Subtítulo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            metaSubtitle.isNotEmpty
                                ? metaSubtitle
                                : 'Detalles de la unidad',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Placa Badge (Más limpio y con menos bordes)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        vehicle.placas.isNotEmpty ? vehicle.placas : 'S/P',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Datos secundarios (VIN, Dept) - Sin bordes pesados
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildVehicleDataChip(
                        icon: Icons.pin_outlined,
                        label: 'VIN',
                        value: vehicle.vin.isNotEmpty ? vehicle.vin : 'N/A',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildVehicleDataChip(
                        icon: Icons.business_rounded,
                        label: 'DEPTO',
                        value: vehicle.dep.isNotEmpty ? vehicle.dep : 'General',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Footer Apple List Tile Style
              const Divider(
                height: 1,
                thickness: 0.6,
                color: Color(0xFFF1F5F9),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ver detalles y gestión vehicular',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: const Color(0xFF0284C7).withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleAvatar(Vehicle vehicle) {
    final photoUrl = vehicle.photo.trim();
    final hasPhoto = photoUrl.isNotEmpty;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: hasPhoto ? const Color(0xFFF8FAFC) : null,
        gradient: hasPhoto
            ? null
            : const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: hasPhoto ? const Color(0xFFE2E8F0) : Colors.transparent,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: hasPhoto
                ? const Color(0xFF0F172A).withOpacity(0.06)
                : const Color(0xFF0284C7).withOpacity(0.28),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: hasPhoto
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.directions_car_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                },
              )
            : const Center(
                child: Icon(
                  Icons.directions_car_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
      ),
    );
  }

  Widget _buildVehicleDataChip(
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ESTADO VACÍO ESTILO APPLE ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Icon(
                Icons.directions_car_outlined,
                size: 36,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay vehículos registrados',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No se encontraron unidades asignadas a esta cuenta o usuario.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => ref.read(vehiclesProvider.notifier).loadVehicles(
                  userId: widget.userId,
                  idMainAccount: widget.idMainAccount,
                ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Recargar',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ANIMACIÓN STAGGERED ESTILO APPLE ────────────────────────────────────────
  Widget _buildAnimatedItem(Widget child, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 260 + (index * 35)),
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

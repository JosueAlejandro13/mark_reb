import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/vehicle_model.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/MyVehicleErrorPage.dart';
import 'package:mark_v3/pages/MyVehicle_/EditVehiclePage.dart';
import 'package:mark_v3/providers/Vehicles_/my_vehicle_provider.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';

export 'package:mark_v3/models/Vehicles_/vehicle_model.dart';

/// Pantalla Principal "Mi Vehículo" — Diseño Apple iOS (Inset Grouped & Showcase Hero)
class MyVehiclePage extends ConsumerStatefulWidget {
  final String idCollaborator;
  final String userId;
  final String idMainAccount;
  final String inspectionsPermission;
  final String? initialVehicleId;

  const MyVehiclePage({
    super.key,
    required this.idCollaborator,
    required this.inspectionsPermission,
    required this.idMainAccount,
    required this.userId,
    this.initialVehicleId,
  });

  @override
  ConsumerState<MyVehiclePage> createState() => _MyVehiclePageState();
}

class _MyVehiclePageState extends ConsumerState<MyVehiclePage> {
  int _selectedVehicleIndex = 0;
  bool _hasAppliedInitialVehicle = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(myVehicleProvider.notifier).loadVehicles(widget.idCollaborator);
    });
  }

  bool get _canEditVehicle =>
      MarkApiClient.instance.flota.can('vehiculo', 'editar');

  void _editVehicle(Vehicle vehicle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditVehiclePage(
          vehicle: vehicle,
          idCollaborator: widget.idCollaborator,
          userId: widget.userId,
          idMainAccount: widget.idMainAccount,
        ),
      ),
    );

    if (mounted) {
      ref.read(myVehicleProvider.notifier).loadVehicles(widget.idCollaborator);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'activo':
        return const Color(0xFF047857);
      case 'inactivo':
        return const Color(0xFFDC2626);
      case 'en taller':
        return const Color(0xFFD97706);
      case 'fuera de servicio':
        return const Color(0xFF475569);
      case 'vendido':
        return const Color(0xFFCA8A04);
      case 'corralon':
        return const Color(0xFF78350F);
      case 'robo':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getStatusBg(String status) {
    switch (status.toLowerCase()) {
      case 'activo':
        return const Color(0xFFECFDF5);
      case 'inactivo':
        return const Color(0xFFFEF2F2);
      case 'en taller':
        return const Color(0xFFFFFBEB);
      case 'fuera de servicio':
        return const Color(0xFFF1F5F9);
      case 'vendido':
        return const Color(0xFFFEFCE8);
      case 'corralon':
        return const Color(0xFFFEF3C7);
      case 'robo':
        return const Color(0xFFEFF6FF);
      default:
        return const Color(0xFFF8FAFC);
    }
  }

  Color _getStatusBorder(String status) {
    switch (status.toLowerCase()) {
      case 'activo':
        return const Color(0xFFA7F3D0);
      case 'inactivo':
        return const Color(0xFFFECACA);
      case 'en taller':
        return const Color(0xFFFDE68A);
      case 'fuera de servicio':
        return const Color(0xFFE2E8F0);
      case 'vendido':
        return const Color(0xFFFEF08A);
      case 'corralon':
        return const Color(0xFFFDE68A);
      case 'robo':
        return const Color(0xFFBFDBFE);
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myVehicleProvider);

    // Manejo de errores de conexión/servidor
    if (state.isConnectionError) {
      return ConnectionErrorPage(
        onRetry: () => ref
            .read(myVehicleProvider.notifier)
            .loadVehicles(widget.idCollaborator),
      );
    }

    if (state.isServerError) {
      return ServerErrorPage(
        onRetry: () => ref
            .read(myVehicleProvider.notifier)
            .loadVehicles(widget.idCollaborator),
      );
    }

    if (state.isUnexpectedError) {
      return MyVehicleErrorPage(
        onRetry: () => ref
            .read(myVehicleProvider.notifier)
            .loadVehicles(widget.idCollaborator),
      );
    }

    if (!state.isLoading && state.vehicles.isEmpty) {
      return MyVehicleErrorPage(
        onRetry: () => ref
            .read(myVehicleProvider.notifier)
            .loadVehicles(widget.idCollaborator),
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    if (state.vehicles.isNotEmpty) {
      if (!_hasAppliedInitialVehicle && widget.initialVehicleId != null) {
        final idx = state.vehicles.indexWhere((v) =>
            v.id.toString() == widget.initialVehicleId ||
            v.economic.toLowerCase() == widget.initialVehicleId?.toLowerCase());
        if (idx != -1) {
          _selectedVehicleIndex = idx;
        }
        _hasAppliedInitialVehicle = true;
      }
      if (_selectedVehicleIndex >= state.vehicles.length) {
        _selectedVehicleIndex = 0;
      }
    }

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F7),
        body: SafeArea(
          child: state.isLoading
              ? AppSkeleton.vehicle(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12.0 : 16.0,
                    vertical: 8.0,
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF0284C7),
                  backgroundColor: Colors.white,
                  onRefresh: () => ref
                      .read(myVehicleProvider.notifier)
                      .refresh(widget.idCollaborator),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12.0 : 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header superior estilo Apple
                        _buildHeader(context),
                        const SizedBox(height: 14),
                        if (state.vehicles.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _buildVehicleShowcase(
                              state.vehicles[_selectedVehicleIndex],
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // --- HEADER SUPERIOR ESTILO APPLE ---
  Widget _buildHeader(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final isDetailMode = widget.initialVehicleId != null;

    return Row(
      children: [
        if (canPop) ...[
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).maybePop(),
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
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDetailMode ? 'Ficha Técnica' : 'Mi Vehículo',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                isDetailMode
                    ? 'Especificaciones técnicas y estado de la unidad'
                    : 'Detalles técnicos y especificaciones de la unidad',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SHOWCASE COMPLETO DEL VEHÍCULO ESTILO APPLE ---
  Widget _buildVehicleShowcase(Vehicle vehicle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HERO SHOWCASE CARD
        _buildHeroSection(vehicle),
        const SizedBox(height: 16),

        // 2. SECCIONES INSET GROUPED DE ESPECIFICACIONES
        _buildSectionTitle('IDENTIFICACIÓN Y REGISTRO'),
        _buildAppleGroupContainer(
          children: [
            _buildDetailRow(
              icon: Icons.tag_rounded,
              iconGradient: const [
                Color(0xFF2563EB),
                Color(0xFF3B82F6)
              ], // Blue
              label: 'Placas',
              value: vehicle.placas.isNotEmpty ? vehicle.placas : 'Sin placas',
            ),
            _buildDetailRow(
              icon: Icons.numbers_rounded,
              iconGradient: const [
                Color(0xFF0F172A),
                Color(0xFF334155)
              ], // Slate
              label: 'VIN / Serie',
              value: vehicle.vin.isNotEmpty ? vehicle.vin : 'No registrado',
            ),
            _buildDetailRow(
              icon: Icons.directions_car_outlined,
              iconGradient: const [
                Color(0xFF0891B2),
                Color(0xFF06B6D4)
              ], // Cyan
              label: 'Tipo de Vehículo',
              value: vehicle.tipoVehiculoNombre.isNotEmpty
                  ? vehicle.tipoVehiculoNombre
                  : 'No especificado',
            ),
            _buildDetailRow(
              icon: Icons.palette_outlined,
              iconGradient: const [
                Color(0xFF1E3A8A),
                Color(0xFF2563EB)
              ], // Indigo
              label: 'Color de Unidad',
              value:
                  vehicle.color.isNotEmpty ? vehicle.color : 'No especificado',
              isLast: true,
            ),
          ],
        ),

        // 3. SUBGRUPO: MOTOR Y RENDIMIENTO
        _buildSectionTitle('MOTOR Y RENDIMIENTO'),
        _buildAppleGroupContainer(
          children: [
            _buildDetailRow(
              icon: Icons.speed_rounded,
              iconGradient: const [
                Color(0xFF059669),
                Color(0xFF10B981)
              ], // Emerald
              label: 'Odómetro',
              value: vehicle.odom.isNotEmpty ? '${vehicle.odom} km' : '0 km',
            ),
            _buildDetailRow(
              icon: Icons.tune_rounded,
              iconGradient: const [
                Color(0xFFD97706),
                Color(0xFFF59E0B)
              ], // Amber
              label: 'Cilindrada',
              value: vehicle.cilindrada.isNotEmpty ? vehicle.cilindrada : 'N/A',
            ),
            _buildDetailRow(
              icon: Icons.view_column_outlined,
              iconGradient: const [
                Color(0xFFEA580C),
                Color(0xFFF97316)
              ], // Orange
              label: 'N° de Cilindros',
              value: vehicle.nCilindros.isNotEmpty ? vehicle.nCilindros : 'N/A',
            ),
            _buildDetailRow(
              icon: Icons.calendar_today_outlined,
              iconGradient: const [
                Color(0xFF0284C7),
                Color(0xFF38BDF8)
              ], // Light Sky Blue
              label: 'Año Modelo',
              value: vehicle.year.isNotEmpty ? vehicle.year : 'N/A',
              isLast: true,
            ),
          ],
        ),

        // 4. SUBGRUPO: COMBUSTIBLE Y CONDICIÓN
        _buildSectionTitle('COMBUSTIBLE Y CONDICIÓN'),
        _buildAppleGroupContainer(
          children: [
            _buildDetailRow(
              icon: Icons.local_gas_station_outlined,
              iconGradient: const [Color(0xFFDC2626), Color(0xFFEF4444)], // Red
              label: 'Combustible',
              value: vehicle.tipoCombustibleNombre.isNotEmpty
                  ? vehicle.tipoCombustibleNombre
                  : 'No definido',
            ),
            _buildDetailRow(
              icon: Icons.opacity_rounded,
              iconGradient: const [
                Color(0xFF0D9488),
                Color(0xFF14B8A6)
              ], // Teal
              label: 'Capacidad del Tanque',
              value: vehicle.capacidadTanque.isNotEmpty
                  ? '${vehicle.capacidadTanque} L'
                  : 'N/A',
            ),
            _buildDetailRow(
              icon: Icons.trending_up_rounded,
              iconGradient: const [
                Color(0xFF1D4ED8),
                Color(0xFF3B82F6)
              ], // Royal Blue
              label: 'Promedio de Consumo',
              value:
                  vehicle.promConsumo.isNotEmpty ? vehicle.promConsumo : 'N/A',
            ),
            _buildDetailRow(
              icon: Icons.verified_outlined,
              iconGradient: const [
                Color(0xFF7C3AED),
                Color(0xFF8B5CF6)
              ], // Violet
              label: 'Estado General',
              value: vehicle.Estado.isNotEmpty ? vehicle.Estado : 'N/A',
              isLast: true,
            ),
          ],
        ),
      ],
    );
  }

  // --- HERO HEADER DEL VEHÍCULO ESTILO APPLE ---
  Widget _buildHeroSection(Vehicle vehicle) {
    final statusColor = _getStatusColor(vehicle.Status);
    final statusBg = _getStatusBg(vehicle.Status);
    final statusBorder = _getStatusBorder(vehicle.Status);
    final canEditVehicle =
        _canEditVehicle || vehicle.raw['puedeEditar'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Título a la izquierda, Estado dinámico a la derecha
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.make} ${vehicle.model}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${vehicle.year} · ${vehicle.tipoVehiculoNombre.isNotEmpty ? vehicle.tipoVehiculoNombre : "Vehículo"}',
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.5,
                      height: 6.5,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5.5),
                    Text(
                      vehicle.Status.isNotEmpty
                          ? vehicle.Status
                          : 'Desconocido',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Escenario de presentación con pedestal y sombra ambiental
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFF1F5F9),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 16,
                  child: Container(
                    width: 180,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.all(Radius.elliptical(180, 20)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.09),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: vehicle.photo.trim().isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _showVehicleImagePreview(
                              context,
                              imageUrl: vehicle.photo.trim(),
                              title: '${vehicle.make} ${vehicle.model}'.trim(),
                              plates: vehicle.placas,
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              vehicle.photo.trim(),
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/car.png',
                                  fit: BoxFit.contain,
                                );
                              },
                            ),
                          ),
                        )
                      : Image.asset(
                          'assets/car.png',
                          fit: BoxFit.contain,
                        ),
                ),
                if (vehicle.photo.trim().isNotEmpty)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () {
                        _showVehicleImagePreview(
                          context,
                          imageUrl: vehicle.photo.trim(),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_in_rounded,
                              size: 14,
                              color: Color(0xFF0284C7),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Ampliar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Botón de acción rápida estilo Apple (Editar)
          if (canEditVehicle) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => _editVehicle(vehicle),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Editar',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- FILA DE ESPECIFICACIÓN SIMÉTRICA ESTILO APPLE SETTINGS ---
  Widget _buildDetailRow({
    required IconData icon,
    required List<Color> iconGradient,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
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
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 5,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 0.6,
            indent: 48,
            endIndent: 0,
            color: Color(0xFFF1F5F9),
          ),
      ],
    );
  }

  // --- TÍTULO DE SECCIÓN INSET GROUPED ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
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

  // --- CONTENEDOR INSET GROUPED ESTILO APPLE ---
  Widget _buildAppleGroupContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // --- ESTADO VACÍO ESTILO APPLE ---
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              size: 34,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No se encontró ningún vehículo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Verifica que tengas una unidad vehicular asignada en la plataforma.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => ref
                  .read(myVehicleProvider.notifier)
                  .loadVehicles(widget.idCollaborator),
              icon: const Icon(Icons.refresh_rounded,
                  size: 16, color: Colors.white),
              label: const Text(
                'Recargar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVehicleImagePreview(
    BuildContext context, {
    required String imageUrl,
    String? title,
    String? plates,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Container(
                  color: Colors.black87,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.90,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.5),
                      child: InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Padding(
                              padding: EdgeInsets.all(40.0),
                              child: Center(
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                size: 48,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

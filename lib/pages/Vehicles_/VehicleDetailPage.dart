import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/pages/Vehicles_/CirculationCardPage%20.dart';
import 'package:mark_v3/pages/Vehicles_/CreditPage.dart';
import 'package:mark_v3/pages/Vehicles_/InsurancePage.dart';
import 'package:mark_v3/pages/MaintenancePage.dart';
import 'package:mark_v3/pages/Vehicles_/TaxesPage.dart';
import 'package:mark_v3/pages/Vehicles_/VerificationsPage.dart';
import 'package:mark_v3/pages/inspeccion/SeleccionPlantillasPage.dart';
import 'package:mark_v3/pages/MyVehicle_/MyVehiclePage.dart';
import 'package:mark_v3/pages/ServiceStation_/ServiceStationPage.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/apple_section_title.dart';
import 'package:mark_v3/widgets/vehicle_report_sheets.dart';

// Autor: Josue Hernandez
class VehicleDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
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

  const VehicleDetailPage({
    super.key,
    required this.vehicle,
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
  ConsumerState<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends ConsumerState<VehicleDetailPage> {
  late int circulationPermissionValue;
  late int taxesPermissionValue;
  late int verificationsPermissionValue;
  late int insurancePermissionValue;
  late int creditPermissionValue;
  late int inspectionsPermission;

  @override
  void initState() {
    super.initState();
    circulationPermissionValue = int.parse(widget.circulationCardPermission);
    taxesPermissionValue = int.parse(widget.taxesPermission);
    verificationsPermissionValue = int.parse(widget.verificationsPermission);
    insurancePermissionValue = int.parse(widget.insurancePermission);
    creditPermissionValue = int.parse(widget.creditPermission);
    inspectionsPermission = int.parse(widget.inspectionsPermission);

    debugPrint('Permisos recibidos:');
    debugPrint('Tarjeta de Circulación: $circulationPermissionValue');
    debugPrint('Impuestos: $taxesPermissionValue');
    debugPrint('Verificaciones: $verificationsPermissionValue');
    debugPrint('Vehicle being passed: ${widget.vehicle}');
    debugPrint('Inspeccionar: $inspectionsPermission');
    debugPrint('Seguro: $insurancePermissionValue');
  }

  int get _idVehic =>
      int.tryParse((widget.vehicle['idVehic'] ?? widget.vehicle['id'] ?? '0')
          .toString()) ??
      0;

  String get _vehicleName {
    final make = widget.vehicle['make']?.toString() ??
        widget.vehicle['marca']?.toString() ??
        '';
    final model = widget.vehicle['model']?.toString() ??
        widget.vehicle['modelo']?.toString() ??
        '';
    final eco = widget.vehicle['economic']?.toString() ??
        widget.vehicle['eco']?.toString() ??
        widget.vehicle['economico']?.toString() ??
        '';
    if (make.isNotEmpty || model.isNotEmpty) {
      return '$make $model'.trim();
    }
    if (eco.isNotEmpty) return 'Unidad $eco';
    return 'Vehículo';
  }

  String get _vehiclePlates {
    return widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'Sin Placas';
  }

  String get _vehiclePhotoUrl {
    final rawPhoto = (widget.vehicle['photo'] ??
            widget.vehicle['foto'] ??
            widget.vehicle['rawFoto'] ??
            '')
        .toString()
        .trim();
    if (rawPhoto.isEmpty) return '';
    if (rawPhoto.startsWith('http://') || rawPhoto.startsWith('https://')) {
      return rawPhoto;
    }
    return MarkApiClient.instance.resolveAssetUrl(rawPhoto);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7), // iOS System Grouped Background
      body: SafeArea(
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
              _buildAppleHeader(context),
              const SizedBox(height: 24),

              // 1. ACCIONES RÁPIDAS
              _buildSectionTitle('ACCIONES RÁPIDAS'),
              const SizedBox(height: 8),
              _buildQuickActionsGroup(),
              const SizedBox(height: 24),

              // 2. FALLAS E INCIDENCIAS (tipo: problema y tipo: incidenciaVehiculo)
              _buildSectionTitle('FALLAS E INCIDENCIAS'),
              const SizedBox(height: 8),
              _buildFailuresAndIncidentsGroup(),
              const SizedBox(height: 24),

              // 3. GESTIÓN VEHICULAR
              if (_hasAnyManagementPermission()) ...[
                _buildSectionTitle('GESTIÓN VEHICULAR'),
                const SizedBox(height: 8),
                _buildManagementGroup(),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detalles de Unidad',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '$_vehicleName · ${_vehiclePlates.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
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

  Widget _buildSectionTitle(String title) {
    return AppleSectionTitle(
      title,
      padding: const EdgeInsets.only(left: 4, bottom: 2),
    );
  }

  Widget _buildQuickActionsGroup() {
    List<Widget> children = [];

    children.add(_buildCupertinoListTile(
      title: 'Ficha Técnica',
      subtitle: 'Información general, odómetro y especificaciones',
      icon: Icons.description_outlined,
      iconGradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)], // Sky blue
      onTap: () => _handleMenuSelection('Ficha Técnica'),
    ));

    if (_canCreateInspections) {
      children.add(_buildCupertinoListTile(
        title: 'Inspeccionar',
        subtitle: 'Inspección de seguridad con fotos y checklist',
        icon: Icons.search_outlined,
        iconGradient: const [Color(0xFF0891B2), Color(0xFF06B6D4)], // Cyan
        onTap: () => _handleMenuSelection('Inspeccionar'),
      ));
    }

    children.add(_buildCupertinoListTile(
      title: 'Mantenimiento',
      subtitle: 'Servicios preventivos y correctivos',
      icon: Icons.build_outlined,
      iconGradient: const [Color(0xFF0F172A), Color(0xFF334155)], // Slate
      onTap: () => _handleMenuSelection('Mantenimiento'),
    ));

    children.add(_buildCupertinoListTile(
      title: 'Reabastecimiento',
      subtitle: 'Registro de carga de combustible, litros y costos',
      icon: Icons.local_gas_station_rounded,
      iconGradient: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
      onTap: () => _handleMenuSelection('Reabastecimiento'),
      isLast: true,
    ));

    return _buildCupertinoListGroup(children);
  }

  Widget _buildFailuresAndIncidentsGroup() {
    return _buildCupertinoListGroup([
      _buildCupertinoListTile(
        title: 'Reportar Falla o Avería',
        subtitle: 'Crea una orden de trabajo o tarea para el taller',
        icon: Icons.build_circle_rounded,
        iconGradient: const [Color(0xFFEA580C), Color(0xFFF97316)],
        onTap: () {
          VehicleReportProblemSheet.show(
            context,
            idVehic: _idVehic,
            vehicleName: _vehicleName,
            plates: _vehiclePlates,
          );
        },
      ),
      _buildCupertinoListTile(
        title: 'Incidencia / Percance Vial',
        subtitle: 'Siniestros, averías en ruta, ponchaduras o multas',
        icon: Icons.car_crash_rounded,
        iconGradient: const [Color(0xFFDC2626), Color(0xFFEF4444)],
        isLast: true,
        onTap: () {
          VehicleReportIncidentSheet.show(
            context,
            idVehic: _idVehic,
            vehicleName: _vehicleName,
            plates: _vehiclePlates,
          );
        },
      ),
    ]);
  }

  Widget _buildManagementGroup() {
    List<Map<String, dynamic>> items = [];

    if (hasPermission(circulationPermissionValue, 2)) {
      items.add({
        'title': 'Tarjeta de Circulación',
        'icon': Icons.card_membership_outlined,
        'gradient': const [Color(0xFF0369A1), Color(0xFF0284C7)] // Sky Blue
      });
    }
    if (hasPermission(taxesPermissionValue, 2)) {
      items.add({
        'title': 'Impuestos',
        'icon': Icons.attach_money,
        'gradient': const [Color(0xFF1D4ED8), Color(0xFF3B82F6)] // Royal Blue
      });
    }
    if (hasPermission(verificationsPermissionValue, 2)) {
      items.add({
        'title': 'Verificaciones',
        'icon': Icons.checklist,
        'gradient': const [
          Color(0xFF0284C7),
          Color(0xFF38BDF8)
        ] // Light Sky Blue
      });
    }
    if (hasPermission(insurancePermissionValue, 2)) {
      items.add({
        'title': 'Seguro',
        'icon': Icons.shield_outlined,
        'gradient': const [Color(0xFF1E3A8A), Color(0xFF2563EB)] // Indigo
      });
    }
    if (hasPermission(creditPermissionValue, 2)) {
      items.add({
        'title': 'Credito',
        'icon': Icons.credit_card,
        'gradient': const [
          Color(0xFF0C4A6E),
          Color(0xFF0284C7)
        ] // Dark Sky Blue
      });
    }

    if (items.isEmpty) return const SizedBox.shrink();

    List<Widget> children = [];
    for (int i = 0; i < items.length; i++) {
      children.add(_buildCupertinoListTile(
        title: items[i]['title'],
        icon: items[i]['icon'],
        iconGradient: items[i]['gradient'],
        onTap: () => _handleMenuSelection(items[i]['title']),
        isLast: i == items.length - 1,
      ));
    }

    return _buildCupertinoListGroup(children);
  }

  Widget _buildCupertinoListGroup(List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFFE2E8F0).withOpacity(0.85), width: 0.9),
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

  Widget _buildCupertinoListTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required List<Color> iconGradient,
    required VoidCallback onTap,
    String? imageUrl,
    bool isLast = false,
  }) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: hasImage ? const Color(0xFFF1F5F9) : null,
                      gradient: hasImage
                          ? null
                          : LinearGradient(
                              colors: iconGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(11),
                      border: hasImage
                          ? Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 0.8,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: hasImage
                              ? const Color(0xFF0F172A).withOpacity(0.06)
                              : iconGradient.first.withOpacity(0.28),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: hasImage
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(icon,
                                    size: 20, color: iconGradient.first),
                              ),
                            )
                          : Center(
                              child: Icon(icon, size: 20, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFFCBD5E1),
                  ),
                ],
              ),
            ),
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

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'Ficha Técnica':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MyVehiclePage(
              idCollaborator: widget.idCollaborator,
              idMainAccount: widget.idMainAccount,
              inspectionsPermission: widget.inspectionsPermission,
              userId: widget.userId,
              initialVehicleId: widget.vehicle['id']?.toString() ??
                  widget.vehicle['idVehic']?.toString(),
            ),
          ),
        );
        break;
      case 'Inspeccionar':
        if (!_canCreateInspections) return;
        final vehicleModel = Vehicle.fromMap(widget.vehicle);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SeleccionPlantillasPage(
              vehicle: vehicleModel,
              userId: widget.userId,
              idCollaborator: widget.idCollaborator,
              idMainAccount: widget.idMainAccount,
            ),
          ),
        );
        break;
      case 'Tarjeta de Circulación':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CirculationCardPage(
              vehicle: widget.vehicle,
              circulationCardPermission: widget.circulationCardPermission,
              idMainAccount: widget.idMainAccount,
              userId: widget.userId,
            ),
          ),
        );
        break;
      case 'Mantenimiento':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MaintenancePage(
              vehicle: widget.vehicle,
            ),
          ),
        );
        break;
      case 'Impuestos':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaxesPage(
              vehicle: widget.vehicle,
              taxesPermission: widget.taxesPermission,
              circulationCardPermission: widget.circulationCardPermission,
              idMainAccount: widget.idMainAccount,
              userId: widget.userId,
            ),
          ),
        );
        break;
      case 'Verificaciones':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationsPage(
              vehicle: widget.vehicle,
              verificationsPermission: widget.verificationsPermission,
              idMainAccount: widget.idMainAccount,
              userId: widget.userId,
            ),
          ),
        );
        break;
      case 'Seguro':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InsurancePage(
              vehicle: widget.vehicle,
              insurancePermission: widget.insurancePermission,
              idMainAccount: widget.idMainAccount,
              userId: widget.userId,
            ),
          ),
        );
        break;
      case 'Credito':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Creditpage(
              vehicle: widget.vehicle,
              creditPermission: widget.creditPermission,
              idMainAccount: widget.idMainAccount,
              userId: widget.userId,
            ),
          ),
        );
        break;
      case 'Reabastecimiento':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceStationForm(
              idMainAccount: widget.idMainAccount,
              idCollaborator: widget.idCollaborator,
            ),
          ),
        );
        break;
      default:
        break;
    }
  }

  bool get _canCreateInspections {
    final session = MarkApiClient.instance.currentSession;
    if (session != null) {
      final rol = session.rol.toLowerCase();
      if (rol == 'usuario' || rol == 'chofer') return true;
      return session.flota.can('inspeccion', 'crear');
    }
    return true;
  }

  bool _hasAnyManagementPermission() {
    final session = MarkApiClient.instance.currentSession;
    if (session != null && (session.rol.toLowerCase() == 'usuario' || session.rol.toLowerCase() == 'chofer')) {
      return true;
    }
    return hasPermission(circulationPermissionValue, 2) ||
        hasPermission(taxesPermissionValue, 2) ||
        hasPermission(verificationsPermissionValue, 2) ||
        hasPermission(insurancePermissionValue, 2) ||
        hasPermission(creditPermissionValue, 2);
  }

  bool hasPermission(int permissionValue, int actionBit) {
    final session = MarkApiClient.instance.currentSession;
    if (session != null && (session.rol.toLowerCase() == 'usuario' || session.rol.toLowerCase() == 'chofer')) {
      return true; // Acceso general habilitado para usuarios y choferes de la flota
    }
    return (permissionValue & actionBit) == actionBit ||
        (permissionValue & 1) == 1;
  }
}

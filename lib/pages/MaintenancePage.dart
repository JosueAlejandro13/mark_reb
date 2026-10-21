import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Pantalla de Gestión de Mantenimiento con Apple Human Interface Guidelines
class MaintenancePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
  final bool? canRegisterService;

  const MaintenancePage({
    super.key,
    required this.vehicle,
    this.canRegisterService,
  });

  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage> {
  final MarkApiClient _client = MarkApiClient.instance;

  bool _isLoading = true;
  String? _errorMessage;
  Object? _lastError;
  Map<String, dynamic> _vehicleFicha = {};
  List<dynamic> _ultimosServicios = [];
  List<dynamic> _preventivosPendientes = [];

  bool _isNetworkError(Object? e) {
    if (e == null) return false;
    if (e is SocketException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('clientexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('software caused connection abort') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('connection timeout') ||
        msg.contains('os error: network is unreachable') ||
        msg.contains('no address associated with hostname');
  }

  bool _isServerError(Object? e) {
    if (e == null) return false;
    if (e is TimeoutException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('timeoutexception') ||
        msg.contains('500') ||
        msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('504') ||
        msg.contains('error de servidor') ||
        msg.contains('server error') ||
        msg.contains('internal server error');
  }

  /// Nelson doc (Pág. 11):
  /// Pantalla: Servicios y mantenimiento
  /// Se enseña si: servicio.ver
  /// Se puede guardar si: servicio.crear
  bool get _canCreateService {
    if (widget.canRegisterService != null) {
      return widget.canRegisterService!;
    }
    final flota = MarkApiClient.instance.flota;
    return flota.can('servicio', 'crear') ||
        flota.can('servicios', 'crear') ||
        flota.can('mantenimiento', 'crear');
  }

  int get _idVehic =>
      int.tryParse((widget.vehicle['idVehic'] ?? widget.vehicle['id'] ?? '0')
          .toString()) ??
      0;

  String get _economic => (widget.vehicle['economic'] ??
          widget.vehicle['eco'] ??
          widget.vehicle['numEconomico'] ??
          'Vehículo')
      .toString();

  String get _plates =>
      (widget.vehicle['plates'] ?? widget.vehicle['placas'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _loadFicha();
  }

  Future<void> _loadFicha() async {
    if (_idVehic <= 0) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Identificador de vehículo no válido.';
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lastError = null;
    });

    try {
      final ficha = await _client.getVehiculo(_idVehic);
      final servicios = ficha['ultimosServicios'] ?? ficha['servicios'] ?? [];
      final preventivos =
          ficha['preventivosPendientes'] ?? ficha['preventivos'] ?? [];

      if (mounted) {
        setState(() {
          _vehicleFicha = ficha;
          _ultimosServicios = servicios is List ? servicios : [];
          _preventivosPendientes = preventivos is List ? preventivos : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastError = e;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showAddServiceModal() {
    if (!_canCreateService) {
      SnackbarTop.showError(
        context,
        'Tu perfil no cuenta con permisos para registrar servicios.',
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddServiceModal(
        idVehic: _idVehic,
        economic: _economic,
        onServiceAdded: _loadFicha,
      ),
    );
  }

  void _showServiceDetailModal(Map<String, dynamic> s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ServiceDetailSheet(service: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si la carga falló, desplegar pantalla oficial de error (Conexión, Servidor o Inesperado)
    if (!_isLoading && _errorMessage != null) {
      if (_isNetworkError(_lastError ?? _errorMessage)) {
        return ConnectionErrorPage(onRetry: _loadFicha);
      } else if (_isServerError(_lastError ?? _errorMessage)) {
        return ServerErrorPage(onRetry: _loadFicha);
      } else {
        return Unexpectederrorpage(onRetry: _loadFicha);
      }
    }

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          toolbarHeight: 64,
          leadingWidth: 54,
          titleSpacing: 12,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: Material(
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
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mantenimiento',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _economic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                  if (_plates.isNotEmpty) ...[
                    const Text(
                      ' · ',
                      style:
                          TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                    Flexible(
                      child: Text(
                        _plates,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          actions: const [],
        ),
        // Botón flotante estilizado Apple (Pill flotante moderno con sombra suave)
        // Solo visible si el usuario tiene permisos de crear servicio (Nelson doc pág. 11)
        floatingActionButton: _canCreateService
            ? Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.38),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _showAddServiceModal,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.build_circle_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Registrar Servicio',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: _isLoading
              ? AppSkeleton.maintenance()
              : RefreshIndicator(
                  onRefresh: _loadFicha,
                  color: const Color(0xFF0284C7),
                  backgroundColor: Colors.white,
                  displacement: 28,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                        16, 8, 16, _canCreateService ? 84 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Tarjeta Resumen Apple del Vehículo
                        _buildVehicleHeroCard(),
                        const SizedBox(height: 16),

                        // 2. Preventivos Pendientes
                        if (_preventivosPendientes.isNotEmpty) ...[
                          _buildSectionHeader(
                            'PREVENTIVOS PENDIENTES',
                            badgeText: '${_preventivosPendientes.length}',
                            badgeColor: _preventivosPendientes.any((p) =>
                                    p is Map &&
                                    (p['vencido'] == true ||
                                        (num.tryParse((p['faltan'] ?? '')
                                                    .toString()) ??
                                                0) <
                                            0))
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFD97706),
                          ),
                          const SizedBox(height: 8),
                          ..._preventivosPendientes
                              .map((prev) => _buildPreventiveCard(prev)),
                          const SizedBox(height: 16),
                        ],

                        // 3. Historial de Servicios
                        _buildSectionHeader(
                          'HISTORIAL DE SERVICIOS REALIZADOS',
                          badgeText: '${_ultimosServicios.length}',
                          badgeColor: const Color(0xFF0284C7),
                        ),
                        const SizedBox(height: 8),

                        if (_ultimosServicios.isEmpty)
                          _buildEmptyServicesView()
                        else
                          ..._ultimosServicios.map((s) => _buildServiceTile(s)),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // --- TARJETA RESUMEN APPLE HERO ---
  Widget _buildVehicleHeroCard() {
    final veh = _vehicleFicha['vehiculo'] ?? widget.vehicle;
    final marca = (veh['marca'] ?? veh['brand'] ?? '').toString();
    final modelo = (veh['modelo'] ?? veh['model'] ?? '').toString();
    final anio = (veh['anio'] ?? veh['year'] ?? '').toString();
    final odometro =
        (veh['odometro'] ?? veh['km'] ?? veh['kilometraje'] ?? '--').toString();

    final subtitulo = [
      if (marca.isNotEmpty) marca,
      if (modelo.isNotEmpty) modelo,
      if (anio.isNotEmpty) anio,
    ].join(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _economic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo.isNotEmpty
                          ? subtitulo
                          : 'Unidad Asignada a Flota',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 12, color: Color(0xFF059669)),
                    SizedBox(width: 4),
                    Text(
                      'Operativo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniMetric(
                icon: Icons.history_rounded,
                label: 'Servicios',
                value: '${_ultimosServicios.length}',
                color: const Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              _buildMiniMetric(
                icon: Icons.warning_amber_rounded,
                label: 'Preventivos',
                value: '${_preventivosPendientes.length}',
                color: _preventivosPendientes.isEmpty
                    ? const Color(0xFF059669)
                    : (_preventivosPendientes.any((p) =>
                            p is Map &&
                            (p['vencido'] == true ||
                                (num.tryParse((p['faltan'] ?? '').toString()) ??
                                        0) <
                                    0))
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFD97706)),
              ),
              const SizedBox(width: 8),
              _buildMiniMetric(
                icon: Icons.speed_rounded,
                label: 'Odómetro',
                value: odometro != '--' ? '$odometro km' : 'Al día',
                color: const Color(0xFF6366F1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ENCABEZADOS DE SECCIÓN APPLE ---
  Widget _buildSectionHeader(String title,
      {String? badgeText, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4, top: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          if (badgeText != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color:
                    (badgeColor ?? const Color(0xFF0284C7)).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: badgeColor ?? const Color(0xFF0284C7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- TARJETA DE PREVENTIVOS PENDIENTES CON AJUSTE RESPONSIVO ---
  Widget _buildPreventiveCard(dynamic prev) {
    if (prev is! Map) return const SizedBox.shrink();

    final nombre = (prev['nombre'] ?? prev['servicio'] ?? 'Servicio Programado')
        .toString();

    // El backend envía "faltan": -9521 (o en casos anteriores "kmFaltan" / "km")
    final dynamic rawFaltan =
        prev['faltan'] ?? prev['kmFaltan'] ?? prev['km'] ?? prev['kmRestantes'];

    final num? faltanNum = num.tryParse(rawFaltan?.toString() ?? '');
    final bool isVencido =
        prev['vencido'] == true || (faltanNum != null && faltanNum < 0);

    final String kmTexto;
    if (faltanNum != null) {
      final formatted = NumberFormat('#,##0', 'es_MX').format(faltanNum.abs());
      if (isVencido || faltanNum < 0) {
        kmTexto = 'Vencido por: $formatted km';
      } else if (faltanNum == 0) {
        kmTexto = 'Vence hoy (0 km)';
      } else {
        kmTexto = 'Faltan: $formatted km';
      }
    } else if (rawFaltan != null && rawFaltan.toString().isNotEmpty) {
      kmTexto = 'Faltan: $rawFaltan km';
    } else {
      kmTexto = 'Faltan: -- km';
    }

    final cardBg =
        isVencido ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final cardBorder =
        isVencido ? const Color(0xFFFECACA) : const Color(0xFFFDE68A);
    final iconBoxBg =
        isVencido ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7);
    final iconBoxBorder =
        isVencido ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D);
    final primaryColor =
        isVencido ? const Color(0xFFDC2626) : const Color(0xFFD97706);
    final titleColor =
        isVencido ? const Color(0xFF991B1B) : const Color(0xFF92400E);
    final subtitleColor =
        isVencido ? const Color(0xFFB91C1C) : const Color(0xFFB45309);
    final badgeText = isVencido ? 'Vencido' : 'Próximo';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBoxBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconBoxBorder),
            ),
            child: Center(
              child: Icon(
                isVencido
                    ? Icons.error_outline_rounded
                    : Icons.warning_amber_rounded,
                color: primaryColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.speed_rounded, size: 12, color: subtitleColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        kmTexto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cardBorder),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- ITEM DE HISTORIAL DE SERVICIO ---
  Widget _buildServiceTile(dynamic s) {
    final taller =
        (s['taller'] ?? s['proveedor'] ?? s['servicio'] ?? 'Mantenimiento')
            .toString();
    final fecha = (s['inicio'] ?? s['fecha'] ?? '').toString();
    final costo = s['costo'] ?? s['monto'];
    final obs = (s['obs'] ?? s['descripcion'] ?? '').toString();
    final origen = s['origen'] ?? (s['tipo'] == 'Preventivo' ? 4 : 0);

    final (tipoNombre, iconBg, iconColor, iconData) = switch (origen) {
      4 => (
          'Preventivo',
          const Color(0xFFECFDF5),
          const Color(0xFF059669),
          Icons.shield_outlined
        ),
      1 => (
          'Inspección',
          const Color(0xFFEEF2FF),
          const Color(0xFF6366F1),
          Icons.fact_check_outlined
        ),
      _ => (
          'Correctivo',
          const Color(0xFFE0F2FE),
          const Color(0xFF0284C7),
          Icons.build_rounded
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showServiceDetailModal(Map<String, dynamic>.from(s)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(iconData, size: 20, color: iconColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              taller,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tipoNombre,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (fecha.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                fecha.length > 16
                                    ? fecha.substring(0, 16)
                                    : fecha,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (obs.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          obs,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (costo != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '\$$costo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF047857),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFFCBD5E1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- VISTA VACÍA ESTILO APPLE ---
  Widget _buildEmptyServicesView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Icon(
                Icons.build_circle_outlined,
                size: 28,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sin servicios registrados',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'No se han capturado mantenimientos previos en esta unidad móvil.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          if (_canCreateService) ...[
            const SizedBox(height: 16),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFF0284C7),
              borderRadius: BorderRadius.circular(12),
              onPressed: _showAddServiceModal,
              child: const Text(
                'Registrar Primer Servicio',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modal Bottom Sheet para Registrar Servicio con Apple HIG
class _AddServiceModal extends StatefulWidget {
  final int idVehic;
  final String economic;
  final VoidCallback onServiceAdded;

  const _AddServiceModal({
    required this.idVehic,
    required this.economic,
    required this.onServiceAdded,
  });

  @override
  State<_AddServiceModal> createState() => _AddServiceModalState();
}

class _AddServiceModalState extends State<_AddServiceModal> {
  final _proveedorCtrl = TextEditingController();
  final _manoObraCtrl = TextEditingController();
  final _refaccionesCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  int _origen = 0; // 0: Correctivo, 4: Preventivo, 1: Inspección
  DateTime _fechaServicio = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _proveedorCtrl.dispose();
    _manoObraCtrl.dispose();
    _refaccionesCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  double get _totalCosto {
    final mo = double.tryParse(_manoObraCtrl.text.trim()) ?? 0.0;
    final ref = double.tryParse(_refaccionesCtrl.text.trim()) ?? 0.0;
    return mo + ref;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaServicio,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0284C7),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechaServicio = picked);
    }
  }

  Future<void> _submit() async {
    final taller = _proveedorCtrl.text.trim();
    if (taller.isEmpty) {
      SnackbarTop.showError(
          context, 'Ingresa el nombre del proveedor o taller.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final manoObra = double.tryParse(_manoObraCtrl.text.trim()) ?? 0.0;
      final refacciones = double.tryParse(_refaccionesCtrl.text.trim()) ?? 0.0;

      final action = {
        'uuid': const Uuid().v4(),
        'tipo': 'servicio',
        'idVehic': widget.idVehic,
        'idProveedor': 1,
        'proveedor': taller,
        'inicio': DateFormat('yyyy-MM-dd HH:mm:ss').format(_fechaServicio),
        'fin': DateFormat('yyyy-MM-dd HH:mm:ss').format(_fechaServicio),
        'manoObra': manoObra,
        'refacciones': refacciones,
        'origen': _origen,
        'obs': _obsCtrl.text.trim(),
        'fecHor': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      };

      final resultados = await MarkApiClient.instance.sendActions([action]);

      // Validar si el servidor rechazó la acción (ej. PERMISO)
      if (resultados.isNotEmpty) {
        final res = resultados.first;
        final bool isOk = res['ok'] == true;
        if (!isOk) {
          final avisos = res['avisos'];
          String errorMsg = 'No fue posible registrar el servicio.';
          bool isPermisoError = false;

          if (avisos is List && avisos.isNotEmpty) {
            final primerAviso = avisos.first;
            if (primerAviso is Map) {
              if (primerAviso['codigo'] == 'PERMISO') {
                isPermisoError = true;
              }
              errorMsg = primerAviso['texto']?.toString() ?? errorMsg;
            }
          }

          if (isPermisoError) {
            // Según Nelson doc (Pág. 11): si el servidor rechaza con PERMISO, refrescar a=yo
            unawaited(MarkApiClient.instance.pingYo().catchError((_) {}));
          }

          if (mounted) {
            SnackbarTop.showError(context, errorMsg);
          }
          return;
        }
      }

      widget.onServiceAdded();
      if (mounted) {
        Navigator.pop(context);
        SnackbarTop.showSuccess(context, 'Servicio registrado correctamente.');
      }
    } catch (e) {
      if (mounted) {
        SnackbarTop.showError(context, 'Error al registrar servicio: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Container(
        height: screenHeight * 0.92,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            // Apple Grabber Pill
            Center(
              child: Container(
                width: 36,
                height: 4.5,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // Header de la Ventana Modal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registrar Servicio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mantenimiento para unidad ${widget.economic}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Contenido con Scroll
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16,
                    math.max(mediaQuery.padding.bottom, 16) + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector Segmentado de Tipo de Mantenimiento
                    const Text(
                      'TIPO DE MANTENIMIENTO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSegmentedOriginSelector(),
                    const SizedBox(height: 16),

                    // Grupo 1: Proveedor y Fecha
                    const Text(
                      'TALLER Y FECHA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAppleCard(
                      children: [
                        _buildAppleTextField(
                          controller: _proveedorCtrl,
                          label: 'Proveedor o Taller Mecánico *',
                          placeholder: 'Ej. Frenos y Servicios del Centro',
                          icon: Icons.storefront_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildDatePickerField(),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Grupo 2: Costos y Presupuesto
                    const Text(
                      'COSTOS Y DESGLOSE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAppleCard(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildAppleTextField(
                                controller: _manoObraCtrl,
                                label: 'Mano de Obra (\$)',
                                placeholder: '0.00',
                                icon: Icons.handyman_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildAppleTextField(
                                controller: _refaccionesCtrl,
                                label: 'Refacciones (\$)',
                                placeholder: '0.00',
                                icon: Icons.extension_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Badge total calculado
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.calculate_outlined,
                                      size: 16, color: Color(0xFF16A34A)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Costo Total Calculado',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                NumberFormat.currency(
                                        locale: 'es_MX', symbol: '\$')
                                    .format(_totalCosto),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Grupo 3: Observaciones
                    const Text(
                      'NOTAS TÉCNICAS Y OBSERVACIONES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAppleCard(
                      children: [
                        _buildAppleTextField(
                          controller: _obsCtrl,
                          label: 'Detalles del Servicio',
                          placeholder:
                              'Describe las piezas reemplazadas, garantía o recomendaciones...',
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Botón Principal Guardar (Estilo exacto de EditProfilePage con tono gris durante carga)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: _isSaving
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF0284C7),
                                    Color(0xFF0369A1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          boxShadow: _isSaving
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF0284C7)
                                        .withOpacity(0.32),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSaving
                              ? Center(
                                  child:
                                      LoadingAnimationWidget.threeRotatingDots(
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded,
                                        color: Colors.white, size: 19),
                                    SizedBox(width: 8),
                                    Text(
                                      'Guardar Mantenimiento',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.2,
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
            ),
          ],
        ),
      ),
    );
  }

  // Segmented Selector estilo Apple
  Widget _buildSegmentedOriginSelector() {
    final options = [
      (0, 'Correctivo', Icons.build_rounded),
      (4, 'Preventivo', Icons.shield_outlined),
      (1, 'Inspección', Icons.fact_check_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = _origen == opt.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _origen = opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      opt.$3,
                      size: 14,
                      color: isSelected
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            'Fecha de Realización',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: Color(0xFF0284C7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('d MMMM yyyy', 'es_MX').format(_fechaServicio),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppleCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildAppleTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          cursorColor: const Color(0xFF0284C7),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: placeholder,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: maxLines == 1
                ? Icon(icon, size: 17, color: const Color(0xFF0284C7))
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hoja de detalle para ver servicio seleccionado estilo Apple
class _ServiceDetailSheet extends StatelessWidget {
  final Map<String, dynamic> service;

  const _ServiceDetailSheet({required this.service});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );

    final taller = (service['taller'] ??
            service['proveedor'] ??
            service['servicio'] ??
            'Mantenimiento')
        .toString();
    final fecha = (service['inicio'] ?? service['fecha'] ?? '--').toString();
    final fin = (service['fin'] ?? '').toString();
    final costo = service['costo'] ?? service['monto'];
    final manoObra = service['manoObra'];
    final refacciones = service['refacciones'];
    final obs = (service['obs'] ?? service['descripcion'] ?? '').toString();
    final origen =
        service['origen'] ?? (service['tipo'] == 'Preventivo' ? 4 : 0);

    final tipoNombre = switch (origen) {
      4 => 'Mantenimiento Preventivo',
      1 => 'Derivado de Inspección',
      _ => 'Mantenimiento Correctivo',
    };

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.90,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          math.max(mediaQuery.padding.bottom, 24),
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          taller,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tipoNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (costo != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        '\$$costo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Fecha de inicio', fecha),
                    if (fin.isNotEmpty && fin != fecha) ...[
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildDetailRow('Fecha de entrega', fin),
                    ],
                    if (manoObra != null) ...[
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildDetailRow('Mano de obra', '\$$manoObra'),
                    ],
                    if (refacciones != null) ...[
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _buildDetailRow('Refacciones', '\$$refacciones'),
                    ],
                  ],
                ),
              ),
              if (obs.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OBSERVACIONES Y NOTAS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        obs,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF334155),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Cerrar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/insurance_model.dart';
import 'package:mark_v3/providers/Vehicles_/insurance_provider.dart';
import 'package:mark_v3/services/mark_api_client.dart';

// Autor: Josue Hernandez
class InsurancePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
  final String insurancePermission;
  final String idMainAccount;
  final String userId;

  const InsurancePage({
    super.key,
    required this.insurancePermission,
    required this.vehicle,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  ConsumerState<InsurancePage> createState() => _InsurancePageState();
}

class _InsurancePageState extends ConsumerState<InsurancePage> {
  List<Map<String, dynamic>> _companias = [];
  List<Map<String, dynamic>> _coberturas = [];
  String _typeSource = '';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _fetchCatalogs();
    _fetchTypeSource();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInsurance();
    });
  }

  Future<void> _fetchCatalogs() async {
    try {
      final dbService = VehiclesconService();
      final results = await Future.wait([
        dbService.obtenerCompanias(),
        dbService.obtenerTipoCobertura(),
      ]);
      if (mounted) {
        setState(() {
          _companias = results[0];
          _coberturas = results[1];
        });
      }
    } catch (e) {
      debugPrint('Error al cargar catálogos de seguros: $e');
    }
  }

  void _loadInsurance() {
    ref.read(insuranceProvider.notifier).fetchInsurances(
          widget.vehicle['id'].toString(),
          widget.idMainAccount.toString(),
        );
  }

  Future<void> _fetchTypeSource() async {
    try {
      final Map<String, dynamic> data =
          await NotificationService().gettypSource('vehic_insurance');
      if (mounted && data.containsKey('id')) {
        setState(() {
          _typeSource = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error al obtener typeSource de seguro: $e');
    }
  }

  Future<void> _refreshData() async {
    _loadInsurance();
    _fetchCatalogs();
  }

  void _handleError(dynamic error) {
    if (!mounted) return;

    if (error is SocketException) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ConnectionErrorPage(
            onRetry: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => widget),
              );
            },
          ),
        ),
      );
    } else if (error is TimeoutException) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ServerErrorPage(
            onRetry: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => widget),
              );
            },
          ),
        ),
      );
    } else {
      debugPrint('Error al obtener seguros: $error');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Unexpectederrorpage(
            onRetry: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => widget),
              );
            },
          ),
        ),
      );
    }
  }

  // --- PERMISOS BITWISE Y FLOTA (Nelson doc) ---
  bool get _canEdit =>
      MarkApiClient.instance.flota.can('seguro', 'editar') ||
      ((int.tryParse(widget.insurancePermission) ?? 0) & 8 == 8);

  bool get _canDelete => false;

  bool get _canCreate =>
      MarkApiClient.instance.flota.can('seguro', 'crear') ||
      ((int.tryParse(widget.insurancePermission) ?? 0) & 4 == 4);

  // --- FORMATEO Y PARSEO DE FECHAS SEGURO ---
  String _formatDisplayDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) {
      return DateFormat('dd / MM / yyyy').format(date);
    }
    final str = date.toString().trim();
    if (str.isEmpty) return 'N/A';

    try {
      DateTime parsed = DateFormat('yyyy-MM-dd').parse(str);
      return DateFormat('dd / MM / yyyy').format(parsed);
    } catch (_) {}

    try {
      DateTime parsed = DateFormat('dd/MM/yyyy').parse(str);
      return DateFormat('dd / MM / yyyy').format(parsed);
    } catch (_) {}

    try {
      DateTime parsed = DateTime.parse(str);
      return DateFormat('dd / MM / yyyy').format(parsed);
    } catch (_) {}

    return str;
  }

  DateTime? _parseDateSafe(dynamic date) {
    if (date == null) return null;
    if (date is DateTime) return date;
    final str = date.toString().trim();
    if (str.isEmpty) return null;

    try {
      return DateFormat('yyyy-MM-dd').parse(str);
    } catch (_) {}

    try {
      return DateFormat('dd/MM/yyyy').parse(str);
    } catch (_) {}

    try {
      return DateTime.parse(str);
    } catch (_) {}

    return null;
  }

  int _calculateDaysDifference(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    final insuranceState = ref.watch(insuranceProvider);

    if (insuranceState.isConnectionError) {
      return ConnectionErrorPage(onRetry: _refreshData);
    }
    if (insuranceState.isServerError) {
      return ServerErrorPage(onRetry: _refreshData);
    }
    if (insuranceState.isUnexpectedError) {
      return Unexpectederrorpage(onRetry: _refreshData);
    }

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFF0284C7),
            onRefresh: _refreshData,
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
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  if (!_canEdit && !_canCreate)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFBFDBFE),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Modo solo lectura: Tu rol cuenta con permisos para consultar la póliza de seguro y su vigencia, pero no para registrar o modificar datos.',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF1E3A8A).withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (insuranceState.isLoading)
                    _buildSkeleton(isSmallScreen)
                  else if (insuranceState.insurances.isEmpty)
                    _buildEmptyState()
                  else
                    _buildInsuranceDetails(insuranceState.insurances.first),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // HEADER SUPERIOR ESTILO APPLE
  // =========================================================================
  Widget _buildHeader(BuildContext context) {
    final make = widget.vehicle['make']?.toString() ?? '';
    final model = widget.vehicle['model']?.toString() ?? '';
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'Sin Placas';

    final subtitle = (make.isNotEmpty || model.isNotEmpty)
        ? '$make $model · Placas: $plates'
        : 'Placas: $plates';

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seguro Vehicular',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
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
        const SizedBox(width: 8),
        _buildHeaderActionMenu(context),
      ],
    );
  }

  Widget _buildHeaderActionMenu(BuildContext context) {
    final List<PopupMenuEntry<String>> menuItems = [];
    final hasInsurance = ref.watch(insuranceProvider).insurances.isNotEmpty;

    if (hasInsurance && _canEdit) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'edit',
          title: 'Editar Seguro',
          icon: Icons.edit_rounded,
          iconColor: const Color(0xFF0284C7),
        ),
      );
    }

    if (hasInsurance && _canDelete) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'delete',
          title: 'Eliminar Seguro',
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFEF4444),
          textColor: const Color(0xFFEF4444),
        ),
      );
    }

    if (!hasInsurance && _canCreate) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'create',
          title: 'Registrar Seguro',
          icon: Icons.add_circle_outline_rounded,
          iconColor: const Color(0xFF0284C7),
        ),
      );
    }

    if (menuItems.isEmpty) {
      return const SizedBox(width: 38, height: 38);
    }

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Opciones de seguro',
        padding: EdgeInsets.zero,
        icon: Container(
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
              Icons.more_horiz_rounded,
              color: Color(0xFF0F172A),
              size: 20,
            ),
          ),
        ),
        itemBuilder: (context) => menuItems,
        onSelected: (action) {
          if (action == 'edit') {
            final insurances = ref.read(insuranceProvider).insurances;
            if (insurances.isNotEmpty) {
              _openInsuranceModal(
                  isEditing: true, initialData: insurances.first.toMap());
            }
          } else if (action == 'delete') {
            _showDeleteConfirmationDialog();
          } else if (action == 'create') {
            _openInsuranceModal(isEditing: false);
          }
        },
      ),
    );
  }

  PopupMenuEntry<String> _buildPopupMenuItem({
    required String value,
    required String title,
    required IconData icon,
    required Color iconColor,
    Color textColor = const Color(0xFF0F172A),
  }) {
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SKELETON APPLE DE CARGA
  // =========================================================================
  Widget _buildSkeleton(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppShimmerBox.card(
          height: 195,
          borderRadius: 20,
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: AppShimmerBox.text(width: 160, height: 12),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  AppShimmerBox(width: 36, height: 36, borderRadius: 10),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmerBox.text(width: 150, height: 14),
                        SizedBox(height: 6),
                        AppShimmerBox.text(width: 220, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const AppShimmerBox(
                width: double.infinity,
                height: 48,
                borderRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: AppShimmerBox.text(width: 170, height: 12),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: const [
              AppShimmerBox.text(width: double.infinity, height: 14),
              SizedBox(height: 12),
              AppShimmerBox.text(width: double.infinity, height: 14),
              SizedBox(height: 12),
              AppShimmerBox.text(width: double.infinity, height: 14),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // ESTADO DE ERROR ESTILO APPLE
  // =========================================================================
  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Error al cargar el seguro vehicular',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Comprueba tu conexión o intenta nuevamente.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Reintentar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // ESTADO VACÍO (SIN SEGURO REGISTRADO)
  // =========================================================================
  Widget _buildEmptyState() {
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'este vehículo';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Color(0xFF0284C7),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin Seguro Registrado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No se encontró ninguna póliza o contrato de seguro registrado para $plates.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            if (_canCreate) ...[
              const SizedBox(height: 24),
              LoadingActionButton(
                text: 'Registrar Seguro',
                icon: Icons.add_circle_outline_rounded,
                isLoading: false,
                height: 46,
                borderRadius: 14,
                onPressed: () => _openInsuranceModal(isEditing: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // DETALLES DEL SEGURO (HERO CARD COLOR ÍNDIGO / ROYAL AMETHYST APPLE WALLET)
  // =========================================================================
  Widget _buildInsuranceDetails(InsuranceModel seguro) {
    final compania = seguro.idCompania.trim().isNotEmpty
        ? seguro.idCompania
        : 'Aseguradora Desconocida';
    final policyNum =
        seguro.polizaNum.trim().isNotEmpty ? seguro.polizaNum : 'Sin Póliza';
    final tipoCobertura = seguro.idTipoCobertura.trim().isNotEmpty
        ? seguro.idTipoCobertura
        : 'Cobertura Desconocida';

    final deducible = double.tryParse(seguro.deducible) ?? 0.0;
    final monto = double.tryParse(seguro.monto) ?? 0.0;

    final fechaInicioStr = _formatDisplayDate(seguro.fechaInicio);
    final fechaVencimientoStr = _formatDisplayDate(seguro.fechaVencimiento);
    final observaciones = seguro.observaciones.trim();

    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'OFICIAL';

    final parsedExpiry = _parseDateSafe(seguro.fechaVencimiento);

    // Evaluación del estatus de vigencia del seguro
    int daysRemaining = 0;
    bool isExpired = false;
    bool isToday = false;
    bool isClose = false;

    Color badgeBg;
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (parsedExpiry == null) {
      badgeBg = const Color(0xFF6366F1).withOpacity(0.2);
      badgeColor = const Color(0xFFA5B4FC);
      badgeText = 'REGISTRADA';
      badgeIcon = Icons.verified_rounded;
    } else {
      daysRemaining = _calculateDaysDifference(parsedExpiry);
      if (daysRemaining < 0) {
        isExpired = true;
        badgeBg = const Color(0xFFEF4444).withOpacity(0.25);
        badgeColor = const Color(0xFFFCA5A5);
        badgeText = 'VENCIDA';
        badgeIcon = Icons.error_rounded;
      } else if (daysRemaining == 0) {
        isToday = true;
        badgeBg = const Color(0xFFEA580C).withOpacity(0.25);
        badgeColor = const Color(0xFFFDBA74);
        badgeText = 'VENCE HOY';
        badgeIcon = Icons.warning_amber_rounded;
      } else if (daysRemaining <= 30) {
        isClose = true;
        badgeBg = const Color(0xFFEA580C).withOpacity(0.25);
        badgeColor = const Color(0xFFFDBA74);
        badgeText = 'POR VENCER';
        badgeIcon = Icons.warning_amber_rounded;
      } else {
        badgeBg = const Color(0xFF10B981).withOpacity(0.25);
        badgeColor = const Color(0xFF6EE7B7);
        badgeText = 'VIGENTE';
        badgeIcon = Icons.check_circle_rounded;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. TARJETA DIGITAL APPLE WALLET HERO (DISTINTIVO COLOR ÍNDIGO NOCTURNO / AMATISTA REAL)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1E1B4B), // Midnight Indigo Base
                Color(0xFF2E1065), // Royal Amethyst
                Color(0xFF6366F1), // Electric Indigo Accent
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E1B4B).withOpacity(0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -30,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  left: -40,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila Superior: Marca oficial y Placas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(
                                    Icons.shield_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PÓLIZA DE SEGURO',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white.withOpacity(0.95),
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      Text(
                                        'COBERTURA & PROTECCIÓN · MARK FLEET',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.65),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 11,
                                  color: Color(0xFFA5B4FC),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  plates.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Fila Central: Aseguradora + Número de Póliza
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.business_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          compania.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cobertura: $tipoCobertura',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'NÚMERO DE PÓLIZA',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.65),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    policyNum,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Fila Inferior: Vigencia y Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VENCIMIENTO',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.65),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fechaVencimientoStr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: badgeColor.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(badgeIcon, size: 12, color: badgeColor),
                                const SizedBox(width: 5),
                                Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 2. SECCIÓN: ESTATUS DE COBERTURA Y VIGENCIA
        _buildSectionTitle('ESTATUS DE COBERTURA Y VIGENCIA'),
        _buildAppleGroupContainer(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isExpired
                        ? const Color(0xFFFEE2E2)
                        : (isClose || isToday
                            ? const Color(0xFFFFF7ED)
                            : const Color(0xFFDCFCE7)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      isExpired
                          ? Icons.error_outline_rounded
                          : (isClose || isToday
                              ? Icons.warning_amber_rounded
                              : Icons.verified_user_rounded),
                      color: isExpired
                          ? const Color(0xFFEF4444)
                          : (isClose || isToday
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF10B981)),
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
                        isExpired
                            ? 'Póliza de Seguro Vencida'
                            : (isToday
                                ? 'Póliza Vence el Día de Hoy'
                                : (isClose
                                    ? 'Próxima a Vencer'
                                    : 'Seguro Activo y Vigente')),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isExpired
                            ? 'Expiró hace ${-daysRemaining} días. La unidad carece de cobertura financiera.'
                            : (isToday
                                ? 'La validez del seguro termina hoy a las 23:59 hrs.'
                                : (isClose
                                    ? 'Quedan $daysRemaining días antes de que expire la cobertura.'
                                    : 'Quedan $daysRemaining días de respaldo activo ante siniestros.')),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExpired
                              ? 'CONDICIÓN: UNIDAD DESPROTEGIDA ANTE ACCIDENTES'
                              : (isClose || isToday
                                  ? 'CONDICIÓN: RENOVACIÓN DE PÓLIZA REQUERIDA'
                                  : 'CONDICIÓN: COBERTURA Y RESPALDO COMPLETO'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isExpired
                                ? const Color(0xFFDC2626)
                                : (isClose || isToday
                                    ? const Color(0xFFC2410C)
                                    : const Color(0xFF15803D)),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isExpired
                              ? 'Renueva el contrato de inmediato para evitar multas de tránsito y pérdidas patrimoniales.'
                              : 'Póliza legal para circular en carreteras y vías públicas del país.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpired
                        ? Icons.report_problem_rounded
                        : (isClose || isToday
                            ? Icons.alarm_rounded
                            : Icons.check_circle_outline_rounded),
                    color: isExpired
                        ? const Color(0xFFEF4444)
                        : (isClose || isToday
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF10B981)),
                    size: 22,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3. SECCIÓN: DETALLES DE LA PÓLIZA
        _buildSectionTitle('DETALLES DE LA PÓLIZA'),
        _buildAppleGroupContainer(
          children: [
            _buildDetailRow(
              icon: Icons.business_rounded,
              label: 'Compañía Aseguradora',
              value: compania,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.shield_outlined,
              label: 'Tipo de Cobertura',
              value: tipoCobertura,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.description_outlined,
              label: 'Número de Póliza',
              value: policyNum,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.percent_rounded,
              label: 'Deducible',
              value: _currencyFormat.format(deducible),
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_available_rounded,
              label: 'Fecha de Contratación / Inicio',
              value: fechaInicioStr,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_busy_rounded,
              label: 'Fecha de Vencimiento',
              value: fechaVencimientoStr,
            ),
            if (observaciones.isNotEmpty) ...[
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildDetailRow(
                icon: Icons.notes_rounded,
                label: 'Observaciones',
                value: observaciones,
              ),
            ],
            const Divider(height: 20, color: Color(0xFFE2E8F0)),
            _buildDetailRow(
              icon: Icons.monetization_on_outlined,
              label: 'Prima Total / Monto',
              value: _currencyFormat.format(monto),
              isHighlight: true,
            ),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // --- FILA DE DETALLE ESTILO CUPERTINO/APPLE ---
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color:
                isHighlight ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 16,
            color:
                isHighlight ? const Color(0xFF0284C7) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              color: isHighlight
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF475569),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 14.5 : 13,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color:
                isHighlight ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
            letterSpacing: isHighlight ? -0.2 : 0,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // MODAL BOTTOM SHEET DE FORMULARIO APPLE (CREAR / EDITAR)
  // =========================================================================
  void _openInsuranceModal({
    required bool isEditing,
    Map<String, dynamic>? initialData,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _InsuranceFormModalSheet(
          isEditing: isEditing,
          initialData: initialData,
          vehicle: widget.vehicle,
          idMainAccount: widget.idMainAccount,
          userId: widget.userId,
          typeSource: _typeSource,
          companias: _companias,
          coberturas: _coberturas,
          onSuccess: () {
            _refreshData();
          },
        );
      },
    );
  }

  // =========================================================================
  // DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN ESTILO APPLE
  // =========================================================================
  void _showDeleteConfirmationDialog() {
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'este vehículo';

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: dynamicMinAxisSize,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        color: Color(0xFFEF4444),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '¿Eliminar Seguro?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Se borrará la póliza registrada para las placas $plates. Esta acción no se puede deshacer.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF475569),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: isDeleting
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LoadingActionButton(
                            text: 'Eliminar',
                            isLoading: isDeleting,
                            height: 44,
                            borderRadius: 14,
                            backgroundColor: const Color(0xFFEF4444),
                            onPressed: () async {
                              setDialogState(() {
                                isDeleting = true;
                              });
                              await _performDeleteInsurance(dialogContext);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  MainAxisSize get dynamicMinAxisSize => MainAxisSize.min;

  Future<void> _performDeleteInsurance(BuildContext dialogContext) async {
    try {
      final seguros = await VehiclesconService().obtenerSegurosPorVehiculo(
        widget.vehicle['id'].toString(),
        widget.idMainAccount.toString(),
      );

      if (seguros.isEmpty) {
        if (mounted) {
          Navigator.of(dialogContext).pop();
          SnackbarTop.showInfo(
            context,
            'No se encontró ningún seguro para eliminar.',
          );
        }
        return;
      }

      final int idinsurance = seguros.first['id'];
      final String policyNum = seguros.first['polizaNum']?.toString() ?? '';
      final String fechaInicio = seguros.first['fechaInicio']?.toString() ?? '';
      final String fechaVencimiento =
          seguros.first['fechaVencimiento']?.toString() ?? '';

      // 1. Notificación antes o después
      try {
        const nameNotice = 'vehicle_insurance_deleted';
        final noticeTemplate =
            await NotificationService().getNoticeByName(nameNotice);

        if (noticeTemplate != null) {
          String message = '';
          final rawMsg = noticeTemplate['message'];
          if (rawMsg is List<int>) {
            try {
              message = utf8.decode(rawMsg);
            } catch (_) {
              message = rawMsg.toString();
            }
          } else {
            message = rawMsg?.toString() ?? '';
          }

          final vehiclePlates = widget.vehicle['placas']?.toString() ??
              widget.vehicle['plate']?.toString() ??
              '';

          final formattedMessage = message
              .replaceAll('{vehicle_plate}', vehiclePlates)
              .replaceAll('{policy_number}', policyNum)
              .replaceAll('{contract_date}', fechaInicio)
              .replaceAll('{expiry_date}', fechaVencimiento);

          final title = (noticeTemplate['title']?.toString() ?? '')
              .replaceAll('{vehicle_plate}', vehiclePlates);

          final finalMessage =
              '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

          await NotificationService().insertNotification({
            'typeSource': _typeSource,
            'idOrigin': idinsurance,
            'typEvent': 3,
            'date': DateTime.now().toIso8601String(),
            'message': finalMessage,
            'colNotice': 'insurace_Delete',
            'idMainAcoount': widget.idMainAccount.toString(),
            'codUsGenerator': widget.userId.toString(),
            'idDev': widget.userId.toString(),
          });
        }
      } catch (notifErr) {
        debugPrint(
            'Error al enviar notificación de eliminación de seguro: $notifErr');
      }

      // 2. Eliminar seguro
      await VehiclesconService().eliminarSeguro(
        widget.vehicle['id'].toString(),
        widget.idMainAccount.toString(),
      );

      // 3. Eliminar control de gestión
      await VehiclesconService().deleteManagementControlINS(
        widget.idMainAccount.toString(),
        widget.vehicle['id'].toString(),
      );

      if (mounted) {
        Navigator.of(dialogContext).pop();
        _refreshData();
        SnackbarTop.showSuccess(
          context,
          'Seguro eliminado exitosamente.',
        );
      }
    } catch (e) {
      debugPrint('Error al eliminar seguro: $e');
      if (mounted) {
        Navigator.of(dialogContext).pop();
        SnackbarTop.showError(
          context,
          'Error al eliminar el seguro. Intente nuevamente.',
        );
      }
    }
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
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
}

// ===========================================================================
// MODAL SHEET FORMULARIO APPLE PARA CREAR / EDITAR SEGURO
// ===========================================================================
class _InsuranceFormModalSheet extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic> vehicle;
  final String idMainAccount;
  final String userId;
  final String typeSource;
  final List<Map<String, dynamic>> companias;
  final List<Map<String, dynamic>> coberturas;
  final VoidCallback onSuccess;

  const _InsuranceFormModalSheet({
    required this.isEditing,
    this.initialData,
    required this.vehicle,
    required this.idMainAccount,
    required this.userId,
    required this.typeSource,
    required this.companias,
    required this.coberturas,
    required this.onSuccess,
  });

  @override
  State<_InsuranceFormModalSheet> createState() =>
      _InsuranceFormModalSheetState();
}

class _InsuranceFormModalSheetState extends State<_InsuranceFormModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _polizaNumController = TextEditingController();
  final _deducibleController = TextEditingController();
  final _montoController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final _fechaVencimientoController = TextEditingController();

  String? _selectedCompaniaId;
  String? _selectedCoberturaId;
  DateTime? _selectedFechaInicio;
  DateTime? _selectedFechaVencimiento;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialData != null) {
      final d = widget.initialData!;
      _polizaNumController.text = d['polizaNum']?.toString() ?? '';
      _deducibleController.text = d['deducible']?.toString() ?? '0';
      _montoController.text = d['monto']?.toString() ?? '0';
      _observacionesController.text = d['observaciones']?.toString() ?? '';

      _selectedFechaInicio = _parseDate(d['fechaInicio']);
      if (_selectedFechaInicio != null) {
        _fechaInicioController.text =
            DateFormat('dd / MM / yyyy').format(_selectedFechaInicio!);
      }

      _selectedFechaVencimiento = _parseDate(d['fechaVencimiento']);
      if (_selectedFechaVencimiento != null) {
        _fechaVencimientoController.text =
            DateFormat('dd / MM / yyyy').format(_selectedFechaVencimiento!);
      }

      _resolveInitialIds(
        d['idCompania']?.toString(),
        d['idTipoCobertura']?.toString(),
      );
    }
  }

  void _resolveInitialIds(String? compVal, String? cobVal) {
    if (compVal != null && widget.companias.isNotEmpty) {
      final compMatch = widget.companias.firstWhere(
        (c) =>
            c['name']?.toString().trim().toLowerCase() ==
                compVal.trim().toLowerCase() ||
            c['id']?.toString() == compVal,
        orElse: () => widget.companias.first,
      );
      _selectedCompaniaId = compMatch['id']?.toString();
    }

    if (cobVal != null && widget.coberturas.isNotEmpty) {
      final cobMatch = widget.coberturas.firstWhere(
        (c) =>
            c['name']?.toString().trim().toLowerCase() ==
                cobVal.trim().toLowerCase() ||
            c['id']?.toString() == cobVal,
        orElse: () => widget.coberturas.first,
      );
      _selectedCoberturaId = cobMatch['id']?.toString();
    }
  }

  DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is DateTime) return date;
    final str = date.toString().trim();
    if (str.isEmpty) return null;

    try {
      return DateFormat('yyyy-MM-dd').parse(str);
    } catch (_) {}

    try {
      return DateFormat('dd/MM/yyyy').parse(str);
    } catch (_) {}

    try {
      return DateTime.parse(str);
    } catch (_) {}

    return null;
  }

  @override
  void dispose() {
    _polizaNumController.dispose();
    _deducibleController.dispose();
    _montoController.dispose();
    _observacionesController.dispose();
    _fechaInicioController.dispose();
    _fechaVencimientoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context, {
    required String title,
    DateTime? initialDate,
    required ValueChanged<DateTime> onDateSelected,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: title,
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
      onDateSelected(picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompaniaId == null || _selectedCompaniaId!.isEmpty) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona una compañía aseguradora.',
      );
      return;
    }

    if (_selectedCoberturaId == null || _selectedCoberturaId!.isEmpty) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona el tipo de cobertura.',
      );
      return;
    }

    if (_selectedFechaInicio == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de inicio del seguro.',
      );
      return;
    }

    if (_selectedFechaVencimiento == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de vencimiento.',
      );
      return;
    }

    if (_selectedFechaInicio!.isAfter(_selectedFechaVencimiento!)) {
      SnackbarTop.showInfo(
        context,
        'La fecha de inicio no puede ser posterior a la fecha de vencimiento.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String polizaNum = _polizaNumController.text.trim();
    final double deducible =
        double.tryParse(_deducibleController.text.trim()) ?? 0.0;
    final double monto = double.tryParse(_montoController.text.trim()) ?? 0.0;
    final String observaciones = _observacionesController.text.trim();

    final String formattedFechaInicio =
        DateFormat('yyyy-MM-dd').format(_selectedFechaInicio!);
    final String formattedFechaVencimiento =
        DateFormat('yyyy-MM-dd').format(_selectedFechaVencimiento!);

    final vehicleId = widget.vehicle['id'].toString();
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        '';

    try {
      if (widget.isEditing) {
        // --- ACTUALIZACIÓN DE SEGURO ---
        await VehiclesconService().actualizarSeguroPorVehiculo(
          vehicleId,
          widget.idMainAccount,
          _selectedCompaniaId!,
          polizaNum,
          _selectedCoberturaId!,
          formattedFechaInicio,
          formattedFechaVencimiento,
          deducible,
          monto,
          observaciones,
        );

        // Notificación de actualización
        try {
          const nameNotice = 'vehicle_insurance_updated';
          final noticeTemplate =
              await NotificationService().getNoticeByName(nameNotice);

          if (noticeTemplate != null) {
            String message = '';
            final rawMsg = noticeTemplate['message'];
            if (rawMsg is List<int>) {
              try {
                message = utf8.decode(rawMsg);
              } catch (_) {
                message = rawMsg.toString();
              }
            } else {
              message = rawMsg?.toString() ?? '';
            }

            final formattedMessage = message
                .replaceAll('{vehicle_plate}', plates)
                .replaceAll('{policy_number}', polizaNum)
                .replaceAll('{contract_date}', formattedFechaInicio)
                .replaceAll('{expiry_date}', formattedFechaVencimiento);

            final title = (noticeTemplate['title']?.toString() ?? '')
                .replaceAll('{vehicle_plate}', plates);

            final finalMessage =
                '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

            final int idinsurance = widget.initialData != null
                ? (int.tryParse(widget.initialData!['id']?.toString() ?? '0') ??
                    0)
                : 0;

            await NotificationService().insertNotification({
              'typeSource': widget.typeSource,
              'idOrigin': idinsurance,
              'typEvent': 2,
              'date': DateTime.now().toIso8601String(),
              'message': finalMessage,
              'colNotice': 'insurace_Edit',
              'idMainAcoount': widget.idMainAccount,
              'codUsGenerator': widget.userId,
              'idDev': widget.userId,
            });
          }
        } catch (notifErr) {
          debugPrint(
              'Error en notificación de actualización de seguro: $notifErr');
        }

        // Actualizar control de gestión
        await VehiclesconService().updateManagementControlINS(
          widget.idMainAccount,
          vehicleId,
          _selectedFechaVencimiento!.toUtc().toIso8601String(),
        );

        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess();
          SnackbarTop.showSuccess(
            context,
            'Seguro actualizado exitosamente.',
          );
        }
      } else {
        // --- CREACIÓN DE SEGURO ---
        final int idinsurance = await VehiclesconService().crearSeguro(
          vehicleId,
          _selectedCompaniaId!,
          widget.idMainAccount,
          polizaNum,
          _selectedCoberturaId!,
          formattedFechaInicio,
          formattedFechaVencimiento,
          deducible.toString(),
          monto.toString(),
          observaciones,
        );

        // Notificación de nuevo seguro
        try {
          const nameNotice = 'vehicle_insurance_added';
          final noticeTemplate =
              await NotificationService().getNoticeByName(nameNotice);

          if (noticeTemplate != null) {
            String message = '';
            final rawMsg = noticeTemplate['message'];
            if (rawMsg is List<int>) {
              try {
                message = utf8.decode(rawMsg);
              } catch (_) {
                message = rawMsg.toString();
              }
            } else {
              message = rawMsg?.toString() ?? '';
            }

            final formattedMessage = message
                .replaceAll('{vehicle_plate}', plates)
                .replaceAll('{policy_number}', polizaNum)
                .replaceAll('{contract_date}', formattedFechaInicio)
                .replaceAll('{expiry_date}', formattedFechaVencimiento);

            final title = (noticeTemplate['title']?.toString() ?? '')
                .replaceAll('{vehicle_plate}', plates);

            final finalMessage =
                '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

            await NotificationService().insertNotification({
              'typeSource': widget.typeSource,
              'idOrigin': idinsurance,
              'typEvent': 1,
              'date': DateTime.now().toIso8601String(),
              'message': finalMessage,
              'colNotice': 'insurace_New',
              'idMainAcoount': widget.idMainAccount,
              'codUsGenerator': widget.userId,
              'idDev': widget.userId,
            });
          }
        } catch (notifErr) {
          debugPrint('Error en notificación de creación de seguro: $notifErr');
        }

        // Insertar control de gestión
        await VehiclesconService().insertManagementControlINS(
          widget.idMainAccount,
          vehicleId,
          _selectedFechaVencimiento!,
        );

        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess();
          SnackbarTop.showSuccess(
            context,
            'Seguro creado exitosamente.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error al guardar seguro: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        SnackbarTop.showError(
          context,
          widget.isEditing
              ? 'Error al actualizar el seguro. Intente nuevamente.'
              : 'Error al registrar el seguro. Intente nuevamente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomInset + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicador Cupertino superior
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Encabezado del modal
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEditing
                                ? 'Actualizar Seguro'
                                : 'Nuevo Seguro Vehicular',
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const Text(
                            'Datos de póliza, cobertura y aseguradora',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Campo: Selector de Compañía Aseguradora
                _buildDropdownField(
                  label: 'COMPAÑÍA ASEGURADORA',
                  icon: Icons.business_rounded,
                  items: widget.companias,
                  selectedValue: _selectedCompaniaId,
                  hintText: 'Selecciona la aseguradora',
                  onChanged: (val) {
                    setState(() {
                      _selectedCompaniaId = val;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Campo: Selector de Tipo de Cobertura
                _buildDropdownField(
                  label: 'TIPO DE COBERTURA',
                  icon: Icons.shield_outlined,
                  items: widget.coberturas,
                  selectedValue: _selectedCoberturaId,
                  hintText: 'Selecciona el tipo de cobertura',
                  onChanged: (val) {
                    setState(() {
                      _selectedCoberturaId = val;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Campo: Número de Póliza
                _buildAppleTextField(
                  label: 'NÚMERO DE PÓLIZA',
                  controller: _polizaNumController,
                  icon: Icons.description_outlined,
                  maxLength: 30,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el número de póliza.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Fila: Deducible y Monto
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildAppleTextField(
                        label: 'DEDUCIBLE (\$)',
                        controller: _deducibleController,
                        icon: Icons.percent_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa deducible.';
                          }
                          final double? val = double.tryParse(value.trim());
                          if (val == null || val < 0) {
                            return 'Inválido.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAppleTextField(
                        label: 'MONTO / PRIMA (\$)',
                        controller: _montoController,
                        icon: Icons.attach_money_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa monto.';
                          }
                          final double? val = double.tryParse(value.trim());
                          if (val == null || val < 0) {
                            return 'Inválido.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Fila: Fechas de Inicio y Vencimiento
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildAppleDateField(
                        label: 'FECHA INICIO',
                        controller: _fechaInicioController,
                        icon: Icons.event_available_rounded,
                        hintText: 'Fecha inicio',
                        onTap: () {
                          _selectDate(
                            context,
                            title: 'Fecha de Inicio',
                            initialDate: _selectedFechaInicio,
                            onDateSelected: (date) {
                              setState(() {
                                _selectedFechaInicio = date;
                                _fechaInicioController.text =
                                    DateFormat('dd / MM / yyyy').format(date);
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAppleDateField(
                        label: 'VENCIMIENTO',
                        controller: _fechaVencimientoController,
                        icon: Icons.event_busy_rounded,
                        hintText: 'Fecha fin',
                        onTap: () {
                          _selectDate(
                            context,
                            title: 'Fecha de Vencimiento',
                            initialDate: _selectedFechaVencimiento,
                            onDateSelected: (date) {
                              setState(() {
                                _selectedFechaVencimiento = date;
                                _fechaVencimientoController.text =
                                    DateFormat('dd / MM / yyyy').format(date);
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Campo: Observaciones
                _buildAppleTextField(
                  label: 'OBSERVACIONES (OPCIONAL)',
                  controller: _observacionesController,
                  icon: Icons.notes_rounded,
                  maxLength: 80,
                ),
                const SizedBox(height: 24),

                LoadingActionButton(
                  text:
                      widget.isEditing ? 'Actualizar Seguro' : 'Guardar Seguro',
                  icon: widget.isEditing
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  isLoading: _isLoading,
                  height: 48,
                  borderRadius: 14,
                  onPressed: _submitForm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required String? selectedValue,
    required String hintText,
    required ValueChanged<String?> onChanged,
  }) {
    String? validValue = selectedValue;
    if (validValue != null &&
        !items.any((it) => it['id']?.toString() == validValue)) {
      validValue = items.isNotEmpty ? items.first['id']?.toString() : null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField2<String>(
          value: validValue,
          isExpanded: true,
          hint: Text(
            hintText,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            prefixIcon: Icon(
              icon,
              size: 18,
              color: const Color(0xFF0284C7),
            ),
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
          items: items.map((it) {
            final name = it['name']?.toString() ?? 'Opción';
            return DropdownMenuItem<String>(
              value: it['id']?.toString(),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          dropdownStyleData: DropdownStyleData(
            maxHeight: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(
            padding: EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildAppleTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            counterText: '',
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0284C7)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppleDateField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: IgnorePointer(
            child: TextFormField(
              controller: controller,
              readOnly: true,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon:
                    Icon(icon, size: 18, color: const Color(0xFF0284C7)),
                suffixIcon: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Color(0xFF64748B),
                  size: 24,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/verification_model.dart';
import 'package:mark_v3/providers/Vehicles_/verification_provider.dart';
import 'package:mark_v3/services/mark_api_client.dart';

// Autor: Josue Hernandez
class VerificationsPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
  final String verificationsPermission;
  final String idMainAccount;
  final String userId;

  const VerificationsPage({
    super.key,
    required this.vehicle,
    required this.verificationsPermission,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  ConsumerState<VerificationsPage> createState() => _VerificationsPageState();
}

class _VerificationsPageState extends ConsumerState<VerificationsPage> {
  String _typeSource = '';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  late Future<List<Map<String, dynamic>>> _hologramasFuture;

  @override
  void initState() {
    super.initState();
    _hologramasFuture = VehiclesconService().obtenerHolograma();
    _fetchTypeSource();
    Future.microtask(() => _refreshData());
  }

  Future<void> _fetchTypeSource() async {
    try {
      final Map<String, dynamic> data =
          await NotificationService().gettypSource('vehic_verification');
      if (mounted && data.containsKey('id')) {
        setState(() {
          _typeSource = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error al obtener typeSource de verificación: $e');
    }
  }

  Future<void> _refreshData() async {
    await ref.read(verificationProvider.notifier).loadVerifications(
          vehicleId: widget.vehicle['id'].toString(),
          userId: widget.idMainAccount.toString(),
        );
  }

  // --- PERMISOS BITWISE Y FLOTA (Nelson doc) ---
  bool get _canEdit =>
      MarkApiClient.instance.flota.can('verificacion', 'editar') ||
      ((int.tryParse(widget.verificationsPermission) ?? 0) & 8 == 8);

  bool get _canDelete => false;

  bool get _canCreate =>
      MarkApiClient.instance.flota.can('verificacion', 'crear') ||
      ((int.tryParse(widget.verificationsPermission) ?? 0) & 4 == 4);

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

    final verifState = ref.watch(verificationProvider);

    if (verifState.isConnectionError) {
      return ConnectionErrorPage(onRetry: _refreshData);
    }
    if (verifState.isServerError) {
      return ServerErrorPage(onRetry: _refreshData);
    }
    if (verifState.isUnexpectedError) {
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
                  _buildHeader(context, verifState),
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
                              'Modo solo lectura: Tu rol cuenta con permisos para consultar la verificación vehicular y sus hologramas, pero no para registrar o modificar datos.',
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
                  Builder(
                    builder: (context) {
                      if (verifState.isLoading) {
                        return _buildSkeleton(isSmallScreen);
                      } else if (verifState.verifications.isEmpty) {
                        return _buildEmptyState();
                      } else {
                        final verificacion = verifState.verifications.first;
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: _hologramasFuture,
                          builder: (context, holoSnapshot) {
                            final hologramas = holoSnapshot.data ?? [];
                            return _buildVerificationDetails(
                                verificacion, hologramas);
                          },
                        );
                      }
                    },
                  ),
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
  Widget _buildHeader(BuildContext context, VerificationState verifState) {
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
                'Verificación Vehicular',
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
        _buildHeaderActionMenu(context, verifState),
      ],
    );
  }

  Widget _buildHeaderActionMenu(
      BuildContext context, VerificationState verifState) {
    final List<PopupMenuEntry<String>> menuItems = [];
    final bool hasVerifications = verifState.verifications.isNotEmpty;

    if (hasVerifications && _canEdit) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'edit',
          title: 'Editar Verificación',
          icon: Icons.edit_rounded,
          iconColor: const Color(0xFF0284C7),
        ),
      );
    }

    if (hasVerifications && _canDelete) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'delete',
          title: 'Eliminar Verificación',
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFEF4444),
          textColor: const Color(0xFFEF4444),
        ),
      );
    }

    if (!hasVerifications && _canCreate) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'create',
          title: 'Registrar Verificación',
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
        tooltip: 'Opciones de verificación',
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
            _openVerificationModal(
                isEditing: true, initialData: verifState.verifications.first);
          } else if (action == 'delete') {
            _showDeleteConfirmationDialog();
          } else if (action == 'create') {
            _openVerificationModal(isEditing: false);
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
              'Error al cargar las verificaciones',
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
  // ESTADO VACÍO (SIN VERIFICACIONES REGISTRADAS)
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
                Icons.eco_rounded,
                color: Color(0xFF0284C7),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin Verificaciones Registradas',
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
              'No se encontró ningún trámite de verificación o inspección ambiental registrado para $plates.',
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
                text: 'Registrar Verificación',
                icon: Icons.add_circle_outline_rounded,
                isLoading: false,
                height: 46,
                borderRadius: 14,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onPressed: () => _openVerificationModal(isEditing: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // DETALLES DE LA VERIFICACIÓN (HERO CARD COLOR EMERALD / ECO APPLE WALLET)
  // =========================================================================
  Widget _buildVerificationDetails(
      VerificationModel verificacion, List<Map<String, dynamic>> hologramas) {
    String hologramName = verificacion.idHolograma.toString();
    if (hologramas.isNotEmpty) {
      final match = hologramas.firstWhere(
        (h) => h['id']?.toString() == verificacion.idHolograma.toString(),
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty && match['name'] != null) {
        hologramName = match['name'].toString();
      }
    }
    final hologram =
        hologramName.trim().isNotEmpty ? hologramName : 'Sin Holograma';
    final fechaVerificacionStr =
        _formatDisplayDate(verificacion.fecVerificacion);
    final proximaVerificStr = _formatDisplayDate(verificacion.proximaVerific);

    final monto = double.tryParse(verificacion.monto) ?? 0.0;

    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'OFICIAL';

    final parsedExpiry = _parseDateSafe(verificacion.proximaVerific);

    // Evaluación del estatus de vigencia ambiental
    int daysRemaining = 0;
    bool isExpired = false;
    bool isToday = false;
    bool isClose = false;

    Color badgeBg;
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (parsedExpiry == null) {
      badgeBg = const Color(0xFF0284C7).withOpacity(0.2);
      badgeColor = const Color(0xFF34D399);
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
        // 1. TARJETA DIGITAL APPLE WALLET HERO (DISTINTIVO COLOR VERDE ESMERALDA / BOSQUE PROFUNDO)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF022C22), // Deep Forest Jade
                Color(0xFF064E3B), // Deep Emerald
                Color(0xFF059669), // Rich Mint Emerald
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
                color: const Color(0xFF0F172A).withOpacity(0.25),
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
                                    Icons.eco_rounded,
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
                                        'VERIFICACIÓN VEHICULAR',
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
                                        'CONTROL AMBIENTAL · MARK FLEET',
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
                                  color: Color(0xFF34D399),
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

                      // Fila Central: Holograma + Costo
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
                                        Icons.local_activity_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          'HOLOGRAMA: $hologram',
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
                                  'Emisiones y Norma Ambiental',
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
                                  'COSTO REGISTRADO',
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
                                    _currencyFormat.format(monto),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Fila Inferior: Próxima Verificación y Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PRÓXIMA VERIFICACIÓN',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.65),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  proximaVerificStr,
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

        // 2. SECCIÓN: ESTATUS AMBIENTAL Y VIGENCIA
        _buildSectionTitle('ESTATUS AMBIENTAL Y VIGENCIA'),
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
                              : Icons.verified_rounded),
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
                            ? 'Verificación Vehicular Vencida'
                            : (isToday
                                ? 'Verificación Vence el Día de Hoy'
                                : (isClose
                                    ? 'Próxima a Vencer'
                                    : 'Verificación Vigente y en Regla')),
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
                            ? 'Venció hace ${-daysRemaining} días. Se requiere verificar inmediatamente.'
                            : (isToday
                                ? 'El periodo asignado expira hoy a las 23:59 hrs.'
                                : (isClose
                                    ? 'Quedan $daysRemaining días antes de que venza el periodo de verificación.'
                                    : 'Quedan $daysRemaining días de validez para circular conforme a la norma.')),
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
                              ? 'CONDICIÓN: SIN AUTORIZACIÓN PARA CIRCULAR'
                              : (isClose || isToday
                                  ? 'CONDICIÓN: PROGRAMAR CITA DE VERIFICACIÓN'
                                  : 'CONDICIÓN: EN REGLA PARA CIRCULAR'),
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
                              ? 'El móvil puede ser remitido al corralón por circular con verificación vencida.'
                              : 'Holograma avalado para tránsito sin restricciones por contingencia.',
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

        // 3. SECCIÓN: DESGLOSE DE VERIFICACIÓN
        _buildSectionTitle('DESGLOSE DE VERIFICACIÓN'),
        _buildAppleGroupContainer(
          children: [
            _buildDetailRow(
              icon: Icons.local_activity_rounded,
              label: 'Holograma Asignado',
              value: hologram,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_available_rounded,
              label: 'Fecha de Verificación',
              value: fechaVerificacionStr,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_busy_rounded,
              label: 'Próxima Verificación',
              value: proximaVerificStr,
            ),
            const Divider(height: 20, color: Color(0xFFE2E8F0)),
            _buildDetailRow(
              icon: Icons.monetization_on_outlined,
              label: 'Monto del Trámite',
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
                isHighlight ? const Color(0xFFD1FAE5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 16,
            color:
                isHighlight ? const Color(0xFF059669) : const Color(0xFF64748B),
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
                isHighlight ? const Color(0xFF059669) : const Color(0xFF0F172A),
            letterSpacing: isHighlight ? -0.2 : 0,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // MODAL BOTTOM SHEET DE FORMULARIO APPLE (CREAR / EDITAR)
  // =========================================================================
  void _openVerificationModal({
    required bool isEditing,
    VerificationModel? initialData,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _VerificationFormModalSheet(
          isEditing: isEditing,
          initialData: initialData?.toMap(),
          vehicle: widget.vehicle,
          idMainAccount: widget.idMainAccount,
          userId: widget.userId,
          typeSource: _typeSource,
          hologramasFuture: _hologramasFuture,
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
                  mainAxisSize: MainAxisSize.min,
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
                      '¿Eliminar Verificación?',
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
                      'Se borrará el registro de verificación ambiental de las placas $plates. Esta acción no se puede deshacer.',
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
                              await _performDeleteVerification(dialogContext);
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

  Future<void> _performDeleteVerification(BuildContext dialogContext) async {
    try {
      final verificaciones = ref.read(verificationProvider).verifications;

      if (verificaciones.isEmpty) {
        if (mounted) {
          Navigator.of(dialogContext).pop();
          SnackbarTop.showInfo(
            context,
            'No se encontraron verificaciones para eliminar.',
          );
        }
        return;
      }

      final int idverificacion = verificaciones.first.id;
      final String fecVerificacion = verificaciones.first.fecVerificacion;
      final String proximaVerific = verificaciones.first.proximaVerific;

      // 1. Notificación antes o durante eliminación
      try {
        const nameNotice = 'vehicle_verification_deleted';
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
              .replaceAll('{verification_date}', fecVerificacion)
              .replaceAll('{due_date}', proximaVerific);

          final title = (noticeTemplate['title']?.toString() ?? '')
              .replaceAll('{vehicle_plate}', vehiclePlates);

          final finalMessage =
              '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

          await NotificationService().insertNotification({
            'typeSource': _typeSource,
            'idOrigin': idverificacion,
            'typEvent': 3,
            'date': DateTime.now().toIso8601String(),
            'message': finalMessage,
            'colNotice': 'verific_Delete',
            'idMainAcoount': widget.idMainAccount.toString(),
            'codUsGenerator': widget.userId.toString(),
            'idDev': widget.userId.toString(),
          });
        }
      } catch (notifErr) {
        debugPrint(
            'Error al enviar notificación de eliminación de verificación: $notifErr');
      }

      // 2. Eliminar verificación del vehículo
      await VehiclesconService().eliminarVerificacionesPorVehiculo(
        widget.vehicle['id'].toString(),
        widget.idMainAccount.toString(),
      );

      // 3. Eliminar control de gestión
      await VehiclesconService().deleteManagementControlVf(
        widget.idMainAccount.toString(),
        widget.vehicle['id'].toString(),
      );

      if (mounted) {
        Navigator.of(dialogContext).pop();
        _refreshData();
        SnackbarTop.showSuccess(
          context,
          'Verificación eliminada correctamente.',
        );
      }
    } catch (e) {
      debugPrint('Error al eliminar verificación: $e');
      if (mounted) {
        Navigator.of(dialogContext).pop();
        SnackbarTop.showError(
          context,
          'Error al eliminar la verificación. Intente nuevamente.',
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
// MODAL SHEET FORMULARIO APPLE PARA CREAR / EDITAR VERIFICACIÓN
// ===========================================================================
class _VerificationFormModalSheet extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic> vehicle;
  final String idMainAccount;
  final String userId;
  final String typeSource;
  final Future<List<Map<String, dynamic>>> hologramasFuture;
  final VoidCallback onSuccess;

  const _VerificationFormModalSheet({
    required this.isEditing,
    this.initialData,
    required this.vehicle,
    required this.idMainAccount,
    required this.userId,
    required this.typeSource,
    required this.hologramasFuture,
    required this.onSuccess,
  });

  @override
  State<_VerificationFormModalSheet> createState() =>
      _VerificationFormModalSheetState();
}

class _VerificationFormModalSheetState
    extends State<_VerificationFormModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _fechaVerificacionController = TextEditingController();
  final _proximaVerificController = TextEditingController();

  String? _selectedHologramId;
  DateTime? _selectedFechaVerificacion;
  DateTime? _selectedProximaVerific;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialData != null) {
      final d = widget.initialData!;
      _montoController.text = d['monto']?.toString() ?? '0';

      _selectedFechaVerificacion = _parseDate(d['fecVerificacion']);
      if (_selectedFechaVerificacion != null) {
        _fechaVerificacionController.text =
            DateFormat('dd / MM / yyyy').format(_selectedFechaVerificacion!);
      }

      _selectedProximaVerific = _parseDate(d['proximaVerific']);
      if (_selectedProximaVerific != null) {
        _proximaVerificController.text =
            DateFormat('dd / MM / yyyy').format(_selectedProximaVerific!);
      }

      _resolveInitialHologramId(d['idHolograma']?.toString());
    }
  }

  void _resolveInitialHologramId(String? hologramValue) async {
    if (hologramValue == null || hologramValue.isEmpty) return;

    try {
      final list = await widget.hologramasFuture;
      final match = list.firstWhere(
        (h) =>
            h['name']?.toString().trim().toLowerCase() ==
                hologramValue.trim().toLowerCase() ||
            h['id']?.toString() == hologramValue,
        orElse: () => list.isNotEmpty ? list.first : {'id': '1'},
      );

      if (mounted) {
        setState(() {
          _selectedHologramId = match['id']?.toString();
        });
      }
    } catch (_) {}
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
    _montoController.dispose();
    _fechaVerificacionController.dispose();
    _proximaVerificController.dispose();
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

    if (_selectedHologramId == null || _selectedHologramId!.isEmpty) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona un holograma.',
      );
      return;
    }

    if (_selectedFechaVerificacion == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de realización de la verificación.',
      );
      return;
    }

    if (_selectedProximaVerific == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de próxima verificación.',
      );
      return;
    }

    if (_selectedFechaVerificacion!.isAfter(_selectedProximaVerific!)) {
      SnackbarTop.showInfo(
        context,
        'La fecha de verificación no puede ser posterior a la próxima verificación.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String formattedFechaVerificacion =
        DateFormat('yyyy-MM-dd').format(_selectedFechaVerificacion!);
    final String formattedProximaVerific =
        DateFormat('yyyy-MM-dd').format(_selectedProximaVerific!);
    final double monto = double.tryParse(_montoController.text.trim()) ?? 0.0;

    final vehicleId = widget.vehicle['id'].toString();
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        '';

    try {
      if (widget.isEditing) {
        // --- ACTUALIZACIÓN DE VERIFICACIÓN ---
        await VehiclesconService().actualizarVerificacionPorVehiculo(
          vehicleId,
          widget.idMainAccount,
          _selectedHologramId!,
          formattedFechaVerificacion,
          formattedProximaVerific,
          monto,
        );

        // Notificación de actualización
        try {
          const nameNotice = 'vehicle_verification_updated';
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
                .replaceAll('{verification_date}', formattedFechaVerificacion)
                .replaceAll('{due_date}', formattedProximaVerific);

            final title = (noticeTemplate['title']?.toString() ?? '')
                .replaceAll('{vehicle_plate}', plates);

            final finalMessage =
                '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

            final int idverificacion = widget.initialData != null
                ? (int.tryParse(widget.initialData!['id']?.toString() ?? '0') ??
                    0)
                : 0;

            await NotificationService().insertNotification({
              'typeSource': widget.typeSource,
              'idOrigin': idverificacion,
              'typEvent': 2,
              'date': DateTime.now().toIso8601String(),
              'message': finalMessage,
              'colNotice': 'verific_Edit',
              'idMainAcoount': widget.idMainAccount,
              'codUsGenerator': widget.userId,
              'idDev': widget.userId,
            });
          }
        } catch (notifErr) {
          debugPrint(
              'Error en notificación de actualización de verificación: $notifErr');
        }

        // Actualizar control de gestión
        await VehiclesconService().updateManagementControlVf(
          widget.idMainAccount,
          vehicleId,
          formattedProximaVerific,
        );

        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess();
          SnackbarTop.showSuccess(
            context,
            'Verificación actualizada exitosamente.',
          );
        }
      } else {
        // --- CREACIÓN DE VERIFICACIÓN ---
        final int idverificacion = await VehiclesconService().crearVerificacion(
          vehicleId,
          _selectedHologramId!,
          widget.idMainAccount,
          formattedFechaVerificacion,
          formattedProximaVerific,
          monto,
          '1',
        );

        // Notificación de nueva verificación
        try {
          const nameNotice = 'vehicle_verification_added';
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
                .replaceAll('{verification_date}', formattedFechaVerificacion)
                .replaceAll('{due_date}', formattedProximaVerific);

            final title = (noticeTemplate['title']?.toString() ?? '')
                .replaceAll('{vehicle_plate}', plates);

            final finalMessage =
                '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

            await NotificationService().insertNotification({
              'typeSource': widget.typeSource,
              'idOrigin': idverificacion,
              'typEvent': 1,
              'date': DateTime.now().toIso8601String(),
              'message': finalMessage,
              'colNotice': 'verific_New',
              'idMainAcoount': widget.idMainAccount,
              'codUsGenerator': widget.userId,
              'idDev': widget.userId,
            });
          }
        } catch (notifErr) {
          debugPrint(
              'Error en notificación de creación de verificación: $notifErr');
        }

        // Insertar control de gestión
        await VehiclesconService().insertManagementControlVf(
          widget.idMainAccount,
          vehicleId,
          _selectedProximaVerific!,
        );

        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess();
          SnackbarTop.showSuccess(
            context,
            'Verificación creada correctamente.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error al guardar verificación: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        SnackbarTop.showError(
          context,
          widget.isEditing
              ? 'Error al actualizar la verificación. Intente nuevamente.'
              : 'Error al registrar la verificación. Intente nuevamente.',
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
                        Icons.eco_rounded,
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
                                ? 'Actualizar Verificación'
                                : 'Nueva Verificación Vehicular',
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const Text(
                            'Datos de inspección y holograma ambiental',
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

                // Campo: Selector de Holograma
                _buildHologramDropdownField(),
                const SizedBox(height: 14),

                // Campo: Fecha de Verificación
                _buildAppleDateField(
                  label: 'FECHA DE VERIFICACIÓN',
                  controller: _fechaVerificacionController,
                  icon: Icons.event_available_rounded,
                  hintText: 'Selecciona la fecha de realización',
                  onTap: () {
                    _selectDate(
                      context,
                      title: 'Fecha de Verificación',
                      initialDate: _selectedFechaVerificacion,
                      onDateSelected: (date) {
                        setState(() {
                          _selectedFechaVerificacion = date;
                          _fechaVerificacionController.text =
                              DateFormat('dd / MM / yyyy').format(date);
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Campo: Próxima Verificación
                _buildAppleDateField(
                  label: 'PRÓXIMA VERIFICACIÓN',
                  controller: _proximaVerificController,
                  icon: Icons.event_busy_rounded,
                  hintText: 'Selecciona la fecha límite / vencimiento',
                  onTap: () {
                    _selectDate(
                      context,
                      title: 'Próxima Verificación',
                      initialDate: _selectedProximaVerific,
                      onDateSelected: (date) {
                        setState(() {
                          _selectedProximaVerific = date;
                          _proximaVerificController.text =
                              DateFormat('dd / MM / yyyy').format(date);
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Campo: Monto
                _buildAppleTextField(
                  label: 'MONTO DEL TRÁMITE (\$)',
                  controller: _montoController,
                  icon: Icons.attach_money_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el costo del trámite.';
                    }
                    final double? val = double.tryParse(value.trim());
                    if (val == null || val < 0) {
                      return 'Ingresa un monto válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Botón de acción con estilo verde esmeralda Apple
                LoadingActionButton(
                  text: widget.isEditing
                      ? 'Actualizar Verificación'
                      : 'Guardar Verificación',
                  icon: widget.isEditing
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  isLoading: _isLoading,
                  height: 48,
                  borderRadius: 14,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0284C7),
                      Color(0xFF0369A1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onPressed: _submitForm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHologramDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HOLOGRAMA AMBIENTAL',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: widget.hologramasFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppShimmerBox(
                width: double.infinity,
                height: 48,
                borderRadius: 12,
              );
            }

            final hologramas = snapshot.data ?? [];
            if (hologramas.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'No hay hologramas disponibles',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              );
            }

            // Validar que el holograma seleccionado exista en la lista
            if (_selectedHologramId == null ||
                !hologramas
                    .any((h) => h['id']?.toString() == _selectedHologramId)) {
              _selectedHologramId = hologramas.first['id']?.toString();
            }

            return DropdownButtonFormField2<String>(
              value: _selectedHologramId,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                prefixIcon: const Icon(
                  Icons.local_activity_rounded,
                  size: 18,
                  color: Color(0xFF0284C7),
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
              items: hologramas.map((holograma) {
                final name = holograma['name']?.toString() ?? 'Holograma';
                return DropdownMenuItem<String>(
                  value: holograma['id']?.toString(),
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
              onChanged: (value) {
                setState(() {
                  _selectedHologramId = value;
                });
              },
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
            );
          },
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

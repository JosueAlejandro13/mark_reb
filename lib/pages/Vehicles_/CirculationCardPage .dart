import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:mark_v3/models/Vehicles_/circulation_card_model.dart';
import 'package:mark_v3/providers/Vehicles_/circulation_card_provider.dart';
import 'package:mark_v3/services/mark_api_client.dart';

// Autor: Josue Hernandez
class CirculationCardPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
  final String circulationCardPermission;
  final String idMainAccount;
  final String userId;

  const CirculationCardPage({
    super.key,
    required this.vehicle,
    required this.circulationCardPermission,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  ConsumerState<CirculationCardPage> createState() =>
      _CirculationCardPageState();
}

class _CirculationCardPageState extends ConsumerState<CirculationCardPage> {
  String _typeSource = '';
  bool _isDisposed = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _fetchTypeSource();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCirculationCard();
    });
  }

  void _loadCirculationCard() {
    ref.read(circulationCardProvider.notifier).fetchCards(
          widget.vehicle['id'].toString(),
          widget.idMainAccount.toString(),
        );
  }

  Future<void> _fetchTypeSource() async {
    if (_isDisposed || !mounted) return;
    try {
      final Map<String, dynamic> data =
          await NotificationService().gettypSource('vehic_circulationCard');
      if (!_isDisposed && mounted && data.containsKey('id')) {
        setState(() {
          _typeSource = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error al obtener typeSource de tarjeta de circulación: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isDisposed || !mounted) return;
    _loadCirculationCard();
  }

  void _handleError(dynamic error) {
    if (_isDisposed || !mounted) return;

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
      debugPrint('Error al obtener la tarjeta de circulación: $error');
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
      MarkApiClient.instance.flota.can('tarjeta', 'editar') ||
      ((int.tryParse(widget.circulationCardPermission) ?? 0) & 8 == 8);

  bool get _canDelete => false;

  bool get _canCreate =>
      MarkApiClient.instance.flota.can('tarjeta', 'crear') ||
      ((int.tryParse(widget.circulationCardPermission) ?? 0) & 4 == 4);

  // --- FORMATEO Y PARSEO DE FECHAS SEGURO ---
  String _formatDisplayDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) {
      return DateFormat('dd / MM / yyyy').format(date);
    }
    final str = date.toString().trim();
    if (str.isEmpty) return 'N/A';

    try {
      final parsed = DateFormat('yyyy-MM-dd').parse(str);
      return DateFormat('dd / MM / yyyy').format(parsed);
    } catch (_) {}

    try {
      final parsed = DateFormat('dd/MM/yyyy').parse(str);
      return DateFormat('dd / MM / yyyy').format(parsed);
    } catch (_) {}

    try {
      final parsed = DateTime.parse(str);
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
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    final cardState = ref.watch(circulationCardProvider);

    if (cardState.isConnectionError) {
      return ConnectionErrorPage(onRetry: _refreshData);
    }
    if (cardState.isServerError) {
      return ServerErrorPage(onRetry: _refreshData);
    }
    if (cardState.isUnexpectedError) {
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
                              'Modo solo lectura: Tu rol cuenta con permisos para consultar la tarjeta de circulación y sus vigencias, pero no para registrar o modificar datos.',
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
                  if (cardState.isLoading)
                    _buildSkeleton(isSmallScreen)
                  else if (cardState.cards.isEmpty)
                    _buildEmptyState()
                  else
                    _buildCardDetails(cardState.cards.first),
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
                'Tarjeta de Circulación',
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
    final hasCirculationCard =
        ref.watch(circulationCardProvider).cards.isNotEmpty;

    if (hasCirculationCard && _canEdit) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'edit',
          title: 'Editar Tarjeta',
          icon: Icons.edit_rounded,
          iconColor: const Color(0xFF0284C7),
        ),
      );
    }

    if (hasCirculationCard && _canDelete) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'delete',
          title: 'Eliminar Tarjeta',
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFEF4444),
          textColor: const Color(0xFFEF4444),
        ),
      );
    }

    if (!hasCirculationCard && _canCreate) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'create',
          title: 'Registrar Tarjeta',
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
        tooltip: 'Opciones de tarjeta',
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
            final cards = ref.read(circulationCardProvider).cards;
            if (cards.isNotEmpty) {
              _openCardModal(isEditing: true, initialData: cards.first.toMap());
            }
          } else if (action == 'delete') {
            _showDeleteConfirmationDialog();
          } else if (action == 'create') {
            _openCardModal(isEditing: false);
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
  // SKELETON LOADER CON APPSHIMMERBOX
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
              'Error al cargar la tarjeta de circulación',
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
  // ESTADO VACÍO (SIN TARJETA REGISTRADA)
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
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 16,
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
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                color: Color(0xFF0284C7),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin Tarjeta de Circulación',
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
              'No se encontró ningún registro oficial de tarjeta de circulación para $plates.',
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
                text: 'Registrar Tarjeta',
                icon: Icons.add_circle_outline_rounded,
                isLoading: false,
                height: 46,
                borderRadius: 14,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onPressed: () => _openCardModal(isEditing: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // DETALLES DE LA TARJETA (HERO WALLET CARD COLOR VINO / BURGUNDY / RUBÍ)
  // OJO: Solo la carta cambia a color vino / rubí, todos los inputs y botones quedan estándar azul
  // =========================================================================
  Widget _buildCardDetails(CirculationCardModel tarjeta) {
    final numTarjeta = tarjeta.numTarjeta.trim().isNotEmpty
        ? tarjeta.numTarjeta
        : 'Sin Número';
    final fecExpStr = _formatDisplayDate(tarjeta.fecExpedicion);
    final fecVenStr = _formatDisplayDate(tarjeta.fecVencimiento);

    final monto = double.tryParse(tarjeta.monto) ?? 0.0;

    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'OFICIAL';

    final parsedExpiry = _parseDateSafe(tarjeta.fecVencimiento);

    // Evaluación del estatus de vigencia
    int daysRemaining = 0;
    bool isExpired = false;
    bool isToday = false;
    bool isClose = false;

    Color badgeBg;
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (parsedExpiry == null) {
      badgeBg = const Color(0xFFBE123C).withOpacity(0.2);
      badgeColor = const Color(0xFFFDA4AF);
      badgeText = 'PERMANENTE';
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
        // 1. TARJETA DIGITAL APPLE WALLET HERO (DISTINTIVO COLOR AZUL PETRÓLEO / TURQUESA OCEÁNICO)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF042F2E), // Deep Obsidian Petrol Teal
                Color(0xFF0F766E), // Rich Oceanic Emerald Teal
                Color(0xFF0D9488), // Luminous Executive Teal
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
                color: const Color(0xFF042F2E).withOpacity(0.30),
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
                                    Icons.credit_card_rounded,
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
                                        'TARJETA DE CIRCULACIÓN',
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
                                        'REGISTRO VEHICULAR OFICIAL · MARK FLEET',
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
                                  color: Color(0xFF5EEAD4),
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

                      // Fila Central: Número de Tarjeta y Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FOLIO DE TARJETA',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.65),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  numTarjeta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
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
                              borderRadius: BorderRadius.circular(10),
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
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Fila Inferior: Expedición, Vencimiento, Monto
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'EXPEDICIÓN',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withOpacity(0.55),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    fecExpStr,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: Colors.white.withOpacity(0.12),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'VENCIMIENTO',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.55),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      fecVenStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isExpired
                                            ? const Color(0xFFFCA5A5)
                                            : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: Colors.white.withOpacity(0.12),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DERECHOS',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.55),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _currencyFormat.format(monto),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFDE047),
                                      ),
                                    ),
                                  ],
                                ),
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
        ),
        const SizedBox(height: 18),

        // 2. SECCIÓN: ESTATUS & VIGENCIA OFICIAL
        _buildSectionTitle('ESTATUS & VIGENCIA OFICIAL'),
        _buildAppleGroupContainer(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isExpired
                          ? const Color(0xFFFEE2E2)
                          : (isClose || isToday
                              ? const Color(0xFFFFEDD5)
                              : const Color(0xFFDCFCE7)),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      badgeIcon,
                      color: isExpired
                          ? const Color(0xFFEF4444)
                          : (isClose || isToday
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF10B981)),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parsedExpiry == null
                              ? 'Tarjeta con Vigencia Permanente'
                              : (isExpired
                                  ? 'Vencida hace ${daysRemaining.abs()} días'
                                  : (isToday
                                      ? '¡Vence el día de hoy!'
                                      : 'Vigente · Vence en $daysRemaining días')),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isExpired
                                ? const Color(0xFFDC2626)
                                : (isClose || isToday
                                    ? const Color(0xFFC2410C)
                                    : const Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fecha registrada: $fecVenStr',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 22, color: Color(0xFFF1F5F9)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isExpired
                    ? const Color(0xFFFEF2F2)
                    : (isClose || isToday
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF0FDF4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isExpired
                              ? 'TRÁMITE DE RENOVACIÓN URGENTE'
                              : (isClose || isToday
                                  ? 'RENOVACIÓN PRÓXIMA'
                                  : 'DOCUMENTO VIGENTE PARA CIRCULAR'),
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
                              ? 'Renueva el documento en la oficina de control vehicular para evitar remisiones al corralón.'
                              : 'Documento oficial indispensable para libre circulación y trámites vehiculares.',
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

        // 3. SECCIÓN: DETALLES DE LA TARJETA
        _buildSectionTitle('DATOS DE LA TARJETA'),
        _buildAppleGroupContainer(
          children: [
            _buildDetailRow(
              icon: Icons.credit_card_rounded,
              label: 'Número / Folio',
              value: numTarjeta,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Fecha de Expedición',
              value: fecExpStr,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_available_rounded,
              label: 'Fecha de Vencimiento',
              value: fecVenStr,
            ),
            const Divider(height: 20, color: Color(0xFFE2E8F0)),
            _buildDetailRow(
              icon: Icons.attach_money_rounded,
              label: 'Monto / Derechos',
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
                isHighlight ? const Color(0xFFCCFBF1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 16,
            color:
                isHighlight ? const Color(0xFF0F766E) : const Color(0xFF64748B),
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
                isHighlight ? const Color(0xFF0F766E) : const Color(0xFF0F172A),
            letterSpacing: isHighlight ? -0.2 : 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

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
            color: const Color(0xFF0F172A).withOpacity(0.02),
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

  // =========================================================================
  // MODAL DE CONFIRMACIÓN DE ELIMINACIÓN
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
                      '¿Eliminar Tarjeta?',
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
                      'Se borrará la tarjeta de circulación registrada para las placas $plates. Esta acción no se puede deshacer.',
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
                              await _performDeleteCard(dialogContext);
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

  Future<void> _performDeleteCard(BuildContext dialogContext) async {
    try {
      final circu = await VehiclesconService().obtenerTarjetaCirculacion(
        widget.vehicle['id'].toString(),
        widget.idMainAccount.toString(),
      );

      if (circu == null || circu.isEmpty || circu['id'] == null) {
        if (mounted) {
          Navigator.of(dialogContext).pop();
          SnackbarTop.showInfo(
            context,
            'No se encontró la tarjeta de circulación para eliminar.',
          );
        }
        return;
      }

      final int idcircu = circu['id'];
      final String numTar = circu['numTarjeta']?.toString() ?? '';
      final String fecExp = circu['fecExpedicion']?.toString() ?? '';
      final String fecVen = circu['fecVencimiento']?.toString() ?? '';

      // 1. Notificación
      try {
        const nameNotice = 'vehicle_registration_card_deleted';
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
              .replaceAll('{card_number}', numTar)
              .replaceAll('{issue_date}', _formatDisplayDate(fecExp))
              .replaceAll('{expiry_date}', _formatDisplayDate(fecVen));

          final title = (noticeTemplate['title']?.toString() ?? '')
              .replaceAll('{vehicle_plate}', vehiclePlates);

          final finalMessage =
              '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

          await NotificationService().insertNotification({
            'typeSource': _typeSource,
            'idOrigin': idcircu,
            'typEvent': 3,
            'date': DateTime.now().toIso8601String(),
            'message': finalMessage,
            'colNotice': 'tc_Delete',
            'idMainAcoount': widget.idMainAccount.toString(),
            'codUsGenerator': widget.userId.toString(),
            'idDev': widget.userId.toString(),
          });
        }
      } catch (notifErr) {
        debugPrint('Error al enviar notificación de eliminación: $notifErr');
      }

      // 2. Eliminar tarjeta
      await VehiclesconService().eliminarTarjetaCirculacion(
        widget.vehicle['id'].toString(),
        widget.idMainAccount.toString(),
      );

      // 3. Eliminar control de gestión
      await VehiclesconService().deleteManagementControlTJ(
        widget.idMainAccount.toString(),
        widget.vehicle['id'].toString(),
      );

      if (mounted) {
        Navigator.of(dialogContext).pop();
        SnackbarTop.showSuccess(
          context,
          'Tarjeta de circulación eliminada exitosamente.',
        );
        _refreshData();
      }
    } catch (e) {
      debugPrint('Error al eliminar tarjeta de circulación: $e');
      if (mounted) {
        Navigator.of(dialogContext).pop();
        SnackbarTop.showError(
          context,
          'Error al eliminar la tarjeta. Inténtalo de nuevo.',
        );
      }
    }
  }

  // =========================================================================
  // MODAL CREAR / EDITAR ESTILO APPLE (BOTTOM SHEET)
  // OJO: Los campos de entrada y botones de acción mantienen el azul estándar Color(0xFF0284C7)
  // =========================================================================
  void _openCardModal({
    required bool isEditing,
    Map<String, dynamic>? initialData,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CirculationCardFormModalSheet(
          isEditing: isEditing,
          initialData: initialData,
          vehicle: widget.vehicle,
          idMainAccount: widget.idMainAccount,
          userId: widget.userId,
          typeSource: _typeSource,
          onSuccess: () {
            _refreshData();
          },
        );
      },
    );
  }
}

// ===========================================================================
// COMPONENTE: MODAL BOTTOM SHEET DE FORMULARIO ESTILO APPLE
// ===========================================================================
class _CirculationCardFormModalSheet extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic> vehicle;
  final String idMainAccount;
  final String userId;
  final String typeSource;
  final VoidCallback onSuccess;

  const _CirculationCardFormModalSheet({
    required this.isEditing,
    this.initialData,
    required this.vehicle,
    required this.idMainAccount,
    required this.userId,
    required this.typeSource,
    required this.onSuccess,
  });

  @override
  State<_CirculationCardFormModalSheet> createState() =>
      _CirculationCardFormModalSheetState();
}

class _CirculationCardFormModalSheetState
    extends State<_CirculationCardFormModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _numTarjetaController = TextEditingController();
  final _fecExpedicionController = TextEditingController();
  final _fecVencimientoController = TextEditingController();
  final _montoController = TextEditingController();

  DateTime? _selectedFechaExpedicion;
  DateTime? _selectedFechaVencimiento;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialData != null) {
      final d = widget.initialData!;
      _numTarjetaController.text = d['numTarjeta']?.toString() ?? '';
      _montoController.text = d['monto']?.toString() ?? '0';

      _selectedFechaExpedicion = _parseDate(d['fecExpedicion']);
      if (_selectedFechaExpedicion != null) {
        _fecExpedicionController.text =
            DateFormat('dd / MM / yyyy').format(_selectedFechaExpedicion!);
      }

      _selectedFechaVencimiento = _parseDate(d['fecVencimiento']);
      if (_selectedFechaVencimiento != null) {
        _fecVencimientoController.text =
            DateFormat('dd / MM / yyyy').format(_selectedFechaVencimiento!);
      }
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
    _numTarjetaController.dispose();
    _fecExpedicionController.dispose();
    _fecVencimientoController.dispose();
    _montoController.dispose();
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

    if (_selectedFechaExpedicion == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de expedición.',
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

    if (_selectedFechaExpedicion!.isAfter(_selectedFechaVencimiento!)) {
      SnackbarTop.showInfo(
        context,
        'La fecha de expedición no puede ser posterior a la fecha de vencimiento.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String numTarjeta = _numTarjetaController.text.trim();
    final double monto = double.tryParse(_montoController.text.trim()) ?? 0.0;

    try {
      if (widget.isEditing) {
        // --- ACTUALIZACIÓN DE TARJETA ---
        final int idVehic = int.parse(widget.vehicle['id'].toString());
        final int idUs = int.parse(widget.idMainAccount.toString());

        await VehiclesconService().actualizarTarjetaCirculacion(
          idVehic,
          idUs,
          numTarjeta,
          DateFormat('yyyy-MM-dd').format(_selectedFechaExpedicion!),
          DateFormat('yyyy-MM-dd').format(_selectedFechaVencimiento!),
          monto,
        );

        // Notificación de actualización
        try {
          final circu = await VehiclesconService().obtenerTarjetaCirculacion(
            widget.vehicle['id'].toString(),
            widget.idMainAccount.toString(),
          );

          if (circu != null && circu.isNotEmpty && circu['id'] != null) {
            final int idcircu = circu['id'];
            const nameNotice = 'vehicle_registration_card_updated';
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
                  .replaceAll('{card_number}', numTarjeta)
                  .replaceAll(
                      '{issue_date}',
                      DateFormat('dd/MM/yyyy')
                          .format(_selectedFechaExpedicion!))
                  .replaceAll(
                      '{expiry_date}',
                      DateFormat('dd/MM/yyyy')
                          .format(_selectedFechaVencimiento!));

              final title = (noticeTemplate['title']?.toString() ?? '')
                  .replaceAll('{vehicle_plate}', vehiclePlates);

              final finalMessage =
                  '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

              await NotificationService().insertNotification({
                'typeSource': widget.typeSource,
                'idOrigin': idcircu,
                'typEvent': 2,
                'date': DateTime.now().toIso8601String(),
                'message': finalMessage,
                'colNotice': 'tc_Edit',
                'idMainAcoount': widget.idMainAccount.toString(),
                'codUsGenerator': widget.userId.toString(),
                'idDev': widget.userId.toString(),
              });
            }
          }
        } catch (notifErr) {
          debugPrint(
              'Error al enviar notificación de actualización: $notifErr');
        }

        // Actualizar control de gestión
        await VehiclesconService().updateManagementControlTJ(
          idUs,
          idVehic,
          DateFormat('yyyy-MM-dd').format(_selectedFechaVencimiento!),
        );

        if (mounted) {
          Navigator.of(context).pop();
          SnackbarTop.showSuccess(
            context,
            'Tarjeta de circulación actualizada exitosamente.',
          );
          widget.onSuccess();
        }
      } else {
        // --- CREACIÓN DE NUEVA TARJETA ---
        final DateTime fechaExpUTC = _selectedFechaExpedicion!.toUtc();
        final DateTime fechaVenUTC = _selectedFechaVencimiento!.toUtc();

        await VehiclesconService().crearTarjetaCirculacion(
          widget.vehicle['id'].toString(),
          widget.idMainAccount.toString(),
          numTarjeta,
          fechaExpUTC,
          fechaVenUTC,
          monto,
        );

        // Notificación de creación
        try {
          final circu = await VehiclesconService().obtenerTarjetaCirculacion(
            widget.vehicle['id'].toString(),
            widget.idMainAccount.toString(),
          );

          if (circu != null && circu.isNotEmpty && circu['id'] != null) {
            final int idcircu = circu['id'];
            const nameNotice = 'vehicle_registration_card_added';
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
                  .replaceAll('{card_number}', numTarjeta)
                  .replaceAll(
                      '{issue_date}',
                      DateFormat('dd/MM/yyyy')
                          .format(_selectedFechaExpedicion!))
                  .replaceAll(
                      '{expiry_date}',
                      DateFormat('dd/MM/yyyy')
                          .format(_selectedFechaVencimiento!));

              final title = (noticeTemplate['title']?.toString() ?? '')
                  .replaceAll('{vehicle_plate}', vehiclePlates);

              final finalMessage =
                  '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

              await NotificationService().insertNotification({
                'typeSource': widget.typeSource,
                'idOrigin': idcircu,
                'typEvent': 1,
                'date': DateTime.now().toIso8601String(),
                'message': finalMessage,
                'colNotice': 'tc_New',
                'idMainAcoount': widget.idMainAccount.toString(),
                'codUsGenerator': widget.userId.toString(),
                'idDev': widget.userId.toString(),
              });
            }
          }
        } catch (notifErr) {
          debugPrint('Error al enviar notificación de creación: $notifErr');
        }

        // Insertar control de gestión
        await VehiclesconService().insertManagementControlTJ(
          widget.idMainAccount.toString(),
          widget.vehicle['id'].toString(),
          fechaVenUTC,
        );

        if (mounted) {
          Navigator.of(context).pop();
          SnackbarTop.showSuccess(
            context,
            'Tarjeta de circulación creada exitosamente.',
          );
          widget.onSuccess();
        }
      }
    } catch (e) {
      debugPrint('Error al guardar tarjeta de circulación: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        SnackbarTop.showError(
          context,
          'Ocurrió un error al procesar la solicitud. Intenta nuevamente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Asa superior estilo Apple
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Encabezado del modal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.credit_card_rounded,
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
                              ? 'Editar Tarjeta de Circulación'
                              : 'Nueva Tarjeta de Circulación',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          widget.vehicle['placas']?.toString() ??
                              widget.vehicle['plate']?.toString() ??
                              'Vehículo',
                          style: const TextStyle(
                            fontSize: 11.5,
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

            // Formulario scrolleable
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Número / Folio de Tarjeta
                      _buildFieldLabel('Número de Tarjeta / Folio *'),
                      TextFormField(
                        controller: _numTarjetaController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 20,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: _buildInputDecoration(
                          hint: 'Ej. TC-94820194',
                          prefixIcon: Icons.badge_outlined,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa el número de tarjeta.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Fechas (Expedición y Vencimiento)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Fecha de Expedición *'),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    _selectDate(
                                      context,
                                      title: 'Fecha de Expedición',
                                      initialDate: _selectedFechaExpedicion,
                                      onDateSelected: (date) {
                                        setState(() {
                                          _selectedFechaExpedicion = date;
                                          _fecExpedicionController.text =
                                              DateFormat('dd / MM / yyyy')
                                                  .format(date);
                                        });
                                      },
                                    );
                                  },
                                  child: IgnorePointer(
                                    child: TextFormField(
                                      controller: _fecExpedicionController,
                                      readOnly: true,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: _buildInputDecoration(
                                        hint: 'dd / mm / aaaa',
                                        prefixIcon:
                                            Icons.calendar_today_rounded,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Selecciona la fecha.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Fecha de Vencimiento *'),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    _selectDate(
                                      context,
                                      title: 'Fecha de Vencimiento',
                                      initialDate: _selectedFechaVencimiento,
                                      onDateSelected: (date) {
                                        setState(() {
                                          _selectedFechaVencimiento = date;
                                          _fecVencimientoController.text =
                                              DateFormat('dd / MM / yyyy')
                                                  .format(date);
                                        });
                                      },
                                    );
                                  },
                                  child: IgnorePointer(
                                    child: TextFormField(
                                      controller: _fecVencimientoController,
                                      readOnly: true,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: _buildInputDecoration(
                                        hint: 'dd / mm / aaaa',
                                        prefixIcon:
                                            Icons.event_available_rounded,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Selecciona la fecha.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Monto / Costo
                      _buildFieldLabel('Monto Pagado / Derechos *'),
                      TextFormField(
                        controller: _montoController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: _buildInputDecoration(
                          hint: '0.00',
                          prefixIcon: Icons.attach_money_rounded,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa el monto.';
                          }
                          final parsed = double.tryParse(v);
                          if (parsed == null || parsed < 0) {
                            return 'Monto inválido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Botones de acción del BottomSheet
                      // OJO: Azul estándar (#0284C7 / #0369A1) para botones e inputs
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: LoadingActionButton(
                              text: widget.isEditing
                                  ? 'Guardar Cambios'
                                  : 'Crear Tarjeta',
                              icon: widget.isEditing
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              isLoading: _isLoading,
                              height: 48,
                              borderRadius: 14,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              onPressed: _submitForm,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 12.5,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: const Color(0xFF0284C7),
        size: 19,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      counterText: '',
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}

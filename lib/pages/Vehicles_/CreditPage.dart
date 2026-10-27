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
import 'package:mark_v3/pages/Vehicles_/PayCreditPage.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/apple_detail_row.dart';
import 'package:mark_v3/widgets/apple_empty_state.dart';
import 'package:mark_v3/widgets/apple_group_card.dart';
import 'package:mark_v3/widgets/apple_section_title.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Credit_/credit_model.dart';
import 'package:mark_v3/providers/Credit_/credit_provider.dart';
import 'package:mark_v3/services/mark_api_client.dart';

// Autor: Josue Hernandez
class Creditpage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
  final String creditPermission;
  final String idMainAccount;
  final String userId;

  const Creditpage({
    super.key,
    required this.vehicle,
    required this.creditPermission,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  ConsumerState<Creditpage> createState() => _CreditpageState();
}

// Alias para compatibilidad de nomenclatura
typedef CreditPage = Creditpage;

class _CreditpageState extends ConsumerState<Creditpage> {
  List<Map<String, dynamic>> _creditosDisponibles = [];
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
    _loadCatalogs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCreditData();
    });
  }

  void _loadCreditData() {
    ref.read(creditProvider.notifier).fetchCredits(
          widget.vehicle['id'].toString(),
          widget.idMainAccount.toString(),
        );
  }

  Future<void> _loadCatalogs() async {
    try {
      final data =
          await VehiclesconService().obtenerCreditos(widget.idMainAccount);
      if (!_isDisposed && mounted) {
        setState(() {
          _creditosDisponibles = data;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar entidades financieras: $e');
    }
  }

  Future<void> _fetchTypeSource() async {
    if (_isDisposed || !mounted) return;
    try {
      final Map<String, dynamic> data =
          await NotificationService().gettypSource('vehic_credit');
      if (!_isDisposed && mounted && data.containsKey('id')) {
        setState(() {
          _typeSource = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error al obtener typeSource de crédito: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isDisposed || !mounted) return;
    _loadCatalogs();
    _loadCreditData();
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
      debugPrint('Error al obtener el crédito: $error');
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
      MarkApiClient.instance.flota.can('credito', 'pagar') ||
      ((int.tryParse(widget.creditPermission) ?? 0) & 8 == 8);

  bool get _canDelete => false;

  bool get _canCreate =>
      MarkApiClient.instance.flota.can('credito', 'pagar') ||
      ((int.tryParse(widget.creditPermission) ?? 0) & 4 == 4);

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

    final creditState = ref.watch(creditProvider);

    if (creditState.isConnectionError) {
      return ConnectionErrorPage(onRetry: _refreshData);
    }
    if (creditState.isServerError) {
      return ServerErrorPage(onRetry: _refreshData);
    }
    if (creditState.isUnexpectedError) {
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
                  if (creditState.isLoading)
                    _buildSkeleton(isSmallScreen)
                  else if (creditState.credits.isEmpty)
                    _buildEmptyState()
                  else
                    _buildCreditDetails(
                        creditState.credits.first, creditState.payDate),
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
                'Crédito Vehicular',
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
    final hasCredit = ref.watch(creditProvider).credits.isNotEmpty;

    if (hasCredit && _canEdit) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'edit',
          title: 'Editar Crédito',
          icon: Icons.edit_rounded,
          iconColor: const Color(0xFF0284C7),
        ),
      );
    }

    if (hasCredit && _canDelete) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'delete',
          title: 'Eliminar Crédito',
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFEF4444),
          textColor: const Color(0xFFEF4444),
        ),
      );
    }

    if (!hasCredit && _canCreate) {
      menuItems.add(
        _buildPopupMenuItem(
          value: 'create',
          title: 'Registrar Crédito',
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
        tooltip: 'Opciones de crédito',
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
            final credits = ref.read(creditProvider).credits;
            if (credits.isNotEmpty) {
              _openCreditModal(
                  isEditing: true, initialData: credits.first.toMap());
            }
          } else if (action == 'delete') {
            _showDeleteConfirmationDialog();
          } else if (action == 'create') {
            _openCreditModal(isEditing: false);
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
          height: 205,
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
              'Error al cargar el crédito vehicular',
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
  // ESTADO VACÍO (SIN CRÉDITO REGISTRADO)
  // =========================================================================
  Widget _buildEmptyState() {
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'este vehículo';

    return AppleEmptyState(
      icon: Icons.account_balance_rounded,
      title: 'Sin Crédito Activo',
      description:
          'No se encontró ningún financiamiento o contrato de crédito activo para $plates.',
      action: _canCreate
          ? LoadingActionButton(
              text: 'Registrar Crédito',
              icon: Icons.add_circle_outline_rounded,
              isLoading: false,
              height: 46,
              borderRadius: 14,
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onPressed: () => _openCreditModal(isEditing: false),
            )
          : null,
    );
  }

  // =========================================================================
  // DETALLES DEL CRÉDITO (HERO WALLET CARD COLOR BRONCE / ÁMBAR / DORADO)
  // OJO: Solo la carta cambia a color bronce ámbar, todos los inputs y botones quedan azul estándar
  // =========================================================================
  Widget _buildCreditDetails(CreditModel credit, String payDate) {
    final name =
        credit.name.trim().isNotEmpty ? credit.name : 'Financiera Desconocida';
    final monto = double.tryParse(credit.monto) ?? 0.0;
    final enganche = double.tryParse(credit.enganche) ?? 0.0;
    final interes = double.tryParse(credit.interes) ?? 0.0;
    final plazo = int.tryParse(credit.plazo) ?? 0;
    final comision = double.tryParse(credit.comision) ?? 0.0;
    final comisionApertura = double.tryParse(credit.comisionApertura) ?? 0.0;

    final fechaInicioStr = _formatDisplayDate(credit.fechaInicio);
    final dateFirstPaymentStr = _formatDisplayDate(credit.dateFirstPayment);

    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'OFICIAL';

    final parsedPayDate = _parseDateSafe(payDate);

    // Evaluación del estatus de la fecha del próximo pago
    int daysRemaining = 0;
    bool isExpired = false;
    bool isToday = false;
    bool isClose = false;

    Color badgeBg;
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (parsedPayDate == null) {
      badgeBg = const Color(0xFFF59E0B).withOpacity(0.2);
      badgeColor = const Color(0xFFFDE68A);
      badgeText = 'ACTIVO';
      badgeIcon = Icons.verified_rounded;
    } else {
      daysRemaining = _calculateDaysDifference(parsedPayDate);
      if (daysRemaining < 0) {
        isExpired = true;
        badgeBg = const Color(0xFFEF4444).withOpacity(0.25);
        badgeColor = const Color(0xFFFCA5A5);
        badgeText = 'PAGO VENCIDO';
        badgeIcon = Icons.error_rounded;
      } else if (daysRemaining == 0) {
        isToday = true;
        badgeBg = const Color(0xFFEA580C).withOpacity(0.25);
        badgeColor = const Color(0xFFFDBA74);
        badgeText = 'VENCE HOY';
        badgeIcon = Icons.warning_amber_rounded;
      } else if (daysRemaining <= 15) {
        isClose = true;
        badgeBg = const Color(0xFFEA580C).withOpacity(0.25);
        badgeColor = const Color(0xFFFDBA74);
        badgeText = 'PRÓXIMO PAGO';
        badgeIcon = Icons.alarm_rounded;
      } else {
        badgeBg = const Color(0xFF10B981).withOpacity(0.25);
        badgeColor = const Color(0xFF6EE7B7);
        badgeText = 'AL DÍA';
        badgeIcon = Icons.check_circle_rounded;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. TARJETA DIGITAL APPLE WALLET HERO (COLOR BRONCE / ÁMBAR / DORADO METÁLICO)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF3B1D08), // Dark Obsidian Bronze
                Color(0xFF78350F), // Rich Warm Amber
                Color(0xFFB45309), // Radiant Gold Amber
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
                color: const Color(0xFF3B1D08).withOpacity(0.32),
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
                                    Icons.account_balance_rounded,
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
                                        'FINANCIAMIENTO AUTOMOTRIZ',
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
                                        'CRÉDITO ACTIVO · MARK FLEET',
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
                                  color: Color(0xFFFDE68A),
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

                      // Fila Central: Nombre Financiera y Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'INSTITUCIÓN FINANCIERA',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.65),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
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

                      // Fila Inferior: Monto Financiado, Plazo, Interés
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
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MONTO TOTAL',
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
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFDE047),
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
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PLAZO',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.55),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$plazo meses',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
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
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TASA',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.55),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$interes%',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
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

        // 2. SECCIÓN: ESTADO DEL PRÓXIMO PAGO
        _buildSectionTitle('PRÓXIMO VENCIMIENTO DE PAGO'),
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
                          payDate.isEmpty
                              ? 'Sin pagos pendientes registrados'
                              : (parsedPayDate == null
                                  ? 'Próximo pago: $payDate'
                                  : (isExpired
                                      ? 'Pago vencido hace ${daysRemaining.abs()} días'
                                      : (isToday
                                          ? '¡Hoy es la fecha límite de pago!'
                                          : 'Próximo pago en $daysRemaining días'))),
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
                          payDate.isEmpty
                              ? 'Consulta el historial de abonos para más detalles.'
                              : 'Fecha límite de corte: ${_formatDisplayDate(payDate)}',
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
                              ? 'ATENCIÓN: PAGO VENCIDO'
                              : (isClose || isToday
                                  ? 'RECORDATORIO DE VENCIMIENTO'
                                  : 'CRÉDITO EN CORRIENTE REGULAR'),
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
                              ? 'Realiza el abono correspondiente para evitar recargos por mora o reporte financiero.'
                              : 'Mantén los pagos al corriente para conservar el historial crediticio impecable.',
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

        // 3. BOTÓN PRINCIPAL PARA REGISTRAR PAGO (AZUL ESTÁNDAR)
        LoadingActionButton(
          text: 'Registrar Abono / Pago',
          icon: Icons.payments_rounded,
          isLoading: false,
          height: 48,
          borderRadius: 14,
          gradient: const LinearGradient(
            colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PayCreditPage(
                  creditoId: credit.id.toString(),
                  vehicle: widget.vehicle,
                  idMainAccount: widget.idMainAccount,
                  userId: widget.userId,
                ),
              ),
            ).then((_) => _refreshData());
          },
        ),
        const SizedBox(height: 18),

        // 4. SECCIÓN: DETALLES FINANCIEROS DEL CONTRATO
        _buildSectionTitle('CONDICIONES DEL CRÉDITO'),
        _buildAppleGroupContainer(
          children: [
            _buildDetailRow(
              icon: Icons.account_balance_rounded,
              label: 'Institución Financiera',
              value: name,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.monetization_on_outlined,
              label: 'Monto Financiado',
              value: _currencyFormat.format(monto),
              isHighlight: true,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.price_check_rounded,
              label: 'Enganche Inicial',
              value: _currencyFormat.format(enganche),
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.percent_rounded,
              label: 'Tasa de Interés',
              value: '$interes%',
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.timer_outlined,
              label: 'Plazo Total',
              value: '$plazo meses',
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.receipt_long_rounded,
              label: 'Comisión',
              value: _currencyFormat.format(comision),
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.folder_open_rounded,
              label: 'Comisión por Apertura',
              value: _currencyFormat.format(comisionApertura),
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.event_available_rounded,
              label: 'Fecha de Contratación',
              value: fechaInicioStr,
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Fecha del Primer Pago',
              value: dateFirstPaymentStr,
            ),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return AppleDetailRow(
      icon: icon,
      label: label,
      value: value,
      isHighlight: isHighlight,
    );
  }

  Widget _buildSectionTitle(String title) {
    return AppleSectionTitle(title);
  }

  Widget _buildAppleGroupContainer({required List<Widget> children}) {
    return AppleGroupCard(children: children);
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
                      '¿Eliminar Crédito?',
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
                      'Se borrará el crédito automotriz y el historial de abonos para las placas $plates. Esta acción no se puede deshacer.',
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
                              await _performDeleteCredit(dialogContext);
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

  Future<void> _performDeleteCredit(BuildContext dialogContext) async {
    try {
      final creditList = await VehiclesconService().getCreditos(
        widget.idMainAccount.toString(),
        widget.vehicle['id'].toString(),
      );

      if (creditList.isEmpty) {
        if (mounted) {
          Navigator.of(dialogContext).pop();
          SnackbarTop.showInfo(
            context,
            'No se encontró ningún crédito para eliminar.',
          );
        }
        return;
      }

      final int idCredit = creditList.first['id'];

      // 1. Notificación
      try {
        const nameNotice = 'vehicle_credit_deleted';
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

          final formattedMessage =
              message.replaceAll('{vehicle_plate}', vehiclePlates);
          final title = (noticeTemplate['title']?.toString() ?? '')
              .replaceAll('{vehicle_plate}', vehiclePlates);

          final finalMessage =
              '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

          await NotificationService().insertNotification({
            'typeSource': _typeSource,
            'idOrigin': idCredit,
            'typEvent': 3,
            'date': DateTime.now().toIso8601String(),
            'message': finalMessage,
            'colNotice': 'credit_Delete',
            'idMainAcoount': widget.idMainAccount.toString(),
            'codUsGenerator': widget.userId.toString(),
            'idDev': widget.userId.toString(),
          });
        }
      } catch (notifErr) {
        debugPrint('Error al enviar notificación de eliminación: $notifErr');
      }

      // 2. Eliminar crédito y pagos
      await VehiclesconService().eliminarCredito(
        widget.idMainAccount.toString(),
        widget.vehicle['id'].toString(),
      );

      await VehiclesconService().eliminarPayCredit(
        widget.idMainAccount.toString(),
        idCredit.toString(),
      );

      await VehiclesconService().deleteManagementControlCd(
        widget.idMainAccount.toString(),
        widget.vehicle['id'].toString(),
      );

      if (mounted) {
        Navigator.of(dialogContext).pop();
        SnackbarTop.showSuccess(
          context,
          'Crédito eliminado exitosamente.',
        );
        _refreshData();
      }
    } catch (e) {
      debugPrint('Error al eliminar crédito: $e');
      if (mounted) {
        Navigator.of(dialogContext).pop();
        SnackbarTop.showError(
          context,
          'Error al eliminar el crédito. Inténtalo de nuevo.',
        );
      }
    }
  }

  // =========================================================================
  // MODAL CREAR / EDITAR ESTILO APPLE (BOTTOM SHEET)
  // =========================================================================
  void _openCreditModal({
    required bool isEditing,
    Map<String, dynamic>? initialData,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CreditFormModalSheet(
          isEditing: isEditing,
          initialData: initialData,
          vehicle: widget.vehicle,
          idMainAccount: widget.idMainAccount,
          userId: widget.userId,
          typeSource: _typeSource,
          creditosDisponibles: _creditosDisponibles,
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
class _CreditFormModalSheet extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic> vehicle;
  final String idMainAccount;
  final String userId;
  final String typeSource;
  final List<Map<String, dynamic>> creditosDisponibles;
  final VoidCallback onSuccess;

  const _CreditFormModalSheet({
    required this.isEditing,
    this.initialData,
    required this.vehicle,
    required this.idMainAccount,
    required this.userId,
    required this.typeSource,
    required this.creditosDisponibles,
    required this.onSuccess,
  });

  @override
  State<_CreditFormModalSheet> createState() => _CreditFormModalSheetState();
}

class _CreditFormModalSheetState extends State<_CreditFormModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _engancheController = TextEditingController();
  final _interesController = TextEditingController();
  final _plazoController = TextEditingController();
  final _comisionController = TextEditingController();
  final _comisionAperturaController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final _dateFirstPaymentController = TextEditingController();

  List<Map<String, dynamic>> _creditosLocales = [];
  String? _selectedFinanceEntityId;
  DateTime? _selectedFechaInicio;
  DateTime? _selectedDateFirstPayment;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _creditosLocales = widget.creditosDisponibles.isNotEmpty
        ? List<Map<String, dynamic>>.from(widget.creditosDisponibles)
        : List<Map<String, dynamic>>.from(VehiclesconService.defaultFinanceEntities);

    if (widget.creditosDisponibles.isEmpty) {
      VehiclesconService().obtenerCreditos(widget.idMainAccount).then((data) {
        if (mounted && data.isNotEmpty) {
          setState(() {
            _creditosLocales = data;
          });
        }
      });
    }

    if (widget.isEditing && widget.initialData != null) {
      final d = widget.initialData!;
      _montoController.text = d['monto']?.toString() ?? '0';
      _engancheController.text = d['enganche']?.toString() ?? '0';
      _interesController.text = d['interes']?.toString() ?? '0';
      _plazoController.text = d['plazo']?.toString() ?? '12';
      _comisionController.text = d['comision']?.toString() ?? '0';
      _comisionAperturaController.text =
          d['comisionApertura']?.toString() ?? '0';

      _selectedFechaInicio = _parseDate(d['fechaInicio']);
      if (_selectedFechaInicio != null) {
        _fechaInicioController.text =
            DateFormat('dd / MM / yyyy').format(_selectedFechaInicio!);
      }

      _selectedDateFirstPayment = _parseDate(d['dateFirstPayment']);
      if (_selectedDateFirstPayment != null) {
        _dateFirstPaymentController.text =
            DateFormat('dd / MM / yyyy').format(_selectedDateFirstPayment!);
      }

      // Resolver ID de la entidad financiera
      final name = d['name']?.toString().trim().toLowerCase();
      final idComp = d['idCompania']?.toString();
      if (_creditosLocales.isNotEmpty) {
        final match = _creditosLocales.firstWhere(
          (c) =>
              c['id']?.toString() == idComp ||
              c['name']?.toString().trim().toLowerCase() == name,
          orElse: () => _creditosLocales.first,
        );
        _selectedFinanceEntityId = match['id']?.toString();
      }
    } else {
      _selectedFinanceEntityId = null;
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
    _montoController.dispose();
    _engancheController.dispose();
    _interesController.dispose();
    _plazoController.dispose();
    _comisionController.dispose();
    _comisionAperturaController.dispose();
    _fechaInicioController.dispose();
    _dateFirstPaymentController.dispose();
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

    if (_selectedFinanceEntityId == null || _selectedFinanceEntityId!.isEmpty) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona una institución financiera.',
      );
      return;
    }

    if (_selectedFechaInicio == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de inicio del crédito.',
      );
      return;
    }

    if (_selectedDateFirstPayment == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha del primer pago.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String monto = _montoController.text.trim();
    final String enganche = _engancheController.text.trim();
    final String interes = _interesController.text.trim();
    final String plazo = _plazoController.text.trim();
    final String comision = _comisionController.text.trim();
    final String comisionApertura = _comisionAperturaController.text.trim();

    try {
      if (widget.isEditing) {
        // --- ACTUALIZACIÓN DE CRÉDITO ---
        final String fechaInicioFormateada =
            DateFormat('yyyy-MM-dd').format(_selectedFechaInicio!);
        final String dateFirstPaymentFormateada =
            DateFormat('yyyy-MM-dd').format(_selectedDateFirstPayment!);

        await VehiclesconService().actualizarCredito(
          widget.idMainAccount.toString(),
          widget.vehicle['id'].toString(),
          _selectedFinanceEntityId!,
          fechaInicioFormateada,
          monto,
          enganche,
          interes,
          plazo,
          comision,
          comisionApertura,
          dateFirstPaymentFormateada,
        );

        final creditList = await VehiclesconService().getCreditos(
          widget.idMainAccount.toString(),
          widget.vehicle['id'].toString(),
        );

        if (creditList.isNotEmpty && creditList.first['id'] != null) {
          final int idcredito = creditList.first['id'];

          // Actualizar calendario de pagos si el plazo o fecha cambiaron
          final int nPayments = int.tryParse(plazo) ?? 0;
          if (nPayments > 0) {
            try {
              await VehiclesconService().UpdatePagosCredito(
                widget.idMainAccount.toString(),
                idcredito.toString(),
                nPayments,
                _selectedDateFirstPayment!,
              );
            } catch (errPagos) {
              debugPrint('Error al actualizar calendario de pagos: $errPagos');
            }
          }

          // Notificación
          try {
            const nameNotice = 'vehicle_credit_updated';
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

              final formattedMessage =
                  message.replaceAll('{vehicle_plate}', vehiclePlates);
              final title = (noticeTemplate['title']?.toString() ?? '')
                  .replaceAll('{vehicle_plate}', vehiclePlates);

              final finalMessage =
                  '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

              await NotificationService().insertNotification({
                'typeSource': widget.typeSource,
                'idOrigin': idcredito,
                'typEvent': 2,
                'date': DateTime.now().toIso8601String(),
                'message': finalMessage,
                'colNotice': 'credit_Edit',
                'idMainAcoount': widget.idMainAccount.toString(),
                'codUsGenerator': widget.userId.toString(),
                'idDev': widget.userId.toString(),
              });
            }
          } catch (notifErr) {
            debugPrint('Error al enviar notificación: $notifErr');
          }

          // Control de gestión
          try {
            final nextPaymentData = await VehiclesconService()
                .getNextPaymentDate(idcredito.toString());
            final DateTime? firstPaymentDate =
                _parseDate(nextPaymentData['fecExpi']);
            if (firstPaymentDate != null) {
              await VehiclesconService().updateManagementControlCd(
                widget.idMainAccount.toString(),
                widget.vehicle['id'].toString(),
                firstPaymentDate,
              );
            }
          } catch (mErr) {
            debugPrint('Error al actualizar management control cd: $mErr');
          }
        }

        if (mounted) {
          Navigator.of(context).pop();
          SnackbarTop.showSuccess(
            context,
            'Crédito automotriz actualizado exitosamente.',
          );
          widget.onSuccess();
        }
      } else {
        // --- CREACIÓN DE CRÉDITO ---
        final DateTime fechaInicioUTC = _selectedFechaInicio!.toUtc();
        final DateTime dateFirstPaymentUTC = _selectedDateFirstPayment!.toUtc();

        await VehiclesconService().crearCredito(
          widget.idMainAccount.toString(),
          widget.vehicle['id'].toString(),
          _selectedFinanceEntityId!,
          fechaInicioUTC,
          monto,
          enganche,
          interes,
          plazo,
          comision,
          comisionApertura,
          dateFirstPaymentUTC,
        );

        final creditList = await VehiclesconService().getCreditos(
          widget.idMainAccount.toString(),
          widget.vehicle['id'].toString(),
        );

        if (creditList.isNotEmpty && creditList.first['id'] != null) {
          final int idcredito = creditList.first['id'];

          // Insertar calendario de pagos
          final int nPayments = int.tryParse(plazo) ?? 0;
          if (nPayments > 0) {
            try {
              await VehiclesconService().insertarPagosCredito(
                widget.idMainAccount.toString(),
                idcredito,
                nPayments,
                dateFirstPaymentUTC,
              );
            } catch (errPagos) {
              debugPrint('Error al insertar pagos: $errPagos');
            }
          }

          // Notificación de creación
          try {
            const nameNotice = 'vehicle_credit_added';
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

              final formattedMessage =
                  message.replaceAll('{vehicle_plate}', vehiclePlates);
              final title = (noticeTemplate['title']?.toString() ?? '')
                  .replaceAll('{vehicle_plate}', vehiclePlates);

              final finalMessage =
                  '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

              await NotificationService().insertNotification({
                'typeSource': widget.typeSource,
                'idOrigin': idcredito,
                'typEvent': 1,
                'date': DateTime.now().toIso8601String(),
                'message': finalMessage,
                'colNotice': 'credit_New',
                'idMainAcoount': widget.idMainAccount.toString(),
                'codUsGenerator': widget.userId.toString(),
                'idDev': widget.userId.toString(),
              });
            }
          } catch (notifErr) {
            debugPrint('Error al enviar notificación de creación: $notifErr');
          }

          // Control de gestión
          try {
            final nextPaymentData = await VehiclesconService()
                .getNextPaymentDate(idcredito.toString());
            final DateTime? firstPaymentDate =
                _parseDate(nextPaymentData['fecExpi']);
            if (firstPaymentDate != null) {
              await VehiclesconService().insertManagementControlCd(
                widget.idMainAccount.toString(),
                widget.vehicle['id'].toString(),
                firstPaymentDate,
              );
            }
          } catch (mErr) {
            debugPrint('Error al insertar management control cd: $mErr');
          }
        }

        if (mounted) {
          Navigator.of(context).pop();
          SnackbarTop.showSuccess(
            context,
            'Crédito automotriz registrado exitosamente.',
          );
          widget.onSuccess();
        }
      }
    } catch (e) {
      debugPrint('Error al guardar crédito: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        SnackbarTop.showError(
          context,
          'Ocurrió un error al procesar el crédito. Intenta de nuevo.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
            // Asa superior
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
                      Icons.account_balance_rounded,
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
                              ? 'Editar Crédito Automotriz'
                              : 'Nuevo Crédito Automotriz',
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
                      // Institución Financiera (Dropdown)
                      _buildFieldLabel('Institución / Financiera *'),
                      Builder(
                        builder: (context) {
                          final seen = <String>{};
                          final dropdownItems = <DropdownMenuItem<String>>[];
                          for (final entidad in _creditosLocales) {
                            final id = entidad['id']?.toString() ?? '';
                            final name = (entidad['name'] ??
                                    entidad['nombre'] ??
                                    '')
                                .toString();
                            if (id.isNotEmpty && !seen.contains(id)) {
                              seen.add(id);
                              dropdownItems.add(
                                DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              );
                            }
                          }

                          final validValue =
                              seen.contains(_selectedFinanceEntityId)
                                  ? _selectedFinanceEntityId
                                  : null;

                          return DropdownButtonFormField2<String>(
                            value: validValue,
                            isExpanded: true,
                            decoration: _buildInputDecoration(
                              hint: 'Selecciona la financiera',
                              prefixIcon: Icons.business_rounded,
                            ),
                            items: dropdownItems,
                            onChanged: (value) {
                              setState(() {
                                _selectedFinanceEntityId = value;
                              });
                            },
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 280,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A)
                                        .withOpacity(0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Monto Financiado y Enganche
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Monto Financiado *'),
                                TextFormField(
                                  controller: _montoController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: '0.00',
                                    prefixIcon: Icons.attach_money_rounded,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Requerido';
                                    }
                                    final val = double.tryParse(v);
                                    if (val == null || val <= 0) {
                                      return 'Monto mayor a 0';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Enganche Inicial *'),
                                TextFormField(
                                  controller: _engancheController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: '0.00',
                                    prefixIcon: Icons.price_check_rounded,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Requerido';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Tasa de Interés y Plazo en Meses
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Tasa de Interés (%) *'),
                                TextFormField(
                                  controller: _interesController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: 'Ej. 12.5',
                                    prefixIcon: Icons.percent_rounded,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Requerido';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Plazo (Meses) *'),
                                TextFormField(
                                  controller: _plazoController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: 'Ej. 24, 36, 48',
                                    prefixIcon: Icons.timer_outlined,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Requerido';
                                    }
                                    final p = int.tryParse(v);
                                    if (p == null || p <= 0) {
                                      return 'Plazo inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Comisión y Comisión por Apertura
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Comisión *'),
                                TextFormField(
                                  controller: _comisionController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: '0.00',
                                    prefixIcon: Icons.receipt_long_rounded,
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
                                _buildFieldLabel('Comisión Apertura *'),
                                TextFormField(
                                  controller: _comisionAperturaController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: '0.00',
                                    prefixIcon: Icons.folder_open_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Fechas (Inicio y Primer Pago)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Fecha de Inicio *'),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    _selectDate(
                                      context,
                                      title: 'Fecha de Contratación',
                                      initialDate: _selectedFechaInicio,
                                      onDateSelected: (date) {
                                        setState(() {
                                          _selectedFechaInicio = date;
                                          _fechaInicioController.text =
                                              DateFormat('dd / MM / yyyy')
                                                  .format(date);
                                        });
                                      },
                                    );
                                  },
                                  child: IgnorePointer(
                                    child: TextFormField(
                                      controller: _fechaInicioController,
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Fecha Primer Pago *'),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    _selectDate(
                                      context,
                                      title: 'Fecha del Primer Pago',
                                      initialDate: _selectedDateFirstPayment,
                                      onDateSelected: (date) {
                                        setState(() {
                                          _selectedDateFirstPayment = date;
                                          _dateFirstPaymentController.text =
                                              DateFormat('dd / MM / yyyy')
                                                  .format(date);
                                        });
                                      },
                                    );
                                  },
                                  child: IgnorePointer(
                                    child: TextFormField(
                                      controller: _dateFirstPaymentController,
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
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Botones de acción del BottomSheet (AZUL ESTÁNDAR)
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
                                  : 'Crear Crédito',
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

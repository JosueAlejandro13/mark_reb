import 'dart:async';
import 'dart:convert';

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
import 'package:mark_v3/models/Credit_/credit_payment_model.dart';
import 'package:mark_v3/providers/Credit_/pay_credit_provider.dart';

// Autor: Josue Hernandez
class PayCreditPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
  final String? creditoId;
  final String idMainAccount;
  final String userId;

  const PayCreditPage({
    super.key,
    required this.vehicle,
    required this.creditoId,
    required this.idMainAccount,
    required this.userId,
  });

  @override
  ConsumerState<PayCreditPage> createState() => _PayCreditPageState();
}

class _PayCreditPageState extends ConsumerState<PayCreditPage> {
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _typeSource = '';
  bool _isSubmitting = false;
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
      _getPaymentHistory();
    });
  }

  Future<void> _fetchTypeSource() async {
    if (_isDisposed || !mounted) return;
    try {
      final Map<String, dynamic> data =
          await NotificationService().gettypSource('vehic_creditBreakdown');
      if (!_isDisposed && mounted && data.containsKey('id')) {
        setState(() {
          _typeSource = data['id'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error al obtener typeSource: $e');
    }
  }

  Future<void> _refreshData() async {
    if (_isDisposed || !mounted) return;
    _getPaymentHistory();
  }

  void _getPaymentHistory() {
    if (widget.creditoId == null) return;
    ref.read(payCreditProvider.notifier).fetchPaymentHistory(widget.creditoId!);
  }

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
              'Error al cargar el historial',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _registrarPago() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.creditoId == null) {
      SnackbarTop.showError(
        context,
        'No se encontró el ID del crédito para registrar el abono.',
      );
      return;
    }

    final montoStr = _amountController.text.trim();
    final monto = double.tryParse(montoStr) ?? 0.0;
    if (monto <= 0) {
      SnackbarTop.showInfo(
        context,
        'Por favor ingresa un monto válido mayor a 0.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final service = VehiclesconService();
      final double montoDouble = double.tryParse(montoStr) ?? 0.0;
      final fechaHoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final int creditIdInt = int.tryParse(widget.creditoId ?? '0') ?? 0;
      await service.pagarCuotaCredito(
        idPago: creditIdInt,
        monto: montoDouble,
        fecha: fechaHoy,
      );
      final int insertedPaymentId = creditIdInt;

      // Siguiente fecha de corte
      DateTime? nextDate;
      try {
        final nextPaymentDataMang =
            await service.getNextPaymentDate(widget.creditoId!);
        if (nextPaymentDataMang.containsKey('fecExpi') &&
            nextPaymentDataMang['fecExpi'] != null) {
          nextDate =
              DateTime.tryParse(nextPaymentDataMang['fecExpi'].toString());
        }
      } catch (errDate) {
        debugPrint('Error al calcular siguiente fecha de corte: $errDate');
      }

      // Notificación
      try {
        const nameNotice = 'vehicle_credit_payment_made';
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
              .replaceAll('{payment_date}', _formatDisplayDate(DateTime.now()));

          final title = (noticeTemplate['title']?.toString() ?? '')
              .replaceAll('{vehicle_plate}', vehiclePlates);

          final finalMessage =
              '$title|$formattedMessage|${noticeTemplate['icon'] ?? ''}';

          await NotificationService().insertNotification({
            'typeSource': _typeSource,
            'idOrigin': insertedPaymentId,
            'typEvent': 1,
            'date': DateTime.now().toIso8601String(),
            'message': finalMessage,
            'colNotice': 'credit_Payment',
            'idMainAcoount': widget.idMainAccount.toString(),
            'codUsGenerator': widget.userId.toString(),
            'idDev': widget.userId.toString(),
          });
        }
      } catch (notifErr) {
        debugPrint('Error al enviar notificación de abono: $notifErr');
      }

      // Control de gestión
      if (nextDate != null) {
        try {
          await service.insertManagementControlCd(
            widget.idMainAccount.toString(),
            widget.vehicle['id'].toString(),
            nextDate,
          );
        } catch (mcErr) {
          debugPrint('Error al registrar control de gestión: $mcErr');
        }
      }

      if (mounted) {
        _amountController.clear();
        SnackbarTop.showSuccess(
          context,
          'Abono registrado correctamente: ${_currencyFormat.format(monto)}',
        );
        _getPaymentHistory();
      }
    } catch (e) {
      debugPrint('Error al registrar pago: $e');
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '').trim();
        SnackbarTop.showError(
          context,
          errorMsg.isNotEmpty ? errorMsg : 'Error al registrar el pago. Intenta de nuevo más tarde.',
        );
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _amountController.dispose();
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

    final payCreditState = ref.watch(payCreditProvider);

    if (payCreditState.isConnectionError) {
      return ConnectionErrorPage(onRetry: _refreshData);
    }
    if (payCreditState.isServerError) {
      return ServerErrorPage(onRetry: _refreshData);
    }
    if (payCreditState.isUnexpectedError) {
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
                  if (payCreditState.isLoading)
                    _buildSkeleton()
                  else ...[
                    _buildSummaryCard(payCreditState.totalPagado,
                        payCreditState.payments.length),
                    const SizedBox(height: 18),
                    _buildPaymentFormSection(),
                    const SizedBox(height: 20),
                    _buildPaymentHistorySection(payCreditState.payments),
                    const SizedBox(height: 32),
                  ],
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
                'Abono a Crédito',
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
        IconButton(
          tooltip: 'Actualizar',
          icon: const Icon(
            Icons.refresh_rounded,
            color: Color(0xFF0F172A),
            size: 22,
          ),
          onPressed: _refreshData,
        ),
      ],
    );
  }

  // =========================================================================
  // SKELETON
  // =========================================================================
  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppShimmerBox.card(height: 180, borderRadius: 20),
        const SizedBox(height: 18),
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
            children: const [
              AppShimmerBox.text(width: 150, height: 14),
              SizedBox(height: 12),
              AppShimmerBox(
                  width: double.infinity, height: 48, borderRadius: 12),
              SizedBox(height: 14),
              AppShimmerBox(
                  width: double.infinity, height: 46, borderRadius: 14),
            ],
          ),
        ),
        const SizedBox(height: 20),
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
              AppShimmerBox.text(width: double.infinity, height: 16),
              SizedBox(height: 14),
              AppShimmerBox.text(width: double.infinity, height: 16),
              SizedBox(height: 14),
              AppShimmerBox.text(width: double.infinity, height: 16),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // HERO WALLET CARD (COLOR BRONCE / ÁMBAR / DORADO METÁLICO)
  // OJO: Solo la carta cambia a color bronce ámbar, todos los inputs y botones quedan azul estándar
  // =========================================================================
  Widget _buildSummaryCard(double totalPagado, int paymentCount) {
    final plates = widget.vehicle['placas']?.toString() ??
        widget.vehicle['plate']?.toString() ??
        'OFICIAL';

    return Container(
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
                  // Fila Superior: Título y Placas
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
                                Icons.payments_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ABONOS DE FINANCIAMIENTO',
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
                                    'CONTROL DE AMORTIZACIÓN · MARK FLEET',
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

                  // Fila Central: Total amortizado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL AMORTIZADO REGISTRADO',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.65),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currencyFormat.format(totalPagado),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFDE047),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          '$paymentCount PAGOS',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
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
    );
  }

  // =========================================================================
  // FORMULARIO PARA REGISTRAR PAGO (AZUL ESTÁNDAR)
  // =========================================================================
  Widget _buildPaymentFormSection() {
    return _buildAppleGroupContainer(
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.add_card_rounded,
                color: Color(0xFF0284C7),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Registrar Nuevo Abono',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('Monto a Pagar *'),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.attach_money_rounded,
                    color: Color(0xFF0284C7),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  counterText: '',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    borderSide:
                        const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa un monto.';
                  }
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) {
                    return 'El monto debe ser mayor a 0.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              LoadingActionButton(
                text: 'Registrar Abono',
                icon: Icons.check_circle_outline_rounded,
                isLoading: _isSubmitting,
                height: 48,
                borderRadius: 14,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onPressed: _registrarPago,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // HISTORIAL DE ABONOS (APPLE TIMELINE)
  // =========================================================================
  Widget _buildPaymentHistorySection(List<CreditPaymentModel> payments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('HISTORIAL DE ABONOS REALIZADOS'),
        _buildAppleGroupContainer(
          children: [
            if (payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(
                        Icons.receipt_long_outlined,
                        color: Color(0xFF94A3B8),
                        size: 38,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Sin abonos registrados',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Los pagos que registres aparecerán en este historial.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final pago = payments[index];
                  final nPayment =
                      pago.nPayment.isNotEmpty ? pago.nPayment : '${index + 1}';
                  final monto = double.tryParse(pago.monto) ?? 0.0;
                  final fecPaymentStr = _formatDisplayDate(pago.fecPayment);
                  final fecExpiStr = _formatDisplayDate(pago.fecExpi);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '#$nPayment',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Abono #$nPayment',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  _currencyFormat.format(monto),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fecha de pago: $fecPaymentStr',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            if (fecExpiStr != 'N/A') ...[
                              const SizedBox(height: 2),
                              Text(
                                'Fecha de corte: $fecExpiStr',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ],
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
}

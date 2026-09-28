import 'dart:async';
import 'dart:io';
import 'package:bottom_picker/bottom_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

// Autor: Josue Hernandez
class LicenseDetailsPage extends StatefulWidget {
  final String idCollaborator;

  const LicenseDetailsPage({super.key, required this.idCollaborator});

  @override
  State<LicenseDetailsPage> createState() => _LicenseDetailsPageState();
}

class _LicenseDetailsPageState extends State<LicenseDetailsPage> {
  late Future<Map<String, dynamic>?> licenseDataFuture;
  final _formKey = GlobalKey<FormState>();
  final _licNumController = TextEditingController();
  final _licClassController = TextEditingController();

  DateTime? dueDate;
  bool isPermanent = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    licenseDataFuture = fetchLicenseDataById(widget.idCollaborator);
  }

  @override
  void dispose() {
    _licNumController.dispose();
    _licClassController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        licenseDataFuture = ProfileconService()
            .obtenerLicenciaPorColaborador(widget.idCollaborator);
      });
    }
  }

  Future<Map<String, dynamic>?> fetchLicenseDataById(
      String idCollaborator) async {
    try {
      final licenseData = await ProfileconService()
          .obtenerLicenciaPorColaborador(idCollaborator);

      if (licenseData == null || licenseData.isEmpty) {
        return null;
      } else {
        return licenseData;
      }
    } on SocketException catch (_) {
      if (mounted) {
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
      }
    } on TimeoutException catch (_) {
      if (mounted) {
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
      }
    } catch (e) {
      debugPrint('Error fetching license: $e');
    }
    return null;
  }

  Future<void> _saveLicense({
    required String num,
    required String category,
    required DateTime? date,
    required bool permanent,
  }) async {
    if (!permanent && date == null) {
      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Por favor selecciona la fecha de vencimiento.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      await ProfileconService().agregarNuevaLicencia({
        'idCollaborator': widget.idCollaborator,
        'licNum': num.trim(),
        'licClass': category.trim().toUpperCase(),
        'dueDate': permanent
            ? DateTime(1000, 1, 1).toIso8601String()
            : date!.toIso8601String(),
      });

      if (mounted) {
        setState(() {
          licenseDataFuture = fetchLicenseDataById(widget.idCollaborator);
          _licNumController.clear();
          _licClassController.clear();
          dueDate = null;
          isPermanent = false;
          isLoading = false;
        });

        showTopSnackBar(
          Overlay.of(context),
          Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Licencia registrada exitosamente.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        showTopSnackBar(
          Overlay.of(context),
          Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Error al procesar la licencia. Intente nuevamente más tarde.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  }

  void _selectDate(
    BuildContext context, {
    DateTime? initial,
    required ValueChanged<DateTime> onDateSelected,
  }) {
    BottomPicker.date(
      pickerTitle: const Text(
        "Fecha de Vencimiento",
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      dismissable: true,
      initialDateTime: initial ?? DateTime.now().add(const Duration(days: 365)),
      minDateTime: DateTime(1990),
      maxDateTime: DateTime(2100),
      pickerTextStyle: const TextStyle(
        fontSize: 16,
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w600,
      ),
      onSubmit: (selectedDate) {
        onDateSelected(selectedDate as DateTime);
      },
      displayCloseIcon: true,
      buttonContent:
          const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      buttonStyle: BoxDecoration(
        color: const Color(0xFF0886B5),
        borderRadius: BorderRadius.circular(12),
      ),
      buttonWidth: 50,
      buttonPadding: 8,
    ).show(context);
  }

  int _calculateDaysRemaining(DateTime targetDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return due.difference(today).inDays;
  }

  String _formatDueDate(dynamic dateVal) {
    if (dateVal == null) return 'N/A';
    if (dateVal is String) {
      try {
        final parsed = DateTime.parse(dateVal);
        return DateFormat('dd / MM / yyyy').format(parsed);
      } catch (_) {
        return 'N/A';
      }
    } else if (dateVal is DateTime) {
      return DateFormat('dd / MM / yyyy').format(dateVal);
    }
    return 'N/A';
  }

  String _getCategoryDescription(String? cat) {
    if (cat == null || cat.isEmpty) return 'Licencia de Conducir';
    switch (cat.trim().toUpperCase()) {
      case 'A':
        return 'Automovilista Particular';
      case 'B':
        return 'Servicio Público y Mercantil';
      case 'C':
        return 'Transporte de Carga';
      case 'D':
        return 'Transporte de Emergencia';
      case 'E':
        return 'Transporte Especializado';
      default:
        return 'Categoría $cat';
    }
  }

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
          child: RefreshIndicator(
            color: const Color(0xFF0886B5),
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header superior
                  _buildHeader(context),
                  const SizedBox(height: 12),

                  // Contenido dinámico
                  FutureBuilder<Map<String, dynamic>?>(
                    future: licenseDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 80),
                          child: Center(
                            child: Lottie.asset(
                              'assets/loading.json',
                              width: 70,
                              height: 70,
                              repeat: true,
                            ),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Colors.red, size: 36),
                                const SizedBox(height: 8),
                                const Text(
                                  'Error al cargar información de licencia',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0886B5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _refreshData,
                                  child: const Text('Reintentar',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else if (snapshot.hasData && snapshot.data != null) {
                        return _buildLicenseDetailsContent(snapshot.data!);
                      } else {
                        return _buildAddLicenseSection();
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

  // --- HEADER SUPERIOR ---
  Widget _buildHeader(BuildContext context) {
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
                border: Border.all(color: Colors.black.withOpacity(0.04)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Licencia de Conducir',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Consulta el estatus, vigencia y tipo de licencia',
                style: TextStyle(
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

  // --- CONTENIDO CUANDO EXISTE LICENCIA REGISTRADA ---
  Widget _buildLicenseDetailsContent(Map<String, dynamic> licenseData) {
    dynamic dueRaw = licenseData['dueDate'];
    DateTime? parsedDue;
    bool isPerm = false;

    if (dueRaw is String) {
      try {
        parsedDue = DateTime.parse(dueRaw);
      } catch (_) {
        isPerm = true;
      }
    } else if (dueRaw is DateTime) {
      parsedDue = dueRaw;
    }

    if (parsedDue == null ||
        parsedDue.year <= 1900 ||
        parsedDue.year <= 0) {
      isPerm = true;
    }

    final category =
        licenseData['licClass']?.toString().toUpperCase() ?? 'A';
    final licNumStr = licenseData['licNum']?.toString() ?? '----';

    // Determinar estado de vigencia
    int daysRemaining = 999;
    bool isExpired = false;
    bool isClose = false;
    bool isToday = false;

    Color badgeBg;
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (isPerm || parsedDue == null) {
      badgeBg = const Color(0xFF0284C7).withOpacity(0.2);
      badgeColor = const Color(0xFF38BDF8);
      badgeText = 'PERMANENTE';
      badgeIcon = Icons.all_inclusive_rounded;
    } else {
      daysRemaining = _calculateDaysRemaining(parsedDue);
      if (daysRemaining < 0) {
        isExpired = true;
        badgeBg = const Color(0xFFEF4444).withOpacity(0.25);
        badgeColor = const Color(0xFFFCA5A5);
        badgeText = 'EXPIRADA';
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
        // ==========================================
        // 1. HERO DIGITAL DRIVER'S LICENSE CARD
        // ==========================================
        Container(
          width: double.infinity,
          height: 195,
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
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0886B5).withOpacity(0.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Círculo decorativo superior derecho
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
                // Círculo decorativo inferior izquierdo
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

                // Contenido de la Tarjeta
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Fila Superior: Título Oficial + Escudo / Sello Oficial
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.directions_car_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LICENCIA DE CONDUCIR',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withOpacity(0.95),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    'CREDENCIAL DIGITAL OFICIAL',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.65),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Sello de seguridad
                          Container(
                            padding: const EdgeInsets.all(4.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      // Sección Central: Tipo / Categoría + Número Grande
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Badge elegante del TIPO de licencia
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
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
                                      Icons.badge_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'TIPO $category',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _getCategoryDescription(category),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.75),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),

                          // Número de licencia grande a la derecha
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'NÚMERO DE LICENCIA',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.65),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                licNumStr,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Fila Inferior: Vigencia + Badge de Estatus Integrado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VIGENCIA',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.65),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isPerm ? 'PERMANENTE' : _formatDueDate(dueRaw),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),

                          // Estatus Badge en la tarjeta
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
        const SizedBox(height: 14),

        // ==========================================
        // 2. CARD DE ESTATUS Y CONDICIÓN DE VIGENCIA
        // ==========================================
        _buildSectionCard(
          icon: isExpired
              ? Icons.error_outline_rounded
              : (isClose || isToday
                  ? Icons.warning_amber_rounded
                  : (isPerm
                      ? Icons.all_inclusive_rounded
                      : Icons.verified_rounded)),
          iconColor: isExpired
              ? const Color(0xFFEF4444)
              : (isClose || isToday
                  ? const Color(0xFFEA580C)
                  : (isPerm
                      ? const Color(0xFF0886B5)
                      : const Color(0xFF10B981))),
          iconBg: isExpired
              ? const Color(0xFFFEE2E2)
              : (isClose || isToday
                  ? const Color(0xFFFFF7ED)
                  : (isPerm
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFDCFCE7))),
          title: isPerm
              ? 'Licencia Permanente'
              : (isExpired
                  ? 'Licencia Expirada'
                  : (isToday
                      ? 'Vence el Día de Hoy'
                      : (isClose
                          ? 'Próxima a Vencer'
                          : 'Licencia Vigente'))),
          subtitle: isPerm
              ? 'No requiere renovación periódica de vigencia'
              : (isExpired
                  ? 'Venció hace ${-daysRemaining} días. Se recomienda renovar.'
                  : (isToday
                      ? 'Su validez expira hoy a las 23:59 hrs.'
                      : 'Quedan $daysRemaining días de validez legal')),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPerm
                              ? 'ESTATUS: VIGENCIA INDEFINIDA'
                              : (isExpired
                                  ? 'DOCUMENTO FUERA DE VIGENCIA'
                                  : 'CONDICIÓN: EN REGLA Y ACTIVA'),
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
                          isPerm
                              ? 'Tu documento no cuenta con fecha límite de caducidad.'
                              : (isExpired
                                  ? 'Renueva tu licencia ante la autoridad correspondiente.'
                                  : 'Documento apto para circulación y operaciones de campo.'),
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
        const SizedBox(height: 24),
      ],
    );
  }

  // --- SECCIÓN PARA AGREGAR NUEVA LICENCIA (CUANDO NO EXISTE) ---
  Widget _buildAddLicenseSection() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de ausencia de licencia
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.badge_outlined,
                      color: Color(0xFF0886B5),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sin Licencia Registrada',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Registra los datos de tu credencial para operar vehículos.',
                        style: TextStyle(
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
          const SizedBox(height: 12),

          // Tarjeta de Formulario de Registro
          _buildSectionCard(
            icon: Icons.add_card_rounded,
            iconColor: const Color(0xFF0886B5),
            iconBg: const Color(0xFFE0F2FE),
            title: 'Registrar Licencia',
            subtitle: 'Ingresa los datos para registrar el documento',
            children: [
              // Campo Número de Licencia
              _buildFormField(
                controller: _licNumController,
                label: 'Número de Licencia',
                icon: Icons.credit_card_rounded,
                maxLength: 12,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingresa el número de licencia'
                    : null,
              ),
              const SizedBox(height: 10),

              // Campo Tipo / Categoría
              _buildFormField(
                controller: _licClassController,
                label: 'Tipo / Categoría (ej. A, B, C)',
                icon: Icons.category_outlined,
                maxLength: 2,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingresa la categoría'
                    : null,
              ),
              const SizedBox(height: 10),

              // Opción de Licencia Permanente
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.all_inclusive_rounded,
                        size: 18, color: Color(0xFF0886B5)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Licencia Permanente',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Activar si no tiene fecha de vencimiento',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: isPermanent,
                      activeColor: const Color(0xFF0886B5),
                      onChanged: (val) {
                        setState(() {
                          isPermanent = val;
                          if (isPermanent) {
                            dueDate = DateTime(1000, 1, 1);
                          } else {
                            dueDate = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Fecha de Vencimiento (si no es permanente)
              if (!isPermanent) ...[
                const SizedBox(height: 10),
                TextFormField(
                  readOnly: true,
                  onTap: () => _selectDate(
                    context,
                    initial: dueDate,
                    onDateSelected: (selected) {
                      setState(() {
                        dueDate = selected;
                      });
                    },
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Fecha de Vencimiento',
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(
                      Icons.calendar_month_rounded,
                      size: 17,
                      color: Color(0xFF7C3AED),
                    ),
                    suffixIcon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.black54,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.black.withOpacity(0.05)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.black.withOpacity(0.05)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF7C3AED), width: 1.5),
                    ),
                  ),
                  controller: TextEditingController(
                    text: dueDate != null
                        ? DateFormat('dd/MM/yyyy').format(dueDate!)
                        : '',
                  ),
                  validator: (val) {
                    if (!isPermanent && dueDate == null) {
                      return 'Por favor selecciona la fecha de vencimiento';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          // Botón Guardar Licencia
          Container(
            width: double.infinity,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0886B5),
                  Color(0xFF0284C7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0886B5).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: isLoading
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          _saveLicense(
                            num: _licNumController.text,
                            category: _licClassController.text,
                            date: dueDate,
                            permanent: isPermanent,
                          );
                        }
                      },
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Guardar Licencia',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- CAMPO DE FORMULARIO ESTILIZADO ---
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      validator: validator,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        labelStyle: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          size: 17,
          color: const Color(0xFF0886B5),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0886B5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }

  // --- CONTENEDOR DE SECCIÓN (CARD) ---
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 17),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      subtitle,
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
          ...children,
        ],
      ),
    );
  }
}

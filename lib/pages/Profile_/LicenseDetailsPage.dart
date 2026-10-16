import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

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
        licenseDataFuture = fetchLicenseDataById(widget.idCollaborator);
      });
    }
  }

  Future<Map<String, dynamic>?> fetchLicenseDataById(
      String idCollaborator) async {
    try {
      final licenseData = await ProfileconService()
          .obtenerLicenciaPorColaborador(idCollaborator);

      if (licenseData.isEmpty) {
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
      throw Exception('Error de conexión');
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
      throw Exception('Error de servidor (Timeout)');    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('no encontrada') || errStr.contains('not found')) {
        // No es error del servidor: el usuario simplemente no tiene licencia registrada
        return null;
      }
      debugPrint('Error fetching license: $e');
      throw Exception('Error del servidor: $e');
    }
  }

  Future<void> _saveLicense({
    required String num,
    required String category,
    required DateTime? date,
    required bool permanent,
  }) async {
    if (!permanent && date == null) {
      SnackbarTop.showInfo(
        context,
        'Por favor selecciona la fecha de vencimiento de tu licencia.',
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
        'licNum': num.trim().toUpperCase(),
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

        SnackbarTop.showSuccess(
          context,
          'Licencia guardada exitosamente.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        SnackbarTop.showError(
          context,
          'Error al procesar la licencia. Intente nuevamente más tarde.',
        );
      }
    }
  }

  Future<void> _selectDate(
    BuildContext context, {
    DateTime? initial,
    required ValueChanged<DateTime> onDateSelected,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
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
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

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
                  // Header superior estilo Apple
                  _buildHeader(context),
                  const SizedBox(height: 12),

                  // Contenido dinámico (Skeleton, Error, Vista Activa o Formulario)
                  FutureBuilder<Map<String, dynamic>?>(
                    future: licenseDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return _buildSkeleton(isSmallScreen);
                      } else if (snapshot.hasError) {
                        return _buildErrorState();
                      } else if (snapshot.hasData &&
                          snapshot.data != null &&
                          snapshot.data!.isNotEmpty) {
                        // VISTA: Licencia Activa (SOLO LECTURA)
                        return _buildLicenseDetailsContent(snapshot.data!);
                      } else {
                        // VISTA: Sin Licencia Registrada (Formulario de Registro)
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

  // --- HEADER SUPERIOR ESTILO APPLE ---
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
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Licencia de Conducir',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Consulta el estatus, vigencia y tipo de credencial',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  // --- SKELETON APPLE DE CARGA ---
  Widget _buildSkeleton(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tarjeta Digital Skeleton
        const AppShimmerBox.card(
          height: 195,
          borderRadius: 20,
        ),
        const SizedBox(height: 16),
        // Sección Estatus
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: AppShimmerBox.text(width: 140, height: 12),
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
                        AppShimmerBox.text(width: 130, height: 14),
                        SizedBox(height: 6),
                        AppShimmerBox.text(width: 200, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const AppShimmerBox(
                  width: double.infinity, height: 46, borderRadius: 12),
            ],
          ),
        ),
      ],
    );
  }

  // --- ESTADO DE ERROR ESTILO APPLE ---
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
              'Error al cargar información de licencia',
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
              label: const Text('Reintentar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // VISTA: CUANDO TIENE LICENCIA ACTIVA (SOLO LECTURA / APPLE WALLET STYLE)
  // =========================================================================
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
        // 1. HERO DIGITAL DRIVER'S LICENSE CARD (APPLE WALLET STYLE)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0F172A),
                Color(0xFF0F2B48),
                Color(0xFF0284C7),
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
                color: const Color(0xFF0F172A).withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Destello decorativo superior derecho
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
                // Destello decorativo inferior izquierdo
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

                // Contenido de la Tarjeta Apple Wallet
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila Superior: Título Oficial + Sello de Seguridad
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.directions_car_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 9),
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
                                    'CREDENCIAL DIGITAL · MARK FLEET',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.65),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded,
                                    size: 12, color: Color(0xFF38BDF8)),
                                SizedBox(width: 4),
                                Text(
                                  'OFICIAL',
                                  style: TextStyle(
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

                      // Fila Central: Tipo de Licencia + Número Grande
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
                                const SizedBox(height: 4),
                                Text(
                                  _getCategoryDescription(category),
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
                                  'NÚMERO DE LICENCIA',
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
                                    licNumStr,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Fila Inferior: Vigencia + Badge de Estatus Integrado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Column(
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
                                  isPerm
                                      ? 'PERMANENTE'
                                      : _formatDueDate(dueRaw),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
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

        // 2. SECCIÓN: ESTATUS DEL DOCUMENTO (INSET GROUPED)
        _buildSectionTitle('ESTATUS DEL DOCUMENTO'),
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
                            : (isPerm
                                ? const Color(0xFFE0F2FE)
                                : const Color(0xFFDCFCE7))),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      isExpired
                          ? Icons.error_outline_rounded
                          : (isClose || isToday
                              ? Icons.warning_amber_rounded
                              : (isPerm
                                  ? Icons.all_inclusive_rounded
                                  : Icons.verified_rounded)),
                      color: isExpired
                          ? const Color(0xFFEF4444)
                          : (isClose || isToday
                              ? const Color(0xFFEA580C)
                              : (isPerm
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF10B981))),
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
                        isPerm
                            ? 'Licencia Permanente'
                            : (isExpired
                                ? 'Licencia Expirada'
                                : (isToday
                                    ? 'Vence el Día de Hoy'
                                    : (isClose
                                        ? 'Próxima a Vencer'
                                        : 'Licencia Vigente'))),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPerm
                            ? 'No requiere renovación periódica de vigencia'
                            : (isExpired
                                ? 'Venció hace ${-daysRemaining} días. Se requiere renovación.'
                                : (isToday
                                    ? 'Su validez expira hoy a las 23:59 hrs.'
                                    : 'Quedan $daysRemaining días de validez legal')),
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
                              ? 'Documento registrado apto para circulación permanente.'
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
        const SizedBox(height: 32),
      ],
    );
  }

  // =========================================================================
  // VISTA: REGISTRO DE LICENCIA (CUANDO NO EXISTE NINGUNA)
  // =========================================================================
  Widget _buildAddLicenseSection() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Inset de Estado Inicial
          Container(
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
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE0F2FE),
                        Color(0xFFBAE6FD),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.badge_outlined,
                      color: Color(0xFF0284C7),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
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
          const SizedBox(height: 8),

          // SECCIÓN: DATOS DE LA LICENCIA
          _buildSectionTitle('DATOS DE LA CREDENCIAL'),
          _buildAppleGroupContainer(
            children: [
              // Campo Número de Licencia
              _buildFormField(
                controller: _licNumController,
                label: 'Número de Licencia',
                icon: Icons.credit_card_rounded,
                maxLength: 12,
                hintText: 'Ej. LIC-8923491',
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingresa el número de licencia'
                    : null,
              ),
              const SizedBox(height: 12),

              // Campo Tipo / Categoría
              _buildFormField(
                controller: _licClassController,
                label: 'Tipo / Categoría (ej. A, B, C)',
                icon: Icons.category_outlined,
                maxLength: 2,
                hintText: 'Ej. A, B, C',
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingresa la categoría'
                    : null,
              ),
              const SizedBox(height: 12),

              // Switch Apple: Licencia Permanente
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.all_inclusive_rounded,
                        size: 18, color: Color(0xFF0284C7)),
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
                            'Activar si no tiene fecha de caducidad',
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
                      activeColor: const Color(0xFF0284C7),
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

              // Fecha de Vencimiento con BottomPicker (si no es permanente)
              if (!isPermanent) ...[
                const SizedBox(height: 12),
                _buildDateField(context),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // BOTÓN DE ACCIÓN REUTILIZABLE CON LOADING INTEGRADO (ESTILO APPLE EDIT PROFILE)
          LoadingActionButton(
            text: 'Guardar Licencia',
            isLoading: isLoading,
            icon: Icons.check_circle_rounded,
            height: 50,
            borderRadius: 16,
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _saveLicense(
                  num: _licNumController.text,
                  category: _licClassController.text,
                  date: dueDate,
                  permanent: isPermanent,
                );
              }
            },
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // --- SELECTOR DE FECHA ESTILO APPLE ---
  Widget _buildDateField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            'Fecha de Vencimiento',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              letterSpacing: -0.1,
            ),
          ),
        ),
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
          cursorColor: const Color(0xFF0284C7),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Seleccionar fecha',
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: Color(0xFF0284C7),
            ),
            suffixIcon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B),
              size: 18,
            ),
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
          controller: TextEditingController(
            text: dueDate != null
                ? DateFormat('dd / MM / yyyy').format(dueDate!)
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
    );
  }

  // --- CAMPO DE TEXTO ESTILIZADO APPLE ---
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.characters,
    String? hintText,
    String? Function(String?)? validator,
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
              letterSpacing: -0.1,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          validator: validator,
          cursorColor: const Color(0xFF0284C7),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            hintText: hintText ?? label,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              icon,
              size: 17,
              color: const Color(0xFF0284C7),
            ),
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

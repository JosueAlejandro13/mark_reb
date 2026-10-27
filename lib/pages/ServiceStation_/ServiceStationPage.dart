import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/pages/ServiceStation_/ServiceStatioRagePage.dart';
import 'package:mark_v3/providers/Station_/service_station_provider.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';

/// Pantalla de Estación de Servicio — Rediseño Apple Inset Grouped
class ServiceStationForm extends ConsumerStatefulWidget {
  final String idMainAccount;
  final String idCollaborator;

  const ServiceStationForm({
    super.key,
    required this.idMainAccount,
    required this.idCollaborator,
  });

  @override
  ConsumerState<ServiceStationForm> createState() => _ServiceStationFormState();
}

class _ServiceStationFormState extends ConsumerState<ServiceStationForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _litersController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadData();
    });
  }

  @override
  void dispose() {
    _litersController.dispose();
    super.dispose();
  }

  void _loadData() {
    ref.read(serviceStationProvider.notifier).initializeData(
          idCollaborator: widget.idCollaborator,
          idMainAccount: widget.idMainAccount,
        );
  }

  void _onLitersChanged(String val) {
    final parsed = int.tryParse(val) ?? 0;
    ref.read(serviceStationProvider.notifier).onLitersChanged(parsed);
  }

  void _setPresetLiters(int amount) {
    _litersController.text = amount.toString();
    ref.read(serviceStationProvider.notifier).onLitersChanged(amount);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(serviceStationProvider);
    if (!state.isFuelValid) {
      SnackbarTop.showError(
        context,
        "Este vehículo no admite este tipo de gasolina.",
        title: "Combustible incompatible",
      );
      return;
    }

    final liters = int.tryParse(_litersController.text.trim()) ?? 0;
    if (liters <= 0) {
      SnackbarTop.showInfo(
        context,
        "Por favor ingresa una cantidad de litros válida.",
        title: "Atención",
      );
      return;
    }

    // Modal de confirmación estilo Apple
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.local_gas_station_rounded,
              color: Color(0xFF0284C7),
              size: 22,
            ),
            SizedBox(width: 10),
            Text(
              "Confirmar Carga",
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "¿Deseas registrar este reabastecimiento con los siguientes datos?",
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    "Estación:",
                    state.stationData?['name']?.toString() ??
                        state.stationData?['code']?.toString() ??
                        'N/A',
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    "Combustible:",
                    state.selectedFuelTypeName ?? 'N/A',
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow("Litros:", "$liters L", isHighlight: true),
                  if (state.selectedFuelPrice != null) ...[
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      "Total estimado:",
                      "\$${(liters * state.selectedFuelPrice!).toStringAsFixed(2)} MXN",
                      isHighlight: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              "Cancelar",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              "Confirmar",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success =
        await ref.read(serviceStationProvider.notifier).submitRefuel(
              idMainAccount: widget.idMainAccount,
              idCollaborator: widget.idCollaborator,
              liters: liters,
            );

    if (!mounted) return;

    if (success) {
      SnackbarTop.showSuccess(
        context,
        "El reabastecimiento de combustible ha sido registrado exitosamente.",
        title: "¡Carga Registrada!",
      );
      Navigator.of(context).pop(true);
    } else {
      final errorMsg = ref.read(serviceStationProvider).errorMessage ??
          "Error al enviar los datos. Intente nuevamente.";
      SnackbarTop.showError(
        context,
        errorMsg,
        title: "Error al registrar",
      );
    }
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color:
                isHighlight ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isHighlight
                  ? const Color(0xFF0284C7)
                  : const Color(0xFF0F172A),
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) {
      return DateFormat('dd/MM/yyyy').format(date);
    }
    final parsed = DateTime.tryParse(date.toString());
    if (parsed != null) {
      return DateFormat('dd/MM/yyyy').format(parsed);
    }
    return date.toString();
  }

  // ── ENCABEZADO APPLE DESIGN (SIN SOMBRAS) ──────────────────────────────────
  Widget _buildAppleHeader(BuildContext context) {
    return Row(
      children: [
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
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estación de Servicio',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Registro y control de combustible para tu vehículo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
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

  // ── TÍTULO DE SECCIÓN INSET GROUPED ─────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
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

  // ── CONTENEDOR DE SECCIÓN (APPLE CARD, SIN SOMBRAS) ────────────────────────
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // ── PASTILLA DE PRECIO DE COMBUSTIBLE ──────────────────────────────────────
  Widget _buildFuelPricePill({
    required String name,
    required dynamic price,
    required Color brandColor,
    required Color bgColor,
    required bool isSelected,
  }) {
    final double? parsedPrice =
        price != null ? double.tryParse(price.toString()) : null;
    final String formattedPrice =
        parsedPrice != null ? '\$${parsedPrice.toStringAsFixed(2)}' : '--';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected ? bgColor : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? brandColor : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_gas_station_rounded,
                color: brandColor,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: brandColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formattedPrice,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isSelected ? brandColor : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 1),
          const Text(
            'por litro',
            style: TextStyle(
              fontSize: 9.5,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ── CARD DE VEHÍCULO Y ODÓMETRO (APPLE DESIGN) ─────────────────────────────
  Widget _buildVehicleOdometerCard(Map<String, dynamic>? vehicle) {
    final String eco = vehicle?['economic']?.toString().isNotEmpty == true
        ? vehicle!['economic'].toString()
        : (vehicle?['plates']?.toString().isNotEmpty == true
            ? vehicle!['plates'].toString()
            : 'Vehículo Asignado');

    final List<String> details = [
      if (vehicle?['brand']?.toString().isNotEmpty == true)
        vehicle!['brand'].toString(),
      if (vehicle?['model']?.toString().isNotEmpty == true)
        vehicle!['model'].toString(),
      if (vehicle?['plates']?.toString().isNotEmpty == true &&
          vehicle?['economic']?.toString().isNotEmpty == true)
        '(${vehicle!['plates']})',
    ];

    final String subtitle = details.isNotEmpty
        ? details.join(' ')
        : 'Datos asignados y combustible sugerido';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_car_rounded,
                color: Color(0xFF0284C7),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eco,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Odómetro
                  Expanded(
                    flex: 5,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.speed_rounded,
                          color: Color(0xFF0284C7),
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Odómetro',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                vehicle?['odom'] != null
                                    ? '${vehicle!['odom']} km'
                                    : (vehicle?['odometer'] != null
                                        ? '${vehicle!['odometer']} km'
                                        : 'N/A'),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider vertical
                  Container(
                    width: 1,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    color: const Color(0xFFE2E8F0),
                  ),

                  // Combustible Sugerido / Asignado
                  Expanded(
                    flex: 6,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.ev_station_rounded,
                          color: Color(0xFFD97706),
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Combustible',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                vehicle?['tipoCombustibleNombre'] ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }

  // ── ANIMACIÓN STAGGERED ESTILO APPLE ────────────────────────────────────────
  Widget _buildAnimatedItem(Widget child, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 260 + (index * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1.0 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiSession = MarkApiClient.instance.currentSession;
    final session = ref.watch(routesProvider).session ?? apiSession;
    final rol = (session?.rol ?? '').trim().toLowerCase();
    final isPreventa = session?.isPreventa == true || rol == 'preventa' || rol == 'vendedor';

    if (isPreventa) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1C1C1E)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Combustible', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_gas_station_outlined, size: 56, color: Colors.amber),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Acceso no disponible',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tu usuario es de preventa. El registro de combustible solo está disponible para choferes o personal operativo de flota.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final state = ref.watch(serviceStationProvider);

    // Manejo de errores de conexión y servidor
    if (state.isConnectionError) {
      return ConnectionErrorPage(onRetry: _loadData);
    }
    if (state.isServerError) {
      return ServerErrorPage(onRetry: _loadData);
    }
    if (state.isUnexpectedError) {
      return Unexpectederrorpage(onRetry: _loadData);
    }

    if (!state.isLoading &&
        (state.isOutOfRange ||
            state.isLocationDisabled ||
            state.isPermissionDenied)) {
      String title = "Sin estaciones cercanas";
      String description = state.errorMessage ??
          "No encontramos estaciones de servicio dentro del rango de tu vehículo. Por favor, verifica la ubicación de la unidad e intenta de nuevo.";

      if (state.isLocationDisabled) {
        title = "GPS del vehículo sin señal";
      } else if (state.isPermissionDenied) {
        title = "Permiso denegado";
        description =
            "Es necesario otorgar permisos para verificar la estación de servicio.";
      }

      return ServiceStationRagePage(
        title: title,
        description: description,
        onRetry: _loadData,
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final isSmallScreen = mediaQuery.size.width < 360;

    final station = state.stationData;
    final vehicle = state.vehicleConfig;

    // Detectar qué combustible está seleccionado para iluminar la pastilla correspondiente
    final selectedFuelId = int.tryParse(state.selectedFuelTypeId ?? '0') ?? 0;
    final isRegular = selectedFuelId == 6 || selectedFuelId == 7;
    final isPremium = selectedFuelId == 8 || selectedFuelId == 9;
    final isDiesel = selectedFuelId == 3 || selectedFuelId == 4;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: state.isLoading
                ? const ServiceStationSkeleton()
                : AbsorbPointer(
                    absorbing: state.isSubmitting,
                    child: RefreshIndicator(
                      color: const Color(0xFF0284C7),
                      backgroundColor: Colors.white,
                      onRefresh: () async {
                        await ref
                            .read(serviceStationProvider.notifier)
                            .initializeData(
                              idCollaborator: widget.idCollaborator,
                              idMainAccount: widget.idMainAccount,
                            );
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12.0 : 16.0,
                          vertical: 10.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 1. Encabezado Apple ───────────────────────
                            _buildAnimatedItem(_buildAppleHeader(context), 0),
                            const SizedBox(height: 14),

                            // ── 2. Card: Estación de Servicio ─────────────
                            _buildAnimatedItem(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('ESTACIÓN Y PRECIOS'),
                                  _buildSectionCard(
                                    icon: Icons.local_gas_station_rounded,
                                    iconColor: const Color(0xFF0284C7),
                                    title: station?['name']?.toString() ??
                                        'Estación de Servicio',
                                    subtitle:
                                        'Permiso: ${station?['reg'] ?? 'N/A'}',
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xFFA7F3D0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.near_me_rounded,
                                            size: 11,
                                            color: Color(0xFF059669),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            station?['dist'] != null
                                                ? '${(station!['dist'] as num).toStringAsFixed(0)} m'
                                                : 'Cerca',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF059669),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today_rounded,
                                            size: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Precios al: ${_formatDate(station?['fecha'])}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildFuelPricePill(
                                              name: 'Regular',
                                              price: station?['regular'],
                                              brandColor:
                                                  const Color(0xFF16A34A),
                                              bgColor: const Color(0xFFF0FDF4),
                                              isSelected: isRegular,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildFuelPricePill(
                                              name: 'Premium',
                                              price: station?['premium'],
                                              brandColor:
                                                  const Color(0xFFDC2626),
                                              bgColor: const Color(0xFFFEF2F2),
                                              isSelected: isPremium,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildFuelPricePill(
                                              name: 'Diésel',
                                              price: station?['diesel'],
                                              brandColor:
                                                  const Color(0xFF1E293B),
                                              bgColor: const Color(0xFFF1F5F9),
                                              isSelected: isDiesel,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              1,
                            ),

                            const SizedBox(height: 14),

                            // ── 3. Card: Vehículo y Odómetro ──────────────
                            _buildAnimatedItem(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('VEHÍCULO ASIGNADO'),
                                  _buildVehicleOdometerCard(vehicle),
                                ],
                              ),
                              2,
                            ),

                            const SizedBox(height: 14),

                            // ── 4. Card: Formulario de Carga ──────────────
                            _buildAnimatedItem(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('REGISTRO DE COMBUSTIBLE'),
                                  _buildSectionCard(
                                    icon: Icons.local_gas_station_rounded,
                                    iconColor: const Color(0xFF059669),
                                    title: 'Detalles de la Carga',
                                    subtitle:
                                        'Selecciona el combustible y litros abastecidos',
                                    children: [
                                      Form(
                                        key: _formKey,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Dropdown de combustible
                                            DropdownButtonFormField2<String>(
                                              value: state.selectedFuelTypeId,
                                              isExpanded: true,
                                              decoration: InputDecoration(
                                                labelText: 'Tipo de Gasolina',
                                                labelStyle: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 12.5,
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons
                                                      .local_gas_station_rounded,
                                                  color: Color(0xFF0284C7),
                                                  size: 18,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                filled: true,
                                                fillColor:
                                                    const Color(0xFFF8FAFC),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFFE2E8F0),
                                                    width: 1.0,
                                                  ),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFF0284C7),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 12,
                                                ),
                                              ),
                                              items:
                                                  state.fuelTypes.map((fuel) {
                                                return DropdownMenuItem<String>(
                                                  value: fuel['id'].toString(),
                                                  child: Text(
                                                    fuel['name'].toString(),
                                                    style: const TextStyle(
                                                      color: Color(0xFF0F172A),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                ref
                                                    .read(serviceStationProvider
                                                        .notifier)
                                                    .onFuelTypeChanged(val);
                                              },
                                              dropdownStyleData:
                                                  DropdownStyleData(
                                                maxHeight: 250,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  color: Colors.white,
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFE2E8F0)),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFF0F172A)
                                                          .withOpacity(0.08),
                                                      blurRadius: 12,
                                                      offset:
                                                          const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // Aviso de incompatibilidad si aplica
                                            if (!state.isFuelValid) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFEF2F2),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFFECACA)),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .error_outline_rounded,
                                                      color: Color(0xFFDC2626),
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Este vehículo no admite este tipo de combustible.',
                                                        style: TextStyle(
                                                          color:
                                                              Color(0xFFDC2626),
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            const SizedBox(height: 10),

                                            // Input de litros
                                            TextFormField(
                                              controller: _litersController,
                                              keyboardType:
                                                  TextInputType.number,
                                              maxLength: 3,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              onChanged: _onLitersChanged,
                                              decoration: InputDecoration(
                                                labelText: 'Litros a Cargar',
                                                hintText: 'Ej. 25',
                                                counterText: '',
                                                labelStyle: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 12.5,
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons.water_drop_outlined,
                                                  color: Color(0xFF0284C7),
                                                  size: 18,
                                                ),
                                                suffixText: 'Lts',
                                                suffixStyle: const TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                filled: true,
                                                fillColor:
                                                    const Color(0xFFF8FAFC),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFFE2E8F0),
                                                    width: 1.0,
                                                  ),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12.0),
                                                  borderSide: const BorderSide(
                                                    color: Color(0xFF0284C7),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 12,
                                                  horizontal: 12,
                                                ),
                                              ),
                                              style: const TextStyle(
                                                color: Color(0xFF0F172A),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              validator: (val) {
                                                if (val == null ||
                                                    val.trim().isEmpty) {
                                                  return 'Ingresa los litros';
                                                }
                                                final num =
                                                    int.tryParse(val) ?? 0;
                                                if (num <= 0) {
                                                  return 'Debe ser mayor a 0';
                                                }
                                                return null;
                                              },
                                            ),

                                            const SizedBox(height: 8),

                                            // Presets rápidos de litros
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                children: [
                                                  const Text(
                                                    'Rápido: ',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF64748B),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  ...[10, 20, 30, 40, 50]
                                                      .map((ltr) {
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              right: 6),
                                                      child: InkWell(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        onTap: () =>
                                                            _setPresetLiters(
                                                                ltr),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 10,
                                                            vertical: 5,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                0xFFEFF6FF),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                              color: const Color(
                                                                  0xFFBFDBFE),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            '+$ltr L',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: Color(
                                                                  0xFF0284C7),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),

                                            // Costo Estimado
                                            const SizedBox(height: 12),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    const Color(0xFFF0FDF4),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFBBF7D0)),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .receipt_long_rounded,
                                                        size: 16,
                                                        color:
                                                            Color(0xFF16A34A),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Costo estimado:',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF166534),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    '\$${(state.liters * (state.selectedFuelPrice ?? 0.0)).toStringAsFixed(2)} MXN',
                                                    style: const TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color:
                                                          Color(0xFF166534),
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
                                ],
                              ),
                              3,
                            ),

                            const SizedBox(height: 20),

                            // ── 5. Botón de Acción Principal Apple ────────
                            _buildAnimatedItem(
                              LoadingActionButton(
                                text: 'Registrar Reabastecimiento',
                                isLoading: state.isSubmitting,
                                icon: Icons.check_circle_outline_rounded,
                                onPressed:
                                    (state.isSubmitting || !state.isFuelValid)
                                        ? null
                                        : _submitForm,
                              ),
                              4,
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton Animado de Estación de Servicio Estilo Apple
class ServiceStationSkeleton extends StatelessWidget {
  const ServiceStationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          Row(
            children: [
              const AppShimmerBox(width: 38, height: 38, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmerBox.text(width: 170, height: 18),
                    SizedBox(height: 6),
                    AppShimmerBox.text(width: 240, height: 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Station Card Skeleton
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    AppShimmerBox.text(width: 160, height: 15),
                    AppShimmerBox(width: 60, height: 22, borderRadius: 8),
                  ],
                ),
                const SizedBox(height: 8),
                const AppShimmerBox.text(width: 110, height: 11),
                const SizedBox(height: 14),
                Row(
                  children: const [
                    Expanded(
                        child: AppShimmerBox(height: 64, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(
                        child: AppShimmerBox(height: 64, borderRadius: 12)),
                    SizedBox(width: 8),
                    Expanded(
                        child: AppShimmerBox(height: 64, borderRadius: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Vehicle & Odometer Card Skeleton
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                Expanded(
                  child: AppShimmerBox(height: 48, borderRadius: 10),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: AppShimmerBox(height: 48, borderRadius: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Fuel Details Form Card Skeleton
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppShimmerBox.text(width: 130, height: 14),
                SizedBox(height: 14),
                AppShimmerBox(height: 46, borderRadius: 12),
                SizedBox(height: 12),
                AppShimmerBox(height: 46, borderRadius: 12),
                SizedBox(height: 12),
                AppShimmerBox(width: 220, height: 26, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Submit Button Skeleton
          const AppShimmerBox.button(height: 50, borderRadius: 16),
        ],
      ),
    );
  }
}

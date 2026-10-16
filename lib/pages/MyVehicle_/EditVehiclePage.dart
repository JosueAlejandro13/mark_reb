import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/vehicle_model.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/pages/Error_/unexpectedErrorPage.dart';
import 'package:mark_v3/providers/Vehicles_/edit_vehicle_provider.dart';
import 'package:mark_v3/providers/Vehicles_/my_vehicle_provider.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:mark_v3/widgets/vehicle_skeleton.dart';

/// Pantalla de Edición de Vehículo — Apple Design (iOS HIG)
class EditVehiclePage extends ConsumerStatefulWidget {
  final Vehicle vehicle;
  final String userId;
  final String idMainAccount;
  final String idCollaborator;

  const EditVehiclePage({
    super.key,
    required this.vehicle,
    required this.userId,
    required this.idMainAccount,
    required this.idCollaborator,
  });

  @override
  ConsumerState<EditVehiclePage> createState() => _EditVehiclePageState();
}

class _EditVehiclePageState extends ConsumerState<EditVehiclePage> {
  late TextEditingController placasController;
  late TextEditingController vinController;
  late TextEditingController makeController;
  late TextEditingController modelController;
  late TextEditingController yearController;
  late TextEditingController cilindradaController;
  late TextEditingController nCilindrosController;
  late TextEditingController promConsumoController;
  late TextEditingController capacidadTanqueController;
  late TextEditingController colorController;
  final TextEditingController obsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    placasController = TextEditingController(text: widget.vehicle.placas);
    vinController = TextEditingController(text: widget.vehicle.vin);
    makeController = TextEditingController(text: widget.vehicle.make);
    modelController = TextEditingController(text: widget.vehicle.model);
    yearController = TextEditingController(text: widget.vehicle.year.toString());
    cilindradaController =
        TextEditingController(text: widget.vehicle.cilindrada.toString());
    nCilindrosController =
        TextEditingController(text: widget.vehicle.nCilindros.toString());
    colorController = TextEditingController(text: widget.vehicle.color);
    promConsumoController =
        TextEditingController(text: widget.vehicle.promConsumo.toString());
    capacidadTanqueController =
        TextEditingController(text: widget.vehicle.capacidadTanque.toString());

    Future.microtask(() {
      ref.read(editVehicleProvider.notifier).initializeData(
            vehicle: widget.vehicle,
            idCollaborator: widget.idCollaborator,
            idMainAccount: widget.idMainAccount,
          );
    });
  }

  @override
  void dispose() {
    placasController.dispose();
    vinController.dispose();
    makeController.dispose();
    modelController.dispose();
    yearController.dispose();
    cilindradaController.dispose();
    nCilindrosController.dispose();
    promConsumoController.dispose();
    capacidadTanqueController.dispose();
    colorController.dispose();
    obsController.dispose();
    super.dispose();
  }

  bool get _canEditVehicle =>
      MarkApiClient.instance.flota.can('vehiculo', 'editar');
  bool get _canEditStatus =>
      MarkApiClient.instance.flota.can('vehiculo', 'estatus');

  void _saveChanges() async {
    FocusScope.of(context).unfocus();

    if (!_canEditVehicle) {
      SnackbarTop.showInfo(
        context,
        "No cuentas con permisos administrativos para editar este vehículo.",
      );
      return;
    }

    final state = ref.read(editVehicleProvider);
    if (state.isSaving) return;

    if (state.selectedModelo == null || state.selectedModelo == "0") {
      SnackbarTop.showInfo(
        context,
        "Por favor, selecciona un modelo.",
      );
      return;
    }

    final success = await ref.read(editVehicleProvider.notifier).saveVehicle(
          vehicle: widget.vehicle,
          idMainAccount: widget.idMainAccount,
          userId: widget.userId,
          placas: placasController.text.trim(),
          vin: vinController.text.trim(),
          make: makeController.text.trim(),
          model: modelController.text.trim(),
          year: yearController.text.trim(),
          cilindrada: cilindradaController.text.trim(),
          nCilindros: nCilindrosController.text.trim(),
          promConsumo: promConsumoController.text.trim(),
          capacidadTanque: capacidadTanqueController.text.trim(),
          color: colorController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      ref.read(myVehicleProvider.notifier).loadVehicles(widget.idCollaborator);
      SnackbarTop.showSuccess(
        context,
        "Vehículo actualizado exitosamente.",
      );
      Navigator.pop(context, true);
    } else {
      final currentError = ref.read(editVehicleProvider).error;
      SnackbarTop.showError(
        context,
        currentError ?? "Error al guardar cambios. Intenta nuevamente más tarde.",
      );
    }
  }

  void _showChangeStatusDialog() {
    final state = ref.read(editVehicleProvider);
    String? localStatus = state.selectedStatus;
    bool isSavingStatus = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              title: Row(
                children: [
                  const Icon(
                    Icons.published_with_changes_rounded,
                    color: Color(0xFF0284C7),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cambiar Estado',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Modifica el estatus operativo',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDropdown(
                      localStatus,
                      'Seleccionar Estado',
                      state.estadosVehiculo,
                      (newValue) {
                        setDialogState(() {
                          localStatus = newValue;
                        });
                        ref
                            .read(editVehicleProvider.notifier)
                            .onStatusChanged(newValue);
                      },
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                      ),
                      enabled: !isSavingStatus,
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 2, bottom: 5),
                          child: Text(
                            'Observaciones',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 100,
                          child: TextField(
                            controller: obsController,
                            enabled: !isSavingStatus,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            cursorColor: const Color(0xFF0284C7),
                            decoration: InputDecoration(
                              hintText: 'Detalles del cambio de estado...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: !isSavingStatus
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0), width: 1.0),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.black.withOpacity(0.04)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0284C7), width: 1.5),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.all(12),
                              counterText: "",
                            ),
                            maxLength: 100,
                            style: TextStyle(
                              color: !isSavingStatus
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: <Widget>[
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSavingStatus
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LoadingActionButton(
                        text: 'Guardar',
                        isLoading: isSavingStatus,
                        height: 44,
                        borderRadius: 12,
                        fontSize: 13,
                        icon: Icons.check_circle_rounded,
                        onPressed: isSavingStatus
                            ? null
                            : () async {
                                if (localStatus == null ||
                                    localStatus!.isEmpty) {
                                  SnackbarTop.showInfo(
                                    context,
                                    "Por favor, selecciona un estado.",
                                  );
                                  return;
                                }

                                if (obsController.text.trim().isEmpty) {
                                  SnackbarTop.showInfo(
                                    context,
                                    "Por favor, ingresa las observaciones.",
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  isSavingStatus = true;
                                });

                                final success = await ref
                                    .read(editVehicleProvider.notifier)
                                    .updateVehicleStatus(
                                      vehicle: widget.vehicle,
                                      userId: widget.userId,
                                      idMainAccount: widget.idMainAccount,
                                      newStatus: localStatus!,
                                      observations: obsController.text.trim(),
                                      vehiclePlacas:
                                          placasController.text.trim(),
                                    );

                                if (!dialogContext.mounted) return;
                                setDialogState(() {
                                  isSavingStatus = false;
                                });

                                if (success) {
                                  ref
                                      .read(myVehicleProvider.notifier)
                                      .loadVehicles(widget.idCollaborator);
                                  Navigator.of(dialogContext).pop();
                                  if (context.mounted) {
                                    SnackbarTop.showSuccess(
                                      context,
                                      "Estado del vehículo actualizado con éxito.",
                                    );
                                    Navigator.of(context).pop(true);
                                  }
                                } else {
                                  if (context.mounted) {
                                    SnackbarTop.showError(
                                      context,
                                      "Error al actualizar el estado.",
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editVehicleProvider);

    // Manejo de errores de conexión y servidor
    if (state.isConnectionError) {
      return ConnectionErrorPage(
        onRetry: () {
          ref.read(editVehicleProvider.notifier).initializeData(
                vehicle: widget.vehicle,
                idCollaborator: widget.idCollaborator,
                idMainAccount: widget.idMainAccount,
              );
        },
      );
    }

    if (state.isServerError) {
      return ServerErrorPage(
        onRetry: () {
          ref.read(editVehicleProvider.notifier).initializeData(
                vehicle: widget.vehicle,
                idCollaborator: widget.idCollaborator,
                idMainAccount: widget.idMainAccount,
              );
        },
      );
    }

    if (state.isUnexpectedError) {
      return Unexpectederrorpage(
        onRetry: () {
          ref.read(editVehicleProvider.notifier).initializeData(
                vehicle: widget.vehicle,
                idCollaborator: widget.idCollaborator,
                idMainAccount: widget.idMainAccount,
              );
        },
      );
    }

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
          child: state.isLoading
              ? const EditVehicleSkeleton()
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 14.0 : 18.0,
                      vertical: 10.0,
                    ),
                    child: AbsorbPointer(
                      absorbing: state.isSaving,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── 1. Encabezado Apple con botón de estado ─────────
                          _buildAnimatedItem(_buildAppleHeader(context), 0),
                          const SizedBox(height: 12),

                          // Banner si el usuario no tiene permisos para editar vehículo (Nelson doc)
                          if (!_canEditVehicle)
                            _buildAnimatedItem(
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
                                        'Modo solo lectura: Tu rol no cuenta con permisos administrativos para modificar datos técnicos del vehículo. Solicita la actualización a tu supervisor.',
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
                              0,
                            ),

                          // ── 2. Sección: Identificación del Vehículo ─────────
                          _buildAnimatedItem(
                            _buildSectionTitle('IDENTIFICACIÓN DEL VEHÍCULO'),
                            1,
                          ),
                          _buildAnimatedItem(
                            _buildAppleGroupContainer(
                              children: [
                                _buildMarcaDropdown(state,
                                    enabled: _canEditVehicle && !state.isSaving),
                                const SizedBox(height: 12),
                                _buildModeloDropdown(state,
                                    enabled: _canEditVehicle && !state.isSaving),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        yearController,
                                        'Año',
                                        Icons.calendar_month_rounded,
                                        maxLength: 4,
                                        enabled: _canEditVehicle && !state.isSaving,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildTextField(
                                        placasController,
                                        'Placas',
                                        Icons.badge_rounded,
                                        maxLength: 10,
                                        enabled: _canEditVehicle && !state.isSaving,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        vinController,
                                        'VIN',
                                        Icons.fingerprint_rounded,
                                        maxLength: 17,
                                        enabled: _canEditVehicle && !state.isSaving,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildTextField(
                                        colorController,
                                        'Color',
                                        Icons.palette_rounded,
                                        maxLength: 20,
                                        enabled: _canEditVehicle && !state.isSaving,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            2,
                          ),
                          const SizedBox(height: 18),

                          // ── 3. Sección: Motor y Rendimiento ─────────────────
                          _buildAnimatedItem(
                            _buildSectionTitle('MOTOR Y RENDIMIENTO'),
                            3,
                          ),
                          _buildAnimatedItem(
                            _buildAppleGroupContainer(
                              children: [
                                _buildDropdown(
                                  state.selectedTiposVehiculo,
                                  'Tipo de Vehículo',
                                  state.tiposVehiculo,
                                  (newValue) {
                                    ref
                                        .read(editVehicleProvider.notifier)
                                        .onTipoVehiculoChanged(newValue);
                                  },
                                  icon: const Icon(
                                    Icons.category_rounded,
                                    size: 18,
                                  ),
                                  enabled: _canEditVehicle && !state.isSaving,
                                ),
                                const SizedBox(height: 12),
                                _buildDropdown(
                                  state.selectedTipoCombustible,
                                  'Tipo de Combustible',
                                  state.tipoCombustible,
                                  (newValue) {
                                    ref
                                        .read(editVehicleProvider.notifier)
                                        .onTipoCombustibleChanged(newValue);
                                  },
                                  icon: const Icon(
                                    Icons.local_gas_station_rounded,
                                    size: 18,
                                  ),
                                  enabled: _canEditVehicle && !state.isSaving,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        cilindradaController,
                                        'Cilindrada',
                                        Icons.tune_rounded,
                                        maxLength: 10,
                                        enabled: _canEditVehicle && !state.isSaving,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildTextField(
                                        nCilindrosController,
                                        'N° Cilindros',
                                        Icons.storage_rounded,
                                        maxLength: 10,
                                        enabled: _canEditVehicle && !state.isSaving,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        promConsumoController,
                                        'Prom. Consumo',
                                        Icons.speed_rounded,
                                        maxLength: 10,
                                        enabled: _canEditVehicle && !state.isSaving,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildTextField(
                                        capacidadTanqueController,
                                        'Cap. Tanque (L)',
                                        Icons.local_shipping_rounded,
                                        maxLength: 10,
                                        enabled: _canEditVehicle && !state.isSaving,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            4,
                          ),
                          const SizedBox(height: 24),

                          // ── 4. Botón de Acción con Loading integrado ────────
                          _buildAnimatedItem(
                            !_canEditVehicle
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.lock_rounded,
                                            size: 16,
                                            color: Color(0xFF64748B)),
                                        SizedBox(width: 8),
                                        Text(
                                          'Edición restringida por permisos corporativos',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : LoadingActionButton(
                                    text: 'Guardar Cambios',
                                    isLoading: state.isSaving,
                                    onPressed: _saveChanges,
                                    icon: Icons.check_circle_rounded,
                                    height: 50,
                                    borderRadius: 16,
                                  ),
                            5,
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ── ENCABEZADO APPLE ────────────────────────────────────────────────────────
  Widget _buildAppleHeader(BuildContext context) {
    final isSaving = ref.watch(editVehicleProvider).isSaving;

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isSaving ? null : () => Navigator.of(context).maybePop(),
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
                'Editar Vehículo',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Actualiza las especificaciones y datos técnicos',
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
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: (isSaving || !_canEditStatus) ? null : _showChangeStatusDialog,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _canEditStatus ? Colors.white : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Icon(
                  _canEditStatus
                      ? Icons.published_with_changes_rounded
                      : Icons.lock_outline_rounded,
                  color: _canEditStatus
                      ? const Color(0xFF0284C7)
                      : const Color(0xFF94A3B8),
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }



  // ── TÍTULO DE SECCIÓN INSET GROUPED ─────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
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

  // ── CONTENEDOR INSET GROUPED ESTILO APPLE ───────────────────────────────────
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

  // ── CAMPO DE TEXTO ESTILO APPLE ─────────────────────────────────────────────
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    required int maxLength,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? const Color(0xFF475569)
                      : const Color(0xFF94A3B8),
                  letterSpacing: -0.1,
                ),
              ),
              if (!enabled)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Fijo',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        TextField(
          controller: controller,
          enabled: enabled,
          readOnly: !enabled,
          maxLength: maxLength,
          cursorColor: const Color(0xFF0284C7),
          style: TextStyle(
            color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: label,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              icon,
              size: 17,
              color: enabled
                  ? const Color(0xFF0284C7)
                  : const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor:
                enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
            counterText: "",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.04)),
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

  // ── DROPDOWNS MARCA / MODELO ESTILO APPLE ───────────────────────────────────
  Widget _buildMarcaDropdown(EditVehicleState state, {bool enabled = true}) {
    return _buildDropdown(
      state.selectedMarca,
      'Marca',
      state.obtenerMake,
      (newValue) {
        if (newValue != null) {
          final makeItem = state.obtenerMake.firstWhere(
            (make) => make['id'].toString() == newValue,
            orElse: () => {'name': ''},
          );
          makeController.text = makeItem['name']?.toString() ?? '';
          modelController.text = '';
        }
        ref.read(editVehicleProvider.notifier).onMarcaChanged(newValue);
      },
      icon: const Icon(
        Icons.directions_car_rounded,
        size: 18,
      ),
      enabled: enabled,
    );
  }

  Widget _buildModeloDropdown(EditVehicleState state, {bool enabled = true}) {
    return _buildDropdown(
      state.selectedModelo,
      'Modelo',
      state.obtenerModel,
      (newValue) {
        if (newValue != null) {
          final modelItem = state.obtenerModel.firstWhere(
            (model) => model['id'].toString() == newValue,
            orElse: () => {'name': ''},
          );
          modelController.text = modelItem['name']?.toString() ?? '';
        }
        ref.read(editVehicleProvider.notifier).onModeloChanged(newValue);
      },
      icon: const Icon(
        Icons.car_repair_rounded,
        size: 18,
      ),
      enabled: enabled,
    );
  }

  // ── DROPDOWN GENÉRICO APPLE ─────────────────────────────────────────────────
  Widget _buildDropdown(
    String? selectedItem,
    String hint,
    List<Map<String, dynamic>> items,
    ValueChanged<String?> onChanged, {
    required Icon icon,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hint,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? const Color(0xFF475569)
                      : const Color(0xFF94A3B8),
                  letterSpacing: -0.1,
                ),
              ),
              if (!enabled)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Fijo',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        DropdownButtonFormField2<String>(
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            fillColor:
                enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.04)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
            prefixIcon: Icon(
              icon.icon,
              size: 17,
              color: enabled
                  ? const Color(0xFF0284C7)
                  : const Color(0xFF94A3B8),
            ),
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w400,
            ),
          ),
          value: (selectedItem != null &&
                  items.any((item) => item['id'].toString() == selectedItem))
              ? selectedItem
              : null,
          onChanged: enabled ? onChanged : null,
          items: [
            const DropdownMenuItem<String>(
              value: "0",
              child: Text(
                'Seleccione una opción',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
            ...items.map((Map<String, dynamic> item) {
              return DropdownMenuItem<String>(
                value: item['id'].toString(),
                child: Text(
                  item['name']?.toString() ?? '',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }),
          ],
          style: TextStyle(
            color: enabled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            fontSize: 13.5,
          ),
          buttonStyleData: const ButtonStyleData(
            padding: EdgeInsets.only(right: 8),
          ),
          iconStyleData: IconStyleData(
            icon: Icon(
              Icons.arrow_drop_down_rounded,
              color: enabled
                  ? const Color(0xFF64748B)
                  : const Color(0xFF94A3B8),
            ),
          ),
          dropdownStyleData: DropdownStyleData(
            maxHeight: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(
            padding: EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
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
}

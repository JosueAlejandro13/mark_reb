import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mark_v3/models/Vehicles_/vehicle_model.dart';
import 'package:mark_v3/pages/Error_/ConnectionErrorPage.dart';
import 'package:mark_v3/pages/Error_/InspError.dart';
import 'package:mark_v3/pages/Error_/ServerErrorPage.dart';
import 'package:mark_v3/providers/Inspeccion_/inspection_execution_provider.dart';
import 'package:mark_v3/services/ConnectionInspeccion_/InspeccionCon_service.dart';
import 'package:mark_v3/widgets/app_skeleton.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:permission_handler/permission_handler.dart';

/// Pantalla de Inspección Vehicular — Diseño Apple Ejecutivo
class MyInspectVehiclePage extends ConsumerStatefulWidget {
  final String userId;
  final Vehicle vehicle;
  final String plantillaId;
  final String idCollaborator;
  final int enableStorePhoto;
  final String idMainAccount;

  const MyInspectVehiclePage({
    super.key,
    required this.userId,
    required this.vehicle,
    required this.idCollaborator,
    required this.plantillaId,
    required this.enableStorePhoto,
    required this.idMainAccount,
  });

  @override
  ConsumerState<MyInspectVehiclePage> createState() =>
      _MyInspectVehiclePageState();
}

class _MyInspectVehiclePageState extends ConsumerState<MyInspectVehiclePage> {
  final ImagePicker _picker = ImagePicker();
  final InspeccionconService _dbService = InspeccionconService();

  late final TextEditingController _observationsController;
  final Map<int, TextEditingController> _itemCommentControllers = {};

  bool _isWarningShown = false;

  @override
  void initState() {
    super.initState();
    _observationsController = TextEditingController();

    // Invalidar inmediatamente cualquier estado previo al entrar para que nunca persista
    Future.microtask(() {
      if (mounted) {
        ref.invalidate(inspectionExecutionProvider);
        ref.read(inspectionExecutionProvider.notifier).initInspection(
              vehicleId: widget.vehicle.id.toString(),
              plantillaId: widget.plantillaId,
            );
      }
    });
  }

  @override
  void dispose() {
    _observationsController.dispose();
    for (var controller in _itemCommentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getCommentController(int index, String initialText) {
    if (!_itemCommentControllers.containsKey(index)) {
      _itemCommentControllers[index] =
          TextEditingController(text: initialText);
    }
    return _itemCommentControllers[index]!;
  }

  void _showNotice(String message, {bool isError = true}) {
    if (_isWarningShown) return;
    _isWarningShown = true;

    if (isError) {
      SnackbarTop.showError(context, message);
    } else {
      SnackbarTop.showInfo(context, message);
    }

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) {
        _isWarningShown = false;
      }
    });
  }

  // --- SELECCIÓN DE FOTO (CÁMARA / GALERÍA) ---
  Future<void> _pickImage(int index) async {
    final state = ref.read(inspectionExecutionProvider);
    if (state.startDateTime == null) {
      _showNotice('Debes presionar "Iniciar Revisión" primero para comenzar.');
      return;
    }
    final notifier = ref.read(inspectionExecutionProvider.notifier);

    if (widget.enableStorePhoto == 1) {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_a_photo_rounded,
                  color: Color(0xFF0284C7), size: 22),
              SizedBox(width: 10),
              Text(
                'Adjuntar Evidencia',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          content: const Text(
            'Elige el origen de la fotografía para documentar esta inspección:',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Galería'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFFBAE6FD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Cámara'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      if (source == null) return;

      if (source == ImageSource.camera) {
        var status = await Permission.camera.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          _showNotice('Se requieren permisos de cámara para capturar la evidencia.');
          return;
        }
      }

      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );

      if (photo != null) {
        notifier.setItemImage(index, photo.path);
      }
    } else {
      var status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        _showNotice('Se requieren permisos de cámara para capturar la evidencia.');
        return;
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
      );

      if (photo != null) {
        notifier.setItemImage(index, photo.path);
      }
    }
  }

  // --- VALIDACIÓN Y ENVÍO DE LA INSPECCIÓN ---
  Future<void> _handleFinishInspection() async {
    final state = ref.read(inspectionExecutionProvider);

    // 1. Validar que la inspección haya sido iniciada
    if (state.startDateTime == null) {
      _showNotice('Debes presionar "Iniciar Revisión" primero para poder terminar.');
      return;
    }

    // 2. Validar que todos los items hayan sido evaluados
    if (!state.allCompleted) {
      final uncompleted = state.items.where((it) => !it.isCompleted).length;
      _showNotice(
        'Faltan $uncompleted puntos por evaluar o con foto requerida pendiente.',
        isError: true,
      );
      return;
    }

    // 3. Validar estado general seleccionado
    if (state.selectedStatus == null || state.selectedStatus!.isEmpty) {
      _showNotice('Selecciona el estado general de la inspección.');
      return;
    }

    // 4. Confirmación antes de enviar
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded,
                color: Color(0xFF0284C7), size: 24),
            SizedBox(width: 10),
            Text(
              'Finalizar Inspección',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        content: Text(
          'Se guardarán ${state.totalCount} puntos evaluados (${state.passedCount} aprobados, ${state.failedCount} fallas). ¿Deseas confirmar y enviar el reporte?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Revisar más',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Confirmar y Guardar',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _executeCreateInspection();
  }

  Future<void> _executeCreateInspection() async {
    final state = ref.read(inspectionExecutionProvider);
    final notifier = ref.read(inspectionExecutionProvider.notifier);

    notifier.setSubmitting(true);

    // Diálogo de carga estilo Apple minimalista
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingAnimationWidget.threeRotatingDots(
                color: const Color(0xFF0284C7),
                size: 34,
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guardando inspección...',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sincronizando puntos y evidencias',
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
      ),
    );

    try {
      // Construir lista de items formateados
      final List<Map<String, dynamic>> items = state.items.map((item) {
        final commentController = _itemCommentControllers[item.index];
        final comment = commentController?.text ?? item.comment;

        return {
          'idItem': int.tryParse(item.idItemDefault) ?? (item.index + 1),
          'status': item.isActive ? 1 : 0,
          'auxval': '',
          'comment': comment,
          'imgUrl': item.imagePath ?? '',
        };
      }).toList();

      // Obtener posición geográfica de forma segura
      String location = '0.0, 0.0';
      try {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 4),
          );
          location = '${pos.latitude}, ${pos.longitude}';
        }
      } catch (geoError) {
        debugPrint('Ubicación por defecto: $geoError');
      }

      // Obtener el ID del estado seleccionado según la guía de Nelson (Pág. 7 y 9):
      // estatus (1: Excelente, 2: Regular / Con detalles, 3: Fallida)
      int statusId = 1;
      if (state.selectedStatus == 'Excelente' && state.allPassed) {
        statusId = 1;
      } else if (state.selectedStatus == 'Fallida / Mala') {
        statusId = 3;
      } else {
        statusId = 2; // Regular / Con detalles
      }

      DateTime startDate = DateTime.now();
      if (state.startDateTime != null) {
        try {
          startDate = DateFormat('dd/MM/yyyy HH:mm').parse(state.startDateTime!);
        } catch (_) {
          startDate = DateTime.now();
        }
      }

      await _dbService.crearInspeccionYItems(
        widget.idMainAccount,
        widget.vehicle.id.toString(),
        widget.plantillaId,
        startDate,
        DateTime.now(),
        widget.idCollaborator,
        statusId,
        location,
        _observationsController.text.trim(),
        0,
        '0',
        items,
      );

      notifier.setSubmitting(false);

      if (!mounted) return;
      Navigator.of(context).pop(); // Cierra diálogo de carga

      // Diálogo de éxito estilo Apple (con azul ejecutivo, sin verde estridente)
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF0284C7), size: 26),
              SizedBox(width: 10),
              Text(
                'Inspección Registrada',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          content: const Text(
            'La inspección ha sido registrada y guardada exitosamente en el sistema.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.45),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true); // Retorna a plantillas
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Aceptar',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      notifier.setSubmitting(false);
      if (!mounted) return;
      Navigator.of(context).pop(); // Cierra diálogo de carga

      debugPrint('Error al crear inspección: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.error_rounded, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 10),
              Text(
                'Error al guardar',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          content: Text(
            'Ocurrió un inconveniente al guardar la inspección: $e\nPor favor, verifica tu conexión y vuelve a intentarlo.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cerrar',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionExecutionProvider);

    // Manejo de errores de red o servidor
    if (state.isConnectionError) {
      return ConnectionErrorPage(
        onRetry: () => ref
            .read(inspectionExecutionProvider.notifier)
            .initInspection(
              vehicleId: widget.vehicle.id.toString(),
              plantillaId: widget.plantillaId,
            ),
      );
    }

    if (state.isServerError) {
      return ServerErrorPage(
        onRetry: () => ref
            .read(inspectionExecutionProvider.notifier)
            .initInspection(
              vehicleId: widget.vehicle.id.toString(),
              plantillaId: widget.plantillaId,
            ),
      );
    }

    if (state.isInspError) {
      return InspError(
        onRetry: () => ref
            .read(inspectionExecutionProvider.notifier)
            .initInspection(
              vehicleId: widget.vehicle.id.toString(),
              plantillaId: widget.plantillaId,
            ),
      );
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
        body: SafeArea(
          child: state.isLoading
              ? AppSkeleton.inspection()
              : Column(
                  children: [
                    // 1. INICIO ANCLADO (STICKY HEADER)
                    _buildStickyHeader(state),

                    // 2. LISTA CON SCROLL DE ITEMS DE INSPECCIÓN
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        itemCount: state.items.length,
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildInspectionItemCard(item, state),
                          );
                        },
                      ),
                    ),

                    // 3. CONTROLES ANCLADOS ABAJO PARA TERMINAR (Solo si ya se inició la revisión)
                    if (state.startDateTime != null)
                      _buildStickyBottomControls(state),
                  ],
                ),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. INICIO ANCLADO (STICKY HEADER ESTILO APPLE)
  // =========================================================================
  Widget _buildStickyHeader(InspectionExecutionState state) {
    final notifier = ref.read(inspectionExecutionProvider.notifier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Botón Volver + Título "Inspección Vehicular" + Vehículo
          Row(
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
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inspección Vehicular',
                      style: TextStyle(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '${widget.vehicle.make} ${widget.vehicle.model} • Placas: ${widget.vehicle.placas.isNotEmpty ? widget.vehicle.placas : "Sin placas"}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // BOTÓN OBLIGATORIO PARA INICIAR LA REVISIÓN O ESTADO DE INICIO
          if (state.startDateTime == null)
            LoadingActionButton(
              text: 'Iniciar Revisión',
              icon: Icons.play_arrow_rounded,
              isLoading: false,
              onPressed: () => notifier.startInspection(),
              height: 48,
              borderRadius: 14,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: Color(0xFF0284C7)),
                      SizedBox(width: 6),
                      Text(
                        'Revisión Iniciada',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 13, color: Color(0xFF0284C7)),
                      const SizedBox(width: 4),
                      Text(
                        state.startDateTime!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Barra de progreso y resumen de evaluación (Solo si ya se inició la revisión)
          if (state.startDateTime != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progreso: ${state.completedCount} de ${state.totalCount} evaluados',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                Text(
                  '${(state.progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  state.allCompleted
                      ? const Color(0xFF059669)
                      : const Color(0xFF0284C7),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildMiniCounterChip(
                  label: '${state.passedCount} Aprobados',
                  color: const Color(0xFF059669),
                  bg: const Color(0xFFECFDF5),
                  border: const Color(0xFFA7F3D0),
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(width: 8),
                _buildMiniCounterChip(
                  label: '${state.failedCount} Fallas',
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEF2F2),
                  border: const Color(0xFFFECACA),
                  icon: Icons.cancel_rounded,
                ),
                const SizedBox(width: 8),
                _buildMiniCounterChip(
                  label: '${state.pendingCount} Pendientes',
                  color: state.pendingCount == 0
                      ? const Color(0xFF059669)
                      : const Color(0xFF64748B),
                  bg: state.pendingCount == 0
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF8FAFC),
                  border: state.pendingCount == 0
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFE2E8F0),
                  icon: Icons.pending_actions_rounded,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniCounterChip({
    required String label,
    required Color color,
    required Color bg,
    required Color border,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. TARJETA DE INSPECCIÓN (DISEÑO APPLE HIG INSET GROUPED)
  // =========================================================================
  Widget _buildInspectionItemCard(
      InspectionItem item, InspectionExecutionState state) {
    final notifier = ref.read(inspectionExecutionProvider.notifier);

    final bool isCompleted = item.isCompleted;
    final bool isManipulated = item.isManipulated;
    final commentController =
        _getCommentController(item.index, item.comment);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: !item.isManipulated
              ? const Color(0xFFE2E8F0)
              : (item.isActive
                  ? const Color(0xFFA7F3D0)
                  : const Color(0xFFFECACA)),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de la tarjeta: Título + Badge de estado + Flecha colapsar
            InkWell(
              onTap: () {
                if (state.startDateTime == null) {
                  _showNotice(
                    'Debes presionar "Iniciar Revisión" primero para comenzar.',
                    isError: true,
                  );
                  return;
                }
                if (!isCompleted) {
                  _showNotice(
                    'Debes evaluar este punto antes de poder cerrarlo.',
                    isError: true,
                  );
                } else {
                  notifier.toggleItemCollapse(item.index);
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    // Ícono de estado Apple
                    Icon(
                      isCompleted
                          ? (item.isActive
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded)
                          : (isManipulated
                              ? Icons.warning_rounded
                              : Icons.radio_button_unchecked_rounded),
                      color: isCompleted
                          ? (item.isActive
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626))
                          : const Color(0xFF94A3B8),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    // Título del elemento
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (item.isCollapsed)
                            Text(
                              item.isActive
                                  ? 'Aprobado'
                                  : 'Con falla registrada',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: item.isActive
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Badge de estado estilo Apple
                    if (!isManipulated)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text(
                          'Pendiente',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      )
                    else if (item.needsPhoto)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text(
                          'Falta foto',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: item.isActive
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: item.isActive
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Text(
                          item.isActive ? 'Aprobado' : 'Falla',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: item.isActive
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),

                    const SizedBox(width: 6),

                    // Ícono de colapsar / expandir
                    Icon(
                      isCompleted
                          ? (item.isCollapsed
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded)
                          : Icons.lock_outline_rounded,
                      size: 19,
                      color: isCompleted
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),

            // Contenido expandible de la tarjeta
            if (!item.isCollapsed) ...[
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Descripción e instrucciones
                    if (item.description.trim().isNotEmpty &&
                        item.description.trim().toLowerCase() !=
                            'descripción no disponible') ...[
                      Text(
                        item.description.trim(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF475569),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (item.instruction.trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 15, color: Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.instruction.trim(),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF0369A1),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Botones de acción: "Aprobado" vs "Falla" con diseño Apple
                    Row(
                      children: [
                        // Opción Aprobado
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (state.startDateTime == null) {
                                _showNotice(
                                  'Debes presionar "Iniciar Revisión" primero para comenzar.',
                                  isError: true,
                                );
                                return;
                              }
                              notifier.setItemStatus(item.index, isActive: true);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                gradient: item.isPassed
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF10B981),
                                          Color(0xFF059669),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: item.isPassed
                                    ? null
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: item.isPassed
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFE2E8F0),
                                  width: item.isPassed ? 1.5 : 1.0,
                                ),
                                boxShadow: item.isPassed
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF059669)
                                              .withOpacity(0.26),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.isPassed
                                        ? Icons.check_circle_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color: item.isPassed
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Aprobado',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: item.isPassed
                                          ? Colors.white
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Opción Falla
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (state.startDateTime == null) {
                                _showNotice(
                                  'Debes presionar "Iniciar Revisión" primero para comenzar.',
                                  isError: true,
                                );
                                return;
                              }
                              notifier.setItemStatus(item.index, isActive: false);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                gradient: item.isFailed
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFDC2626),
                                          Color(0xFFB91C1C),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: item.isFailed
                                    ? null
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: item.isFailed
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFFE2E8F0),
                                  width: item.isFailed ? 1.5 : 1.0,
                                ),
                                boxShadow: item.isFailed
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFDC2626)
                                              .withOpacity(0.24),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.isFailed
                                        ? Icons.cancel_rounded
                                        : Icons.highlight_off_rounded,
                                    size: 16,
                                    color: item.isFailed
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Falla',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: item.isFailed
                                          ? Colors.white
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Si falló y requiere foto, advertencia visual
                    if (item.isFailed && item.requirePhotoFail) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.photo_camera_rounded,
                                size: 15, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Esta falla requiere evidencia fotográfica obligatoria.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Vista previa de imagen o botón para adjuntarla
                    if (item.isFailed || item.imagePath != null) ...[
                      const SizedBox(height: 12),
                      if (item.imagePath != null) ...[
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(item.imagePath!),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Foto adjunta',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _pickImage(item.index),
                                        icon: const Icon(Icons.refresh_rounded,
                                            size: 15),
                                        label: const Text('Cambiar'),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF0284C7),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => notifier.setItemImage(
                                            item.index, null),
                                        icon: const Icon(Icons.delete_outline_rounded,
                                            size: 15, color: Color(0xFFDC2626)),
                                        label: const Text('Eliminar',
                                            style: TextStyle(
                                                color: Color(0xFFDC2626))),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(item.index),
                          icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                          label: Text(
                            item.requirePhotoFail
                                ? 'Tomar foto requerida'
                                : 'Adjuntar foto (opcional)',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: item.requirePhotoFail
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF0284C7),
                            side: BorderSide(
                              color: item.requirePhotoFail
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFBAE6FD),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 12),

                    // Campo de comentario del punto
                    TextField(
                      controller: commentController,
                      onChanged: (text) =>
                          notifier.setItemComment(item.index, text),
                      decoration: InputDecoration(
                        labelText: 'Observación del punto (opcional)',
                        labelStyle: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF0284C7), width: 1.4),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. CONTROLES ANCLADOS ABAJO PARA TERMINAR (ESTILO APPLE)
  // =========================================================================
  Widget _buildStickyBottomControls(InspectionExecutionState state) {
    final notifier = ref.read(inspectionExecutionProvider.notifier);

    // Filtrar los estados permitidos según la regla estricta de Nelson (Pág. 9):
    // "Si hay un punto malo, el estatus general no puede ser 1 «Excelente»."
    final bool allItemsPassed = state.allPassed;
    final List<Map<String, dynamic>> availableStatuses = state.statuses.where((s) {
      final code = s['code'] ?? s['id'] ?? 1;
      if (allItemsPassed) {
        return code == 1 || code == 2;
      } else {
        return code == 2 || code == 3;
      }
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CONTROL 1: Campo de Observaciones Generales
          Row(
            children: [
              const Icon(Icons.edit_note_rounded,
                  size: 22, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _observationsController,
                    onChanged: (text) => notifier.setObservations(text),
                    decoration: InputDecoration(
                      hintText: 'Observaciones generales o kilometraje...',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF0284C7), width: 1.4),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // CONTROL 2: Selector de Estado General
          Builder(
            builder: (context) {
              final Set<String> uniqueNames = {};
              final List<DropdownMenuItem<String>> dropdownItems = [];
              for (final status in availableStatuses) {
                final name = status['name']?.toString() ?? '';
                final int code = status['code'] ?? status['id'] ?? 1;
                final Color color = code == 1
                    ? const Color(0xFF059669)
                    : (code == 2
                        ? const Color(0xFFD97706)
                        : const Color(0xFFDC2626));

                if (name.isNotEmpty && uniqueNames.add(name)) {
                  dropdownItems.add(
                    DropdownMenuItem<String>(
                      value: name,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }

              final bool isValueInItems = dropdownItems
                  .any((item) => item.value == state.selectedStatus);
              final String? currentDropdownValue = isValueInItems
                  ? state.selectedStatus
                  : (dropdownItems.isNotEmpty ? dropdownItems.first.value : null);

              return Row(
                children: [
                  const Text(
                    'Estado:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          value: currentDropdownValue,
                          hint: const Text(
                            'Selecciona estado...',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                          icon: const Icon(Icons.arrow_drop_down_rounded,
                              color: Color(0xFF64748B)),
                          items: dropdownItems,
                          onChanged: (newStatus) {
                            notifier.setSelectedStatus(newStatus);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // CONTROL 3: Botón Deslizable hacia la derecha para Terminar Revisión
          SwipeToFinishButton(
            label: 'Desliza para terminar revisión',
            isLoading: state.isSubmitting,
            onConfirmed: () => _handleFinishInspection(),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// WIDGET PERSONALIZADO: BOTÓN DESLIZABLE A LA DERECHA (SWIPE TO CONFIRM APPLE)
// =========================================================================
class SwipeToFinishButton extends StatefulWidget {
  final Future<void> Function() onConfirmed;
  final bool isLoading;
  final String label;

  const SwipeToFinishButton({
    super.key,
    required this.onConfirmed,
    this.isLoading = false,
    this.label = 'Desliza para terminar revisión',
  });

  @override
  State<SwipeToFinishButton> createState() => _SwipeToFinishButtonState();
}

class _SwipeToFinishButtonState extends State<SwipeToFinishButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  late AnimationController _animController;
  late Animation<double> _resetAnimation;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        setState(() {
          _dragPosition = _resetAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _reset() {
    if (!mounted) return;
    _resetAnimation = Tween<double>(
      begin: _dragPosition,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward(from: 0.0);
    _isFinished = false;
  }

  @override
  Widget build(BuildContext context) {
    const double height = 50.0;
    const double handlePadding = 3.5;
    const double handleSize = height - (handlePadding * 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag =
            constraints.maxWidth - handleSize - (handlePadding * 2);

        return Container(
          height: height,
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Stack(
            children: [
              // Barra de relleno con color que sigue el arrastre
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: (_dragPosition + handleSize + handlePadding * 2)
                    .clamp(0.0, constraints.maxWidth),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),

              // Texto central con flecha indicativa
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 36, right: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        color: Color(0xFF0284C7),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              // Agarradera / Handle deslizable estilo Apple
              Positioned(
                left: handlePadding + _dragPosition,
                top: handlePadding,
                child: GestureDetector(
                  onHorizontalDragUpdate: widget.isLoading || _isFinished
                      ? null
                      : (details) {
                          if (_animController.isAnimating) return;
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx)
                                .clamp(0.0, maxDrag);
                          });
                        },
                  onHorizontalDragEnd: widget.isLoading || _isFinished
                      ? null
                      : (details) async {
                          if (_animController.isAnimating) return;
                          // Umbral de activación al 75%
                          if (_dragPosition >= maxDrag * 0.75) {
                            setState(() {
                              _dragPosition = maxDrag;
                              _isFinished = true;
                            });
                            await widget.onConfirmed();
                            if (mounted) {
                              _reset();
                            }
                          } else {
                            _reset();
                          }
                        },
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0284C7),
                          Color(0xFF0369A1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isLoading
                          ? LoadingAnimationWidget.threeRotatingDots(
                              color: Colors.white,
                              size: 18,
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mark_v3/services/ConnectionInspeccion_/InspeccionCon_service.dart';
import 'package:mark_v3/services/ConnectionMyVehicle_/MyVehicleCon_service.dart';

// Modelo inmutable para cada elemento de inspección
class InspectionItem {
  final int index;
  final String idItemDefault;
  final String name;
  final String description;
  final String instruction;
  final bool requirePhotoFail;
  final bool isManipulated;
  final bool isActive; // true: Aprobado (Pasó), false: Falla (No pasó)
  final String? imagePath;
  final String comment;
  final bool isCollapsed;

  const InspectionItem({
    required this.index,
    required this.idItemDefault,
    required this.name,
    required this.description,
    required this.instruction,
    required this.requirePhotoFail,
    this.isManipulated = false,
    this.isActive = true,
    this.imagePath,
    this.comment = '',
    this.isCollapsed = false,
  });

  bool get isPassed => isManipulated && isActive;
  bool get isFailed => isManipulated && !isActive;

  // Si falló y requiere foto, necesita tener foto para considerarse completado
  bool get needsPhoto => isFailed && requirePhotoFail && (imagePath == null || imagePath!.isEmpty);

  // Completado: fue manipulado y no tiene fotos pendientes obligatorias
  bool get isCompleted => isManipulated && !needsPhoto;

  InspectionItem copyWith({
    int? index,
    String? idItemDefault,
    String? name,
    String? description,
    String? instruction,
    bool? requirePhotoFail,
    bool? isManipulated,
    bool? isActive,
    String? imagePath,
    bool clearImage = false,
    String? comment,
    bool? isCollapsed,
  }) {
    return InspectionItem(
      index: index ?? this.index,
      idItemDefault: idItemDefault ?? this.idItemDefault,
      name: name ?? this.name,
      description: description ?? this.description,
      instruction: instruction ?? this.instruction,
      requirePhotoFail: requirePhotoFail ?? this.requirePhotoFail,
      isManipulated: isManipulated ?? this.isManipulated,
      isActive: isActive ?? this.isActive,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      comment: comment ?? this.comment,
      isCollapsed: isCollapsed ?? this.isCollapsed,
    );
  }
}

// Estado inmutable de la ejecución de inspección
class InspectionExecutionState {
  final bool isLoading;
  final bool isConnectionError;
  final bool isServerError;
  final bool isInspError;
  final String? errorMessage;
  final List<InspectionItem> items;
  final List<Map<String, dynamic>> statuses;
  final String? selectedStatus;
  final String? startDateTime;
  final String? endDateTime;
  final String observations;
  final bool isSubmitting;
  final bool isStatusManuallySet;

  const InspectionExecutionState({
    this.isLoading = true,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isInspError = false,
    this.errorMessage,
    this.items = const [],
    this.statuses = const [],
    this.selectedStatus,
    this.startDateTime,
    this.endDateTime,
    this.observations = '',
    this.isSubmitting = false,
    this.isStatusManuallySet = false,
  });

  int get totalCount => items.length;
  int get completedCount => items.where((i) => i.isCompleted).length;
  int get passedCount => items.where((i) => i.isPassed).length;
  int get failedCount => items.where((i) => i.isFailed).length;
  int get pendingCount => items.where((i) => !i.isCompleted).length;
  double get progress => totalCount == 0 ? 0.0 : (completedCount / totalCount);
  bool get allCompleted => totalCount > 0 && completedCount == totalCount;
  bool get allPassed => totalCount > 0 && items.every((i) => i.isPassed);

  InspectionExecutionState copyWith({
    bool? isLoading,
    bool? isConnectionError,
    bool? isServerError,
    bool? isInspError,
    String? errorMessage,
    List<InspectionItem>? items,
    List<Map<String, dynamic>>? statuses,
    String? selectedStatus,
    bool clearSelectedStatus = false,
    String? startDateTime,
    bool clearStartDateTime = false,
    String? endDateTime,
    String? observations,
    bool? isSubmitting,
    bool? isStatusManuallySet,
  }) {
    return InspectionExecutionState(
      isLoading: isLoading ?? this.isLoading,
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isInspError: isInspError ?? this.isInspError,
      errorMessage: errorMessage ?? this.errorMessage,
      items: items ?? this.items,
      statuses: statuses ?? this.statuses,
      selectedStatus: clearSelectedStatus ? null : (selectedStatus ?? this.selectedStatus),
      startDateTime: clearStartDateTime ? null : (startDateTime ?? this.startDateTime),
      endDateTime: endDateTime ?? this.endDateTime,
      observations: observations ?? this.observations,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isStatusManuallySet: isStatusManuallySet ?? this.isStatusManuallySet,
    );
  }
}

// Provider de la ejecución de inspección (se resetea al entrar y salir de la pantalla)
final inspectionExecutionProvider = NotifierProvider<
    InspectionExecutionNotifier,
    InspectionExecutionState>(InspectionExecutionNotifier.new);

class InspectionExecutionNotifier
    extends Notifier<InspectionExecutionState> {
  final InspeccionconService _dbService = InspeccionconService();
  final MyvehicleconService _vehicleService = MyvehicleconService();

  @override
  InspectionExecutionState build() {
    return const InspectionExecutionState();
  }

  void reset() {
    state = const InspectionExecutionState();
  }

  Future<void> initInspection({
    required String vehicleId,
    required String plantillaId,
  }) async {
    // Resetear completamente para no conservar ningún progreso anterior
    state = const InspectionExecutionState(
      isLoading: true,
      startDateTime: null,
    );

    try {
      // 1. Cargar estados generales y elementos en paralelo
      final results = await Future.wait([
        _vehicleService.obtenerStatus(),
        _dbService
            .obtenerInspeccionesPorVehiculo(
              idVehic: vehicleId,
              idItemTemplate: plantillaId,
            )
            .timeout(const Duration(seconds: 12)),
      ]);

      final List<Map<String, dynamic>> statuses =
          List<Map<String, dynamic>>.from(results[0]);
      final List<Map<String, dynamic>> rawInspections =
          List<Map<String, dynamic>>.from(results[1]);

      if (rawInspections.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          isInspError: true,
          errorMessage: 'No se encontraron preguntas de inspección.',
        );
        return;
      }

      // Convertir a modelos de ítem
      final List<InspectionItem> items = [];
      for (int i = 0; i < rawInspections.length; i++) {
        final raw = rawInspections[i];
        final idItemDefault = raw['idItemDefault']?.toString() ?? '$i';
        final name = raw['defaultItemName']?.toString() ?? 'Punto ${i + 1}';
        final description = raw['description']?.toString() ?? '';
        final instruction = raw['instruction']?.toString() ?? '';
        final requirePhotoFail = (raw['requirePhotoFail'] == true ||
            raw['requirePhotoFail'] == 1 ||
            raw['requirePhotoFail'] == '1');

        items.add(InspectionItem(
          index: i,
          idItemDefault: idItemDefault,
          name: name,
          description: description,
          instruction: instruction,
          requirePhotoFail: requirePhotoFail,
          isManipulated: false,
          isActive: true,
          isCollapsed: false, // Inician abiertas
        ));
      }

      // Seleccionar automáticamente el estado óptimo inicial (índice 0, ej: "Excelente")
      final String? initialStatus =
          statuses.isNotEmpty ? statuses[0]['name']?.toString() : null;

      // No auto-iniciamos el tiempo: el usuario debe presionar obligatoriamente "Iniciar Revisión"
      state = state.copyWith(
        isLoading: false,
        items: items,
        statuses: statuses,
        selectedStatus: initialStatus,
        isStatusManuallySet: false,
        clearStartDateTime: true,
      );
    } on TimeoutException {
      state = state.copyWith(
        isLoading: false,
        isServerError: true,
        errorMessage: 'Tiempo de espera agotado al conectar con el servidor.',
      );
    } on SocketException {
      state = state.copyWith(
        isLoading: false,
        isConnectionError: true,
        errorMessage: 'Error de conexión a internet.',
      );
    } catch (e) {
      debugPrint('Error al inicializar inspección: $e');
      state = state.copyWith(
        isLoading: false,
        isInspError: true,
        errorMessage: e.toString(),
      );
    }
  }

  void startInspection() {
    state = state.copyWith(
      startDateTime: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
    );
  }

  void setItemStatus(int index, {required bool isActive}) {
    if (index < 0 || index >= state.items.length) return;

    final updatedItems = [...state.items];
    final current = updatedItems[index];

    // Al evaluarlo, queda manipulado.
    // Solo si está 100% Aprobado (isActive == true) se colapsa automáticamente.
    // Si tiene Falla (isActive == false), se mantiene abierta para requerir foto/comentarios.
    final updated = current.copyWith(
      isManipulated: true,
      isActive: isActive,
      isCollapsed: isActive ? true : false,
    );

    updatedItems[index] = updated;

    // Actualizar estado general recomendado si todos pasaron o alguno falló
    _updateAutoSelectedStatus(updatedItems);
  }

  void setItemComment(int index, String comment) {
    if (index < 0 || index >= state.items.length) return;
    final updatedItems = [...state.items];
    updatedItems[index] = updatedItems[index].copyWith(comment: comment);
    state = state.copyWith(items: updatedItems);
  }

  void setItemImage(int index, String? imagePath) {
    if (index < 0 || index >= state.items.length) return;
    final updatedItems = [...state.items];
    if (imagePath == null) {
      updatedItems[index] = updatedItems[index].copyWith(clearImage: true);
    } else {
      updatedItems[index] = updatedItems[index].copyWith(imagePath: imagePath);
    }
    state = state.copyWith(items: updatedItems);
  }

  /// Intenta alternar el colapso de la tarjeta.
  /// REGLA: Si no ha sido manipulado o no está completado, NO se puede colapsar (retorna false).
  bool toggleItemCollapse(int index) {
    if (index < 0 || index >= state.items.length) return false;

    final current = state.items[index];

    // Si aún no está completado, no se permite colapsar
    if (!current.isCompleted) {
      return false;
    }

    final updatedItems = [...state.items];
    updatedItems[index] = current.copyWith(isCollapsed: !current.isCollapsed);
    state = state.copyWith(items: updatedItems);
    return true;
  }

  /// Colapsa todas las tarjetas completadas para despejar la vista
  void collapseAllCompleted() {
    final updatedItems = state.items.map((item) {
      if (item.isCompleted) {
        return item.copyWith(isCollapsed: true);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updatedItems);
  }

  /// Expande todas las tarjetas
  void expandAll() {
    final updatedItems = state.items.map((item) {
      return item.copyWith(isCollapsed: false);
    }).toList();
    state = state.copyWith(items: updatedItems);
  }

  void setSelectedStatus(String? status, {bool isManual = true}) {
    state = state.copyWith(
      selectedStatus: status,
      isStatusManuallySet: isManual,
    );
  }

  void setObservations(String obs) {
    state = state.copyWith(observations: obs);
  }

  void setSubmitting(bool isSubmitting) {
    state = state.copyWith(isSubmitting: isSubmitting);
  }

  /// Calcula dinámicamente el estado general según los puntos evaluados
  void _updateAutoSelectedStatus(List<InspectionItem> items) {
    if (state.statuses.isEmpty) {
      state = state.copyWith(items: items);
      return;
    }

    final hasFaults = items.any((i) => i.isManipulated && !i.isActive);
    final allPassed = !hasFaults;

    String? currentStatus = state.selectedStatus;
    final String excellentName =
        state.statuses[0]['name']?.toString() ?? '';

    if (allPassed) {
      // Si todos los puntos pasan y el usuario no forzó manualmente otro estado permitido,
      // o si estaba en estado de fallo, volver dinámicamente a "Excelente"
      if (!state.isStatusManuallySet || currentStatus != excellentName) {
        currentStatus = excellentName;
      }
    } else {
      // Hay al menos una falla: "Excelente" ya no es una opción válida para fallas
      if (currentStatus == excellentName ||
          !state.isStatusManuallySet ||
          currentStatus == null) {
        final failCount =
            items.where((i) => i.isManipulated && !i.isActive).length;

        if (failCount >= 3 && state.statuses.length > 2) {
          // Si hay 3 o más fallas, asignar estado más severo (índice 2, ej: "Malo")
          currentStatus = state.statuses[2]['name']?.toString();
        } else if (state.statuses.length > 1) {
          // Si hay 1 o 2 fallas, asignar estado intermedio (índice 1, ej: "Regular / Bueno")
          currentStatus = state.statuses[1]['name']?.toString();
        }
      }
    }

    state = state.copyWith(
      items: items,
      selectedStatus: currentStatus,
      clearSelectedStatus: currentStatus == null,
    );
  }
}

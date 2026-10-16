import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/vehicle_model.dart';
import 'package:mark_v3/services/ConnectionMyVehicle_/MyVehicleCon_service.dart';
import 'package:mark_v3/services/ConnectionNotification_/NotificationCon_service.dart';
import 'package:mark_v3/services/ConnectionProfile_/ProfileCon_service.dart';

// Estado inmutable de Edición de Vehículo
class EditVehicleState {
  final bool isLoading;
  final bool isSaving;
  final bool isChangingStatus;
  final List<Map<String, dynamic>> tiposVehiculo;
  final List<Map<String, dynamic>> obtenerEngomados;
  final List<Map<String, dynamic>> tipoCombustible;
  final List<Map<String, dynamic>> estadosVehiculo;
  final List<Map<String, dynamic>> obtenerMake;
  final List<Map<String, dynamic>> obtenerModel;
  final Map<String, dynamic> profile;
  final String? selectedMarca;
  final String? selectedModelo;
  final String? selectedTiposVehiculo;
  final String? selectedTipoCombustible;
  final String? selectedStatus;
  final String typeSource;
  final String typeSources;
  final String? error;
  final String? successMessage;
  final bool isConnectionError;
  final bool isServerError;
  final bool isUnexpectedError;

  const EditVehicleState({
    this.isLoading = true,
    this.isSaving = false,
    this.isChangingStatus = false,
    this.tiposVehiculo = const [],
    this.obtenerEngomados = const [],
    this.tipoCombustible = const [],
    this.estadosVehiculo = const [],
    this.obtenerMake = const [],
    this.obtenerModel = const [],
    this.profile = const {},
    this.selectedMarca,
    this.selectedModelo,
    this.selectedTiposVehiculo,
    this.selectedTipoCombustible,
    this.selectedStatus,
    this.typeSource = '',
    this.typeSources = '',
    this.error,
    this.successMessage,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isUnexpectedError = false,
  });

  EditVehicleState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isChangingStatus,
    List<Map<String, dynamic>>? tiposVehiculo,
    List<Map<String, dynamic>>? obtenerEngomados,
    List<Map<String, dynamic>>? tipoCombustible,
    List<Map<String, dynamic>>? estadosVehiculo,
    List<Map<String, dynamic>>? obtenerMake,
    List<Map<String, dynamic>>? obtenerModel,
    Map<String, dynamic>? profile,
    String? selectedMarca,
    String? selectedModelo,
    String? selectedTiposVehiculo,
    String? selectedTipoCombustible,
    String? selectedStatus,
    String? typeSource,
    String? typeSources,
    String? error,
    String? successMessage,
    bool? isConnectionError,
    bool? isServerError,
    bool? isUnexpectedError,
    bool clearSelectedModelo = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return EditVehicleState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isChangingStatus: isChangingStatus ?? this.isChangingStatus,
      tiposVehiculo: tiposVehiculo ?? this.tiposVehiculo,
      obtenerEngomados: obtenerEngomados ?? this.obtenerEngomados,
      tipoCombustible: tipoCombustible ?? this.tipoCombustible,
      estadosVehiculo: estadosVehiculo ?? this.estadosVehiculo,
      obtenerMake: obtenerMake ?? this.obtenerMake,
      obtenerModel: obtenerModel ?? this.obtenerModel,
      profile: profile ?? this.profile,
      selectedMarca: selectedMarca ?? this.selectedMarca,
      selectedModelo:
          clearSelectedModelo ? null : (selectedModelo ?? this.selectedModelo),
      selectedTiposVehiculo:
          selectedTiposVehiculo ?? this.selectedTiposVehiculo,
      selectedTipoCombustible:
          selectedTipoCombustible ?? this.selectedTipoCombustible,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      typeSource: typeSource ?? this.typeSource,
      typeSources: typeSources ?? this.typeSources,
      error: clearError ? null : (error ?? this.error),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isUnexpectedError: isUnexpectedError ?? this.isUnexpectedError,
    );
  }
}

// Provider global de Edición de Vehículo
final editVehicleProvider =
    NotifierProvider<EditVehicleNotifier, EditVehicleState>(
        EditVehicleNotifier.new);

class EditVehicleNotifier extends Notifier<EditVehicleState> {
  final MyvehicleconService _dbService = MyvehicleconService();
  final NotificationService _notificationService = NotificationService();
  final ProfileconService _profileService = ProfileconService();

  @override
  EditVehicleState build() {
    return const EditVehicleState();
  }

  Future<void> initializeData({
    required Vehicle vehicle,
    required String idCollaborator,
    required String idMainAccount,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      isConnectionError: false,
      isServerError: false,
      isUnexpectedError: false,
    );

    try {
      final catalogos = await _dbService.obtenerCatalogosVehiculo();
      final tiposVehiculo = catalogos['vehicType'] ?? [];
      final obtenerEngomados = catalogos['engomados'] ?? [];
      final tipoCombustible = catalogos['vehicFuel'] ?? [];
      final estadosVehiculo = catalogos['vehicStatus'] ?? [];
      final obtenerMake = catalogos['make'] ?? [];

      Map<String, dynamic> profile = {};
      try {
        profile =
            await _profileService.getUserData(idCollaborator, idMainAccount);
      } catch (e) {
        debugPrint('Error profile: $e');
      }

      String typeSource = '';
      String typeSources = '';
      try {
        final dataSource =
            await _notificationService.gettypSource('vehic_data');
        typeSource = dataSource['id']?.toString() ?? '';
      } catch (e) {
        debugPrint("Error en TypeSource: $e");
      }
      try {
        final historySource = await _notificationService
            .gettypSource('vehic_historicalStatusVehicles');
        typeSources = historySource['id']?.toString() ?? '';
      } catch (e) {
        debugPrint("Error en TypeSources: $e");
      }

      // Initial vehicle values
      final makeItem = obtenerMake.firstWhere(
        (m) => m['name'] == vehicle.make,
        orElse: () => {'id': '0'},
      );
      final selectedMarca = makeItem['id']?.toString() ?? '0';

      List<Map<String, dynamic>> models = [];
      String? selectedModelo;
      if (selectedMarca != '0') {
        try {
          models = await _dbService.obtenerModel(int.parse(selectedMarca));
          final modelItem = models.firstWhere(
            (m) => m['name'] == vehicle.model,
            orElse: () => {'id': '0'},
          );
          selectedModelo = modelItem['id']?.toString() ?? '0';
        } catch (e) {
          debugPrint('Error cargando modelos iniciales: $e');
        }
      }

      final tipoVehiculoItem = tiposVehiculo.firstWhere(
        (t) => t['name'] == vehicle.tipoVehiculoNombre,
        orElse: () => {'id': '0'},
      );
      final selectedTiposVehiculo = tipoVehiculoItem['id']?.toString() ?? '0';

      final combustibleItem = tipoCombustible.firstWhere(
        (t) => t['name'] == vehicle.tipoCombustibleNombre,
        orElse: () => {'id': '0'},
      );
      final selectedTipoCombustible =
          combustibleItem['id']?.toString() ?? '0';

      final statusItem = estadosVehiculo.firstWhere(
        (s) => s['name'] == vehicle.Status,
        orElse: () => {'id': '0'},
      );
      final selectedStatus = statusItem['id']?.toString() ?? '0';

      state = state.copyWith(
        isLoading: false,
        tiposVehiculo: tiposVehiculo,
        obtenerEngomados: obtenerEngomados,
        tipoCombustible: tipoCombustible,
        estadosVehiculo: estadosVehiculo,
        obtenerMake: obtenerMake,
        obtenerModel: models,
        profile: profile,
        typeSource: typeSource,
        typeSources: typeSources,
        selectedMarca: selectedMarca,
        selectedModelo: selectedModelo,
        selectedTiposVehiculo: selectedTiposVehiculo,
        selectedTipoCombustible: selectedTipoCombustible,
        selectedStatus: selectedStatus,
      );
    } on SocketException catch (_) {
      state = state.copyWith(isLoading: false, isConnectionError: true);
    } on TimeoutException catch (_) {
      state = state.copyWith(isLoading: false, isServerError: true);
    } catch (e) {
      debugPrint("Error inesperado en initializeData: $e");
      state = state.copyWith(isLoading: false, isUnexpectedError: true);
    }
  }

  Future<void> onMarcaChanged(String? newMarcaId) async {
    state = state.copyWith(
      selectedMarca: newMarcaId,
      clearSelectedModelo: true,
      obtenerModel: [],
    );

    if (newMarcaId != null && newMarcaId != '0') {
      try {
        final models = await _dbService.obtenerModel(int.parse(newMarcaId));
        state = state.copyWith(obtenerModel: models);
      } catch (e) {
        debugPrint('Error al cargar modelos: $e');
      }
    }
  }

  void onModeloChanged(String? newModelId) {
    state = state.copyWith(selectedModelo: newModelId);
  }

  void onTipoVehiculoChanged(String? newTipo) {
    state = state.copyWith(selectedTiposVehiculo: newTipo ?? '0');
  }

  void onTipoCombustibleChanged(String? newCombustible) {
    state = state.copyWith(selectedTipoCombustible: newCombustible);
  }

  void onStatusChanged(String? newStatus) {
    state = state.copyWith(selectedStatus: newStatus);
  }

  Future<bool> saveVehicle({
    required Vehicle vehicle,
    required String idMainAccount,
    required String userId,
    required String placas,
    required String vin,
    required String make,
    required String model,
    required String year,
    required String cilindrada,
    required String nCilindros,
    required String promConsumo,
    required String capacidadTanque,
    required String color,
  }) async {
    state =
        state.copyWith(isSaving: true, clearError: true, clearSuccess: true);
    try {
      final vehicleData = {
        'idvehic': vehicle.id,
        'placas': placas,
        'vin': vin,
        'make': make,
        'model': model,
        'year': int.tryParse(year) ?? 0,
        'cilindrada': cilindrada.isNotEmpty ? cilindrada : '0',
        'nCilindros': nCilindros.isNotEmpty ? nCilindros : '0',
        'promConsumo': promConsumo.isNotEmpty ? promConsumo : '0',
        'capacidadTanque':
            capacidadTanque.isNotEmpty ? capacidadTanque : '0',
        'color': color,
        'idTypVehic': state.selectedTiposVehiculo ?? '0',
        'idTypFuel': state.selectedTipoCombustible ?? '0',
        'idMake': state.selectedMarca ?? '0',
        'idModel': state.selectedModelo ?? '0',
      };

      await _dbService.updateVehicleT(vehicleData, idMainAccount);

      // Notification
      try {
        const nameNotice = 'vehicle_data_edited';
        final noticeTemplate =
            await _notificationService.getNoticeByName(nameNotice);
        if (noticeTemplate != null) {
          String message = '';
          final rawMessage = noticeTemplate['message'];
          if (rawMessage is String) {
            message = rawMessage;
          } else if (rawMessage is List<int>) {
            message = utf8.decode(rawMessage);
          } else if (rawMessage != null) {
            message = rawMessage.toString();
          }

          final title = (noticeTemplate['title'] ?? '')
              .replaceAll('{vehicle_plate}', placas);
          final finalMessage = '$title|$message|${noticeTemplate['icon']}';

          final notificationData = {
            'typeSource': state.typeSource,
            'idOrigin': vehicle.id.toString(),
            'typEvent': 2,
            'date': DateTime.now().toIso8601String(),
            'message': finalMessage,
            'colNotice': 'vehic_Update',
            'idMainAcoount': idMainAccount.toString(),
            'codUsGenerator': userId.toString(),
            'idDev': userId.toString(),
          };
          await _notificationService.insertNotification(notificationData);
        }
      } catch (notifErr) {
        debugPrint(
            'Error enviando notificación de edición de vehículo: $notifErr');
      }

      state = state.copyWith(
        isSaving: false,
        successMessage: 'Vehículo actualizado exitosamente.',
      );
      return true;
    } catch (e) {
      debugPrint('Error al guardar vehículo: $e');
      final rawMsg = e.toString().replaceFirst('Exception: ', '').trim();
      state = state.copyWith(
        isSaving: false,
        error: rawMsg.isNotEmpty
            ? rawMsg
            : 'Error al guardar cambios. Intente nuevamente más tarde.',
      );
      return false;
    }
  }

  Future<bool> updateVehicleStatus({
    required Vehicle vehicle,
    required String userId,
    required String idMainAccount,
    required String newStatus,
    required String observations,
    required String vehiclePlacas,
  }) async {
    state = state.copyWith(isChangingStatus: true, clearError: true);
    try {
      final selectedStatusInt = int.tryParse(newStatus) ?? -1;
      final vehicleStatusInt =
          int.tryParse(vehicle.idStatus.toString()) ?? -1;

      if (selectedStatusInt != vehicleStatusInt) {
        await _notificationService.insertStatus(
          userId,
          vehicle.id.toString(),
          observations,
          DateTime.now(),
          newStatus,
          "0",
          "0",
        );
      }

      await _dbService.updatevehicleStatus(newStatus, vehicle.id.toString());

      try {
        const nameNotice = "vehicle_status_changed";
        final noticeTemplate =
            await _notificationService.getNoticeByName(nameNotice);
        if (noticeTemplate != null) {
          String message = '';
          final rawMessage = noticeTemplate['message'];
          if (rawMessage is String) {
            message = rawMessage;
          } else if (rawMessage is List<int>) {
            message = utf8.decode(rawMessage);
          } else if (rawMessage != null) {
            message = rawMessage.toString();
          }

          final userEmail = state.profile['email']?.toString() ?? '';
          final formattedMessage = message
              .replaceAll("{new_status}", newStatus)
              .replaceAll("{user}", userEmail)
              .replaceAll("{observations}", observations);

          final title = (noticeTemplate['title'] ?? '')
              .replaceAll("{vehicle_plate}", vehiclePlacas);
          final finalMessage =
              "$title|$formattedMessage|${noticeTemplate['icon']}";

          final notificationData = {
            'typeSource': state.typeSources,
            'idOrigin': vehicle.id.toString(),
            'typEvent': 2,
            'date': DateTime.now().toIso8601String(),
            'message': finalMessage,
            'colNotice': 'vehic_Status',
            'idMainAcoount': idMainAccount,
            'codUsGenerator': userId,
            'idDev': userId,
          };
          await _notificationService.insertNotification(notificationData);
        }
      } catch (notifErr) {
        debugPrint('Error enviando notificación de status: $notifErr');
      }

      state = state.copyWith(
        isChangingStatus: false,
        selectedStatus: newStatus,
      );
      return true;
    } catch (e) {
      debugPrint('Error al cambiar status: $e');
      final rawMsg = e.toString().replaceFirst('Exception: ', '').trim();
      state = state.copyWith(
        isChangingStatus: false,
        error: rawMsg.isNotEmpty ? rawMsg : 'Error al cambiar estado.',
      );
      return false;
    }
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/vehicle_model.dart';
import 'package:mark_v3/services/ConnectionMyVehicle_/MyVehicleCon_service.dart';

// Estado inmutable para la pantalla de Mis Vehículos
class MyVehicleState {
  final bool isLoading;
  final List<Vehicle> vehicles;
  final String? error;
  final bool isConnectionError;
  final bool isServerError;
  final bool isUnexpectedError;

  const MyVehicleState({
    this.isLoading = true,
    this.vehicles = const [],
    this.error,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isUnexpectedError = false,
  });

  MyVehicleState copyWith({
    bool? isLoading,
    List<Vehicle>? vehicles,
    String? error,
    bool clearError = false,
    bool? isConnectionError,
    bool? isServerError,
    bool? isUnexpectedError,
  }) {
    return MyVehicleState(
      isLoading: isLoading ?? this.isLoading,
      vehicles: vehicles ?? this.vehicles,
      error: clearError ? null : (error ?? this.error),
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isUnexpectedError: isUnexpectedError ?? this.isUnexpectedError,
    );
  }
}

// Provider global de MyVehicle
final myVehicleProvider =
    NotifierProvider<MyVehicleNotifier, MyVehicleState>(MyVehicleNotifier.new);

class MyVehicleNotifier extends Notifier<MyVehicleState> {
  final MyvehicleconService _service = MyvehicleconService();

  @override
  MyVehicleState build() {
    return const MyVehicleState();
  }

  Future<void> loadVehicles(String collaboratorId) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isConnectionError: false,
      isServerError: false,
      isUnexpectedError: false,
    );

    try {
      final vehicleMaps =
          await _service.getVehiclesByCollaboratorId(collaboratorId);
      final list =
          vehicleMaps.map<Vehicle>((map) => Vehicle.fromMap(map)).toList();
      state = state.copyWith(
        isLoading: false,
        vehicles: list,
      );
    } on SocketException catch (_) {
      state = state.copyWith(isLoading: false, isConnectionError: true);
    } on TimeoutException catch (_) {
      state = state.copyWith(isLoading: false, isServerError: true);
    } catch (e) {
      debugPrint('Error al cargar vehículos: $e');
      state = state.copyWith(
        isLoading: false,
        isUnexpectedError: true,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh(String collaboratorId) async {
    await loadVehicles(collaboratorId);
  }

  Future<bool> updateVehiclePhoto({
    required dynamic vehicleId,
    required String filePath,
    required String collaboratorId,
  }) async {
    try {
      await _service.updateVehiclePhoto(vehicleId, filePath);
      await loadVehicles(collaboratorId);
      return true;
    } catch (e) {
      debugPrint('Error al actualizar foto del vehículo: $e');
      rethrow;
    }
  }
}

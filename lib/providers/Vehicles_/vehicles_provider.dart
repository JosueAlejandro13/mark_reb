import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/vehicle_model.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';

/// Estado inmutable para la pantalla de Vehículos Registrados (VehiclesPage)
class VehiclesState {
  final bool isLoading;
  final List<Vehicle> vehicles;
  final String? error;
  final bool isConnectionError;
  final bool isServerError;
  final bool isUnexpectedError;

  const VehiclesState({
    this.isLoading = true,
    this.vehicles = const [],
    this.error,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isUnexpectedError = false,
  });

  VehiclesState copyWith({
    bool? isLoading,
    List<Vehicle>? vehicles,
    String? error,
    bool clearError = false,
    bool? isConnectionError,
    bool? isServerError,
    bool? isUnexpectedError,
  }) {
    return VehiclesState(
      isLoading: isLoading ?? this.isLoading,
      vehicles: vehicles ?? this.vehicles,
      error: clearError ? null : (error ?? this.error),
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isUnexpectedError: isUnexpectedError ?? this.isUnexpectedError,
    );
  }
}

/// Provider global de Vehículos Registrados
final vehiclesProvider =
    NotifierProvider<VehiclesNotifier, VehiclesState>(VehiclesNotifier.new);

class VehiclesNotifier extends Notifier<VehiclesState> {
  final VehiclesconService _service = VehiclesconService();

  @override
  VehiclesState build() {
    return const VehiclesState();
  }

  bool _isNetworkError(Object e) {
    if (e is SocketException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('clientexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('software caused connection abort') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('no address associated with hostname');
  }

  Future<void> loadVehicles({
    required String userId,
    required String idMainAccount,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isConnectionError: false,
      isServerError: false,
      isUnexpectedError: false,
    );

    try {
      final List<Map<String, dynamic>> rawList =
          await _service.obtenerVehiculosPorUsuario(userId, idMainAccount);

      final vehicles =
          rawList.map<Vehicle>((map) => Vehicle.fromMap(map)).toList();

      state = state.copyWith(
        isLoading: false,
        vehicles: vehicles,
      );
    } on TimeoutException catch (_) {
      state = state.copyWith(isLoading: false, isServerError: true);
    } catch (e) {
      debugPrint('Error al cargar vehículos registrados: $e');
      if (_isNetworkError(e)) {
        state = state.copyWith(isLoading: false, isConnectionError: true);
      } else if (e.toString().contains('Error de servidor') ||
          e.toString().contains('500') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        state = state.copyWith(isLoading: false, isServerError: true);
      } else {
        state = state.copyWith(
          isLoading: false,
          isUnexpectedError: true,
          error: e.toString(),
        );
      }
    }
  }

  Future<void> refresh({
    required String userId,
    required String idMainAccount,
  }) async {
    await loadVehicles(userId: userId, idMainAccount: idMainAccount);
  }
}

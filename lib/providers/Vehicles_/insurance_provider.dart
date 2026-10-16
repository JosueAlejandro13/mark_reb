import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/insurance_model.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';

class InsuranceState {
  final List<InsuranceModel> insurances;
  final bool isLoading;
  final bool isConnectionError;
  final bool isServerError;
  final bool isUnexpectedError;

  InsuranceState({
    this.insurances = const [],
    this.isLoading = true,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isUnexpectedError = false,
  });

  InsuranceState copyWith({
    List<InsuranceModel>? insurances,
    bool? isLoading,
    bool? isConnectionError,
    bool? isServerError,
    bool? isUnexpectedError,
  }) {
    return InsuranceState(
      insurances: insurances ?? this.insurances,
      isLoading: isLoading ?? this.isLoading,
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isUnexpectedError: isUnexpectedError ?? this.isUnexpectedError,
    );
  }
}

class InsuranceNotifier extends Notifier<InsuranceState> {
  final VehiclesconService _dbService = VehiclesconService();

  @override
  InsuranceState build() {
    return InsuranceState();
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

  Future<void> fetchInsurances(String idVehic, String idUs) async {
    state = state.copyWith(
        isLoading: true,
        isConnectionError: false,
        isServerError: false,
        isUnexpectedError: false);
    try {
      final List<Map<String, dynamic>> rawData =
          await _dbService.obtenerSegurosPorVehiculo(idVehic, idUs);
      if (rawData.isNotEmpty) {
        final insurances =
            rawData.map((data) => InsuranceModel.fromMap(data)).toList();
        state = state.copyWith(insurances: insurances, isLoading: false);
      } else {
        state = state.copyWith(insurances: [], isLoading: false);
      }
    } on TimeoutException {
      state = state.copyWith(isLoading: false, isServerError: true);
    } catch (e) {
      debugPrint('Error en fetchInsurances: $e');
      if (_isNetworkError(e)) {
        state = state.copyWith(isLoading: false, isConnectionError: true);
      } else if (e.toString().contains('Error de servidor') ||
          e.toString().contains('500') ||
          e.toString().contains('502') ||
          e.toString().contains('503')) {
        state = state.copyWith(isLoading: false, isServerError: true);
      } else {
        state = state.copyWith(isLoading: false, isUnexpectedError: true);
      }
    }
  }

  void reset() {
    state = InsuranceState();
  }
}

final insuranceProvider =
    NotifierProvider<InsuranceNotifier, InsuranceState>(InsuranceNotifier.new);

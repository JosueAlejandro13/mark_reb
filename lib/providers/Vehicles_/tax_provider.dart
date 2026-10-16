import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/tax_model.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';

class TaxState {
  final bool isLoading;
  final bool isConnectionError;
  final bool isServerError;
  final bool isUnexpectedError;
  final List<TaxModel> taxes;

  TaxState({
    this.isLoading = true,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isUnexpectedError = false,
    this.taxes = const [],
  });

  TaxState copyWith({
    bool? isLoading,
    bool? isConnectionError,
    bool? isServerError,
    bool? isUnexpectedError,
    List<TaxModel>? taxes,
  }) {
    return TaxState(
      isLoading: isLoading ?? this.isLoading,
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isUnexpectedError: isUnexpectedError ?? this.isUnexpectedError,
      taxes: taxes ?? this.taxes,
    );
  }
}

class TaxNotifier extends Notifier<TaxState> {
  final VehiclesconService _dbService = VehiclesconService();

  @override
  TaxState build() {
    return TaxState();
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

  Future<void> loadTaxes({required String vehicleId, required String userId}) async {
    state = state.copyWith(
      isLoading: true,
      isConnectionError: false,
      isServerError: false,
      isUnexpectedError: false,
    );

    try {
      final data = await _dbService.obtenerImpuestosPorVehiculo(vehicleId, userId);
      final List<TaxModel> loadedTaxes = data.map((map) => TaxModel.fromMap(map)).toList();
      state = state.copyWith(
        isLoading: false,
        taxes: loadedTaxes,
      );
    } on TimeoutException {
      state = state.copyWith(isLoading: false, isServerError: true);
    } catch (e) {
      debugPrint('Error en loadTaxes: $e');
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
}

final taxProvider = NotifierProvider<TaxNotifier, TaxState>(TaxNotifier.new);

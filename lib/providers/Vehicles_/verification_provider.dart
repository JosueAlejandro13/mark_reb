import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/verification_model.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';

class VerificationState {
  final bool isLoading;
  final bool isConnectionError;
  final bool isServerError;
  final bool isUnexpectedError;
  final List<VerificationModel> verifications;

  VerificationState({
    this.isLoading = true,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isUnexpectedError = false,
    this.verifications = const [],
  });

  VerificationState copyWith({
    bool? isLoading,
    bool? isConnectionError,
    bool? isServerError,
    bool? isUnexpectedError,
    List<VerificationModel>? verifications,
  }) {
    return VerificationState(
      isLoading: isLoading ?? this.isLoading,
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isUnexpectedError: isUnexpectedError ?? this.isUnexpectedError,
      verifications: verifications ?? this.verifications,
    );
  }
}

class VerificationNotifier extends Notifier<VerificationState> {
  final VehiclesconService _dbService = VehiclesconService();

  @override
  VerificationState build() {
    return VerificationState();
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

  Future<void> loadVerifications({required String vehicleId, required String userId}) async {
    state = state.copyWith(
      isLoading: true,
      isConnectionError: false,
      isServerError: false,
      isUnexpectedError: false,
    );

    try {
      final data = await _dbService.obtenerVerificacionesPorVehiculo(vehicleId, userId);
      final List<VerificationModel> loadedData = data.map((map) => VerificationModel.fromMap(map)).toList();
      state = state.copyWith(
        isLoading: false,
        verifications: loadedData,
      );
    } on TimeoutException {
      state = state.copyWith(isLoading: false, isServerError: true);
    } catch (e) {
      debugPrint('Error en loadVerifications: $e');
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

final verificationProvider = NotifierProvider<VerificationNotifier, VerificationState>(VerificationNotifier.new);

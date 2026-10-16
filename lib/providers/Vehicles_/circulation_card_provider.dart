import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/circulation_card_model.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';

class CirculationCardState {
  final List<CirculationCardModel> cards;
  final bool isLoading;
  final bool isConnectionError;
  final bool isServerError;
  final bool isUnexpectedError;

  CirculationCardState({
    this.cards = const [],
    this.isLoading = true,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isUnexpectedError = false,
  });

  CirculationCardState copyWith({
    List<CirculationCardModel>? cards,
    bool? isLoading,
    bool? isConnectionError,
    bool? isServerError,
    bool? isUnexpectedError,
  }) {
    return CirculationCardState(
      cards: cards ?? this.cards,
      isLoading: isLoading ?? this.isLoading,
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isUnexpectedError: isUnexpectedError ?? this.isUnexpectedError,
    );
  }
}

class CirculationCardNotifier extends Notifier<CirculationCardState> {
  final VehiclesconService _dbService = VehiclesconService();

  @override
  CirculationCardState build() {
    return CirculationCardState();
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

  Future<void> fetchCards(String idVehic, String idUs) async {
    state = state.copyWith(isLoading: true, isConnectionError: false, isServerError: false, isUnexpectedError: false);
    try {
      final dynamic rawData = await _dbService.obtenerTarjetaCirculacion(idVehic, idUs);
      if (rawData != null) {
        if (rawData is Map<String, dynamic> && rawData.isNotEmpty) {
           final card = CirculationCardModel.fromMap(rawData);
           state = state.copyWith(cards: [card], isLoading: false);
        } else {
           state = state.copyWith(cards: [], isLoading: false);
        }
      } else {
        state = state.copyWith(cards: [], isLoading: false);
      }
    } on TimeoutException {
      state = state.copyWith(isLoading: false, isServerError: true);
    } catch (e) {
      debugPrint('Error en fetchCards: $e');
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
    state = CirculationCardState();
  }
}

final circulationCardProvider = NotifierProvider<CirculationCardNotifier, CirculationCardState>(
  CirculationCardNotifier.new,
);

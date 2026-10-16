import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Credit_/credit_model.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';

class CreditState {
  final List<CreditModel> credits;
  final String payDate;
  final bool isLoading;
  final bool isConnectionError;
  final bool isServerError;
  final bool isUnexpectedError;

  CreditState({
    this.credits = const [],
    this.payDate = '',
    this.isLoading = true,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isUnexpectedError = false,
  });

  CreditState copyWith({
    List<CreditModel>? credits,
    String? payDate,
    bool? isLoading,
    bool? isConnectionError,
    bool? isServerError,
    bool? isUnexpectedError,
  }) {
    return CreditState(
      credits: credits ?? this.credits,
      payDate: payDate ?? this.payDate,
      isLoading: isLoading ?? this.isLoading,
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isUnexpectedError: isUnexpectedError ?? this.isUnexpectedError,
    );
  }
}

class CreditNotifier extends Notifier<CreditState> {
  final VehiclesconService _dbService = VehiclesconService();

  @override
  CreditState build() {
    return CreditState();
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

  Future<void> fetchCredits(String idVehic, String idUs) async {
    state = state.copyWith(
        isLoading: true,
        isConnectionError: false,
        isServerError: false,
        isUnexpectedError: false);
    try {
      final List<Map<String, dynamic>> rawData =
          await _dbService.getCreditos(idUs, idVehic);
          
      if (rawData.isNotEmpty) {
        final credits =
            rawData.map((data) => CreditModel.fromMap(data)).toList();
        
        String payDate = '';
        final creditoId = credits.first.id.toString();
        if (creditoId != '0') {
           try {
             final nextPay = await _dbService.getNextPaymentDate(creditoId);
             payDate = nextPay['fecExpi']?.toString() ?? '';
           } catch (e) {
             // Ignoramos error de fecha
           }
        }
        
        state = state.copyWith(credits: credits, payDate: payDate, isLoading: false);
      } else {
        state = state.copyWith(credits: [], payDate: '', isLoading: false);
      }
    } on TimeoutException {
      state = state.copyWith(isLoading: false, isServerError: true);
    } catch (e) {
      debugPrint('Error en fetchCredits: $e');
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
    state = CreditState();
  }
}

final creditProvider =
    NotifierProvider<CreditNotifier, CreditState>(CreditNotifier.new);

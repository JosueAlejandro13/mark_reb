import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Credit_/credit_payment_model.dart';
import 'package:mark_v3/services/ConnectionVehicles_/VehiclesCon_service.dart';

class PayCreditState {
  final List<CreditPaymentModel> payments;
  final double totalPagado;
  final bool isLoading;
  final bool isConnectionError;
  final bool isServerError;
  final bool isUnexpectedError;

  PayCreditState({
    this.payments = const [],
    this.totalPagado = 0.0,
    this.isLoading = true,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isUnexpectedError = false,
  });

  PayCreditState copyWith({
    List<CreditPaymentModel>? payments,
    double? totalPagado,
    bool? isLoading,
    bool? isConnectionError,
    bool? isServerError,
    bool? isUnexpectedError,
  }) {
    return PayCreditState(
      payments: payments ?? this.payments,
      totalPagado: totalPagado ?? this.totalPagado,
      isLoading: isLoading ?? this.isLoading,
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isUnexpectedError: isUnexpectedError ?? this.isUnexpectedError,
    );
  }
}

class PayCreditNotifier extends Notifier<PayCreditState> {
  final VehiclesconService _dbService = VehiclesconService();

  @override
  PayCreditState build() {
    return PayCreditState();
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

  Future<void> fetchPaymentHistory(String creditoId) async {
    state = state.copyWith(
        isLoading: true,
        isConnectionError: false,
        isServerError: false,
        isUnexpectedError: false);
    try {
      final List<Map<String, dynamic>> rawData =
          await _dbService.getPaymentHistory(creditoId);
          
      if (rawData.isNotEmpty) {
        final payments =
            rawData.map((data) => CreditPaymentModel.fromMap(data)).toList();
        
        double totalPagado = 0.0;
        for (var p in payments) {
          totalPagado += double.tryParse(p.monto) ?? 0.0;
        }
        
        state = state.copyWith(payments: payments, totalPagado: totalPagado, isLoading: false);
      } else {
        state = state.copyWith(payments: [], totalPagado: 0.0, isLoading: false);
      }
    } on TimeoutException {
      state = state.copyWith(isLoading: false, isServerError: true);
    } catch (e) {
      debugPrint('Error en fetchPaymentHistory: $e');
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
    state = PayCreditState();
  }
}

final payCreditProvider =
    NotifierProvider<PayCreditNotifier, PayCreditState>(PayCreditNotifier.new);

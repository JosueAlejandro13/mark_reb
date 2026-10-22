import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mark_v3/models/Vehicles_/vehicle_model.dart';
import 'package:mark_v3/services/ConnectionInspeccion_/InspeccionCon_service.dart';

// Modelo inmutable para cada ítem de plantilla con su estado de periodicidad calculado
class PlantillaItem {
  final Map<String, dynamic> raw;
  final int daysRemaining;
  final bool isReady;

  PlantillaItem({
    required this.raw,
    required this.daysRemaining,
    required this.isReady,
  });

  String get id => raw['id']?.toString() ?? '';
  String get name => raw['name']?.toString() ?? 'Sin nombre';
  String get description => raw['decription']?.toString() ?? 'Sin descripción';
  int get enableStorePhoto => raw['enableStorePhoto'] ?? 0;
  int get periodicity => raw['periodicity'] ?? 0;
}

// Estado inmutable de la selección de plantillas
class TemplateSelectionState {
  final bool isLoading;
  final List<PlantillaItem> plantillas;
  final bool isConnectionError;
  final bool isServerError;
  final bool isInspError;
  final String? error;

  const TemplateSelectionState({
    this.isLoading = true,
    this.plantillas = const [],
    this.isConnectionError = false,
    this.isServerError = false,
    this.isInspError = false,
    this.error,
  });

  TemplateSelectionState copyWith({
    bool? isLoading,
    List<PlantillaItem>? plantillas,
    bool? isConnectionError,
    bool? isServerError,
    bool? isInspError,
    String? error,
  }) {
    return TemplateSelectionState(
      isLoading: isLoading ?? this.isLoading,
      plantillas: plantillas ?? this.plantillas,
      isConnectionError: isConnectionError ?? this.isConnectionError,
      isServerError: isServerError ?? this.isServerError,
      isInspError: isInspError ?? this.isInspError,
      error: error ?? this.error,
    );
  }
}

// Provider global de Selección de Plantillas
final templateSelectionProvider = NotifierProvider<
    TemplateSelectionNotifier,
    TemplateSelectionState>(TemplateSelectionNotifier.new);

class TemplateSelectionNotifier extends Notifier<TemplateSelectionState> {
  final InspeccionconService _service = InspeccionconService();

  @override
  TemplateSelectionState build() {
    return const TemplateSelectionState();
  }

  Future<void> loadTemplates({
    required String idMainAccount,
    required Vehicle vehicle,
  }) async {
    state = state.copyWith(
      isLoading: true,
      isConnectionError: false,
      isServerError: false,
      isInspError: false,
    );

    try {
      final vehicleIdInt = int.tryParse(vehicle.id) ?? 0;
      final rawPlantillas = await _service.obtenerPlantillasPorUsuarioYVehiculo(
        idMainAccount,
        vehicleIdInt,
      );

      if (rawPlantillas.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          isInspError: true,
          plantillas: [],
        );
        return;
      }

      final List<PlantillaItem> items = [];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final p in rawPlantillas) {
        int daysRemaining = 0;
        bool isReady = true;

        // Ronda 144: Verificación directa con banderas del servidor
        if (p['puedeHoy'] != null || p['hoyHecha'] != null) {
          final puedeHoy = p['puedeHoy'] == true;
          final hoyHecha = p['hoyHecha'] == true;
          if (!puedeHoy || hoyHecha) {
            isReady = false;
            daysRemaining = 1;
          } else {
            isReady = true;
            daysRemaining = 0;
          }
        } else {
          try {
            final lastInspection = await _service.obtenerUltimaInspeccion(
              vehicle.id,
              p['id'].toString(),
              idMainAccount,
            );

            if (lastInspection != null && lastInspection['endDate'] != null) {
              DateTime? lastDate;
              final rawDate = lastInspection['endDate'];
              if (rawDate is DateTime) {
                lastDate = rawDate;
              } else {
                lastDate = DateTime.tryParse(rawDate.toString());
              }

              if (lastDate != null) {
                final int periodicity = p['periodicity'] is int
                    ? p['periodicity']
                    : (lastInspection['periodicity'] is int
                        ? lastInspection['periodicity']
                        : 1);

                final lastDay =
                    DateTime(lastDate.year, lastDate.month, lastDate.day);

                if (periodicity <= 1) {
                  // Periodicidad diaria (preoperativa): Si ya se hizo hoy o fecha futura
                  if (today.isAtSameMomentAs(lastDay) || today.isBefore(lastDay)) {
                    isReady = false;
                    daysRemaining = 1;
                  } else {
                    isReady = true;
                    daysRemaining = 0;
                  }
                } else {
                  // Periodicidad mayor a 1 día
                  final nextAllowedDate =
                      lastDay.add(Duration(days: periodicity));
                  final diffDays = nextAllowedDate.difference(today).inDays;
                  if (diffDays > 0) {
                    isReady = false;
                    daysRemaining = diffDays;
                  } else {
                    isReady = true;
                    daysRemaining = 0;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error calculando periodicidad para plantilla ${p['id']}: $e');
          }
        }

        items.add(PlantillaItem(
          raw: p,
          daysRemaining: daysRemaining,
          isReady: isReady,
        ));
      }

      state = state.copyWith(
        isLoading: false,
        plantillas: items,
      );
    } on SocketException catch (_) {
      state = state.copyWith(isLoading: false, isConnectionError: true);
    } on TimeoutException catch (_) {
      state = state.copyWith(isLoading: false, isServerError: true);
    } catch (e) {
      debugPrint('Error inesperado al cargar plantillas: $e');
      state = state.copyWith(
        isLoading: false,
        isInspError: true,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh({
    required String idMainAccount,
    required Vehicle vehicle,
  }) async {
    await loadTemplates(idMainAccount: idMainAccount, vehicle: vehicle);
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mark_v3/services/ConnectionStation_/StationCon_service.dart';
import 'package:mark_v3/services/mark_api_client.dart';

// Autor: Josue Hernandez - Migrado a Riverpod
class ServiceStationState {
  final bool isLoading;
  final bool isSubmitting;
  final bool isOutOfRange;
  final bool isLocationDisabled;
  final bool isPermissionDenied;
  final bool isConnectionError;
  final bool isServerError;
  final bool isUnexpectedError;
  final String? errorMessage;
  final String? successMessage;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? stationData;
  final Map<String, dynamic>? vehicleConfig;
  final List<Map<String, dynamic>> fuelTypes;
  final String? selectedFuelTypeId;
  final String? selectedFuelTypeName;
  final double? selectedFuelPrice;
  final bool isFuelValid;
  final int liters;
  final double totalEstimated;

  const ServiceStationState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.isOutOfRange = false,
    this.isLocationDisabled = false,
    this.isPermissionDenied = false,
    this.isConnectionError = false,
    this.isServerError = false,
    this.isUnexpectedError = false,
    this.errorMessage,
    this.successMessage,
    this.latitude,
    this.longitude,
    this.stationData,
    this.vehicleConfig,
    this.fuelTypes = const [],
    this.selectedFuelTypeId,
    this.selectedFuelTypeName,
    this.selectedFuelPrice,
    this.isFuelValid = true,
    this.liters = 0,
    this.totalEstimated = 0.0,
  });

  ServiceStationState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    bool? isOutOfRange,
    bool? isLocationDisabled,
    bool? isPermissionDenied,
    bool? isConnectionError,
    bool? isServerError,
    bool? isUnexpectedError,
    String? errorMessage,
    String? successMessage,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? stationData,
    Map<String, dynamic>? vehicleConfig,
    List<Map<String, dynamic>>? fuelTypes,
    String? selectedFuelTypeId,
    String? selectedFuelTypeName,
    double? selectedFuelPrice,
    bool? isFuelValid,
    int? liters,
    double? totalEstimated,
    bool clearErrors = false,
    bool clearStation = false,
  }) {
    return ServiceStationState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isOutOfRange: isOutOfRange ?? this.isOutOfRange,
      isLocationDisabled: isLocationDisabled ?? this.isLocationDisabled,
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
      isConnectionError:
          clearErrors ? false : (isConnectionError ?? this.isConnectionError),
      isServerError:
          clearErrors ? false : (isServerError ?? this.isServerError),
      isUnexpectedError:
          clearErrors ? false : (isUnexpectedError ?? this.isUnexpectedError),
      errorMessage: clearErrors ? null : (errorMessage ?? this.errorMessage),
      successMessage: successMessage ?? this.successMessage,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      stationData: clearStation ? null : (stationData ?? this.stationData),
      vehicleConfig: vehicleConfig ?? this.vehicleConfig,
      fuelTypes: fuelTypes ?? this.fuelTypes,
      selectedFuelTypeId: selectedFuelTypeId ?? this.selectedFuelTypeId,
      selectedFuelTypeName: selectedFuelTypeName ?? this.selectedFuelTypeName,
      selectedFuelPrice: selectedFuelPrice ?? this.selectedFuelPrice,
      isFuelValid: isFuelValid ?? this.isFuelValid,
      liters: liters ?? this.liters,
      totalEstimated: totalEstimated ?? this.totalEstimated,
    );
  }
}

final serviceStationProvider =
    NotifierProvider<ServiceStationNotifier, ServiceStationState>(
        ServiceStationNotifier.new);

class ServiceStationNotifier extends Notifier<ServiceStationState> {
  final StationService _stationService = StationService();

  static const List<List<int>> _allowedFuelCombinations = [
    [3, 4], // Diesel
    [8, 9, 6, 7], // Premium / Regular
  ];

  @override
  ServiceStationState build() {
    return const ServiceStationState();
  }

  Future<void> initializeData({
    required String idCollaborator,
    required String idMainAccount,
  }) async {
    state = state.copyWith(
      isLoading: true,
      isOutOfRange: false,
      isLocationDisabled: false,
      isPermissionDenied: false,
      clearErrors: true,
      clearStation: false,
    );

    try {
      // 1. Obtener vehículos asignados y catálogo de tipos de combustible en paralelo
      final resupplyFuture = _stationService.getresupply(idCollaborator);
      final fuelTypesFuture = _stationService.getTypeFuel();

      final results = await Future.wait([
        resupplyFuture,
        fuelTypesFuture,
      ]);

      final configList = results[0];
      final rawFuelTypes = results[1];

      final fuelTypes = rawFuelTypes
          .where((f) => f['id'] != null && f['name'] != null)
          .toList();

      final vehicleConfig = configList.isNotEmpty ? configList.first : null;

      if (vehicleConfig == null) {
        state = state.copyWith(
          isLoading: false,
          isOutOfRange: true,
          errorMessage:
              'No se encontró vehículo asignado para este colaborador.',
          fuelTypes: fuelTypes,
        );
        return;
      }

      // 2. Extraer posición GPS del VEHÍCULO (no del celular)
      double? vehicleLat;
      double? vehicleLng;

      if (vehicleConfig['lat'] != null) {
        vehicleLat = double.tryParse(vehicleConfig['lat'].toString());
      }
      if (vehicleConfig['lng'] != null) {
        vehicleLng = double.tryParse(vehicleConfig['lng'].toString());
      }

      debugPrint(
        '📍 GPS del Vehículo (${vehicleConfig['economic'] ?? vehicleConfig['id']}): $vehicleLat, $vehicleLng',
      );

      // Si el vehículo no tiene reporte GPS válido, intentar obtener ubicación del teléfono como respaldo
      // (según Guía de Integración Mark V3.1: "Usa la posición del teléfono; si no la hay, la del vehículo.")
      if (vehicleLat == null ||
          vehicleLng == null ||
          (vehicleLat == 0.0 && vehicleLng == 0.0)) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 4),
          );
          vehicleLat = pos.latitude;
          vehicleLng = pos.longitude;
          debugPrint(
              '📍 Respaldo GPS del teléfono para combustible: $vehicleLat, $vehicleLng');
        } catch (e) {
          debugPrint(
              'Aviso: no se pudo obtener GPS del teléfono de respaldo: $e');
        }
      }

      // Coordenadas seguras para consulta y registro
      vehicleLat ??= 19.4326;
      vehicleLng ??= -99.1332;

      // 3. Buscar estación cercana usando la posición GPS del VEHÍCULO (o teléfono)
      final stationData = await _stationService.buscarEstacionCercanaConPrecio(
        vehicleLat,
        vehicleLng,
      );

      if (stationData == null) {
        state = state.copyWith(
          isLoading: false,
          latitude: vehicleLat,
          longitude: vehicleLng,
          isOutOfRange: true,
          vehicleConfig: vehicleConfig,
          fuelTypes: fuelTypes,
        );
        return;
      }

      // Parsear datos de la estación de forma segura
      final cleanStation = Map<String, dynamic>.from(stationData);

      // Determinar combustible inicial
      String? initialFuelTypeId;
      String? initialFuelTypeName;
      double? initialFuelPrice;

      if (vehicleConfig != null &&
          vehicleConfig['tipoCombustibleNombre'] != null) {
        final assignedName =
            vehicleConfig['tipoCombustibleNombre'].toString().toLowerCase();
        final match = fuelTypes.where((f) {
          final fname = f['name'].toString().toLowerCase();
          return fname.contains(assignedName) || assignedName.contains(fname);
        });
        if (match.isNotEmpty) {
          initialFuelTypeId = match.first['id'].toString();
          initialFuelTypeName = match.first['name'].toString();
          vehicleConfig['idtipoCombustibleNombre'] = match.first['id'];
        }
      }

      if (initialFuelTypeId == null && fuelTypes.isNotEmpty) {
        initialFuelTypeId = fuelTypes.first['id'].toString();
        initialFuelTypeName = fuelTypes.first['name'].toString();
      }

      if (initialFuelTypeId != null) {
        initialFuelPrice = _calculatePriceForType(
          int.tryParse(initialFuelTypeId) ?? 0,
          cleanStation,
        );
      }

      final int initialLiters = state.liters > 0 ? state.liters : 0;
      final double initialTotal = initialLiters * (initialFuelPrice ?? 0.0);

      state = state.copyWith(
        isLoading: false,
        latitude: vehicleLat,
        longitude: vehicleLng,
        stationData: cleanStation,
        vehicleConfig: vehicleConfig,
        fuelTypes: fuelTypes,
        selectedFuelTypeId: initialFuelTypeId,
        selectedFuelTypeName: initialFuelTypeName,
        selectedFuelPrice: initialFuelPrice,
        isFuelValid: true,
        liters: initialLiters,
        totalEstimated: initialTotal,
      );
    } on SocketException catch (e) {
      debugPrint('ServiceStation SocketException: $e');
      state = state.copyWith(isLoading: false, isConnectionError: true);
    } on TimeoutException catch (e) {
      debugPrint('ServiceStation TimeoutException: $e');
      state = state.copyWith(isLoading: false, isServerError: true);
    } catch (e) {
      debugPrint('ServiceStation Error inesperado: $e');
      if (e.toString().contains('SocketException')) {
        state = state.copyWith(isLoading: false, isConnectionError: true);
      } else if (e.toString().contains('TimeoutException')) {
        state = state.copyWith(isLoading: false, isServerError: true);
      } else {
        state = state.copyWith(
          isLoading: false,
          isUnexpectedError: true,
          errorMessage: e.toString(),
        );
      }
    }
  }

  double? _calculatePriceForType(
      int fuelTypeId, Map<String, dynamic>? station) {
    if (station == null) return null;

    if (fuelTypeId == 3 || fuelTypeId == 4) {
      return station['diesel'] != null
          ? double.tryParse(station['diesel'].toString())
          : null;
    } else if (fuelTypeId == 6 || fuelTypeId == 7) {
      return station['regular'] != null
          ? double.tryParse(station['regular'].toString())
          : null;
    } else if (fuelTypeId == 8 || fuelTypeId == 9) {
      return station['premium'] != null
          ? double.tryParse(station['premium'].toString())
          : null;
    }
    return null;
  }

  bool _checkFuelCompatibility(int selectedFuel, int? vehicleAssignedFuel) {
    if (vehicleAssignedFuel == null) return true;

    for (var combination in _allowedFuelCombinations) {
      if (combination.contains(selectedFuel) &&
          combination.contains(vehicleAssignedFuel)) {
        return true;
      }
    }
    return false;
  }

  void onFuelTypeChanged(String? newFuelTypeId) {
    if (newFuelTypeId == null) return;
    final int selectedFuelInt = int.tryParse(newFuelTypeId) ?? 0;

    int? assignedFuelInt;
    if (state.vehicleConfig != null &&
        state.vehicleConfig!['idtipoCombustibleNombre'] != null) {
      assignedFuelInt = int.tryParse(
          state.vehicleConfig!['idtipoCombustibleNombre'].toString());
    }

    final bool isValid =
        _checkFuelCompatibility(selectedFuelInt, assignedFuelInt);

    final selectedFuelName = state.fuelTypes.firstWhere(
      (f) => f['id'].toString() == newFuelTypeId,
      orElse: () => {'name': ''},
    )['name'];

    final double? price =
        _calculatePriceForType(selectedFuelInt, state.stationData);

    final double total = state.liters * (price ?? 0.0);

    state = state.copyWith(
      selectedFuelTypeId: newFuelTypeId,
      selectedFuelTypeName: selectedFuelName,
      selectedFuelPrice: price,
      isFuelValid: isValid,
      totalEstimated: total,
    );
  }

  void onLitersChanged(int liters) {
    final double price = state.selectedFuelPrice ?? 0.0;
    state = state.copyWith(
      liters: liters,
      totalEstimated: liters * price,
    );
  }

  Future<bool> submitRefuel({
    required String idMainAccount,
    required String idCollaborator,
    required int liters,
  }) async {
    final session = MarkApiClient.instance.currentSession;
    final rol = session?.rol.toLowerCase().trim() ?? '';
    final isPreventa =
        session?.isPreventa == true || rol == 'preventa' || rol == 'vendedor';

    if (isPreventa) {
      state = state.copyWith(
        errorMessage:
            'Tu perfil de preventa no cuenta con autorización para registrar reabastecimientos de combustible.',
      );
      return false;
    }

    if (state.stationData == null || state.vehicleConfig == null) {
      state = state.copyWith(
        errorMessage: 'Faltan datos de la estación o del vehículo.',
      );
      return false;
    }

    if (!state.isFuelValid) {
      state = state.copyWith(
        errorMessage: 'El combustible seleccionado no es compatible.',
      );
      return false;
    }

    if (liters <= 0) {
      state = state.copyWith(
        errorMessage: 'Ingresa una cantidad de litros válida.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearErrors: true);

    try {
      final int idVehic = state.vehicleConfig!['idVehic'] ??
          state.vehicleConfig!['idvehic'] ??
          state.vehicleConfig!['id'] ??
          0;
      final String odom = state.vehicleConfig!['odom']?.toString() ??
          state.vehicleConfig!['odometer']?.toString() ??
          '0';
      final String stationCode = state.stationData!['codeES']?.toString() ??
          state.stationData!['code']?.toString() ??
          '';
      final String typFuel = state.selectedFuelTypeId ?? '6';

      DateTime datePrice = DateTime.now();
      if (state.stationData!['fecha'] != null) {
        final parsed =
            DateTime.tryParse(state.stationData!['fecha'].toString());
        if (parsed != null) datePrice = parsed;
      }

      final String priceLts = state.selectedFuelPrice != null
          ? state.selectedFuelPrice.toString()
          : '0.0';

      final bool success = await _stationService.EstacionesDeServicio(
        id: 0,
        idUs: int.tryParse(idMainAccount) ?? 0,
        idSubAcco: int.tryParse(idCollaborator) ?? 0,
        idVehic: idVehic,
        odom: odom,
        codeES: stationCode,
        typFuel: typFuel,
        datePrice: datePrice.toUtc(),
        priceLts: priceLts,
        lts: liters,
        dateCreated: DateTime.now(),
        lat: state.latitude,
        lng: state.longitude,
      );

      state = state.copyWith(isSubmitting: false);
      return success;
    } catch (e) {
      debugPrint('Error en submitRefuel: $e');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Error al registrar el reabastecimiento: $e',
      );
      return false;
    }
  }
}

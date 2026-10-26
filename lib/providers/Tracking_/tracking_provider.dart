import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mark_v3/services/ConnectionTracking_/TrackingCon_service.dart';

// Autor: Josue Hernandez - Migrado a Riverpod
class TrackingState {
  final List<Map<String, dynamic>> devices;
  final String? selectedVehicleId;
  final bool isLoading;
  final bool isUpdating;
  final bool hasError;
  final String? errorMessage;
  final Map<String, String> deviceTimeElapsed;
  final MapType mapType;
  final bool showTraffic;
  final String searchQuery;
  final String statusFilter; // 'all', 'moving', 'stopped'

  const TrackingState({
    this.devices = const [],
    this.selectedVehicleId,
    this.isLoading = true,
    this.isUpdating = false,
    this.hasError = false,
    this.errorMessage,
    this.deviceTimeElapsed = const {},
    this.mapType = MapType.normal,
    this.showTraffic = false,
    this.searchQuery = '',
    this.statusFilter = 'all',
  });

  Map<String, dynamic>? get selectedVehicle {
    if (selectedVehicleId == null || devices.isEmpty) return null;
    try {
      return devices.firstWhere((d) => d['id'].toString() == selectedVehicleId);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get filteredDevices {
    return devices.where((device) {
      final name = (device['economico'] ?? '').toString().toLowerCase();
      final plate = (device['placas'] ?? '').toString().toLowerCase();
      final make = (device['make'] ?? '').toString().toLowerCase();
      final model = (device['model'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase().trim();

      final matchesSearch =
          query.isEmpty ||
          name.contains(query) ||
          plate.contains(query) ||
          make.contains(query) ||
          model.contains(query);

      if (!matchesSearch) return false;

      final isIgnitionOn = (device['ignStatus'] ?? 0) == 1;
      if (statusFilter == 'moving') return isIgnitionOn;
      if (statusFilter == 'stopped') return !isIgnitionOn;

      return true;
    }).toList();
  }

  int get movingCount =>
      devices.where((d) => (d['ignStatus'] ?? 0) == 1).length;

  int get stoppedCount =>
      devices.where((d) => (d['ignStatus'] ?? 0) != 1).length;

  TrackingState copyWith({
    List<Map<String, dynamic>>? devices,
    String? selectedVehicleId,
    bool clearSelectedVehicle = false,
    bool? isLoading,
    bool? isUpdating,
    bool? hasError,
    String? errorMessage,
    Map<String, String>? deviceTimeElapsed,
    MapType? mapType,
    bool? showTraffic,
    String? searchQuery,
    String? statusFilter,
  }) {
    return TrackingState(
      devices: devices ?? this.devices,
      selectedVehicleId: clearSelectedVehicle
          ? null
          : (selectedVehicleId ?? this.selectedVehicleId),
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage,
      deviceTimeElapsed: deviceTimeElapsed ?? this.deviceTimeElapsed,
      mapType: mapType ?? this.mapType,
      showTraffic: showTraffic ?? this.showTraffic,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

final trackingProvider =
    NotifierProvider.autoDispose<TrackingNotifier, TrackingState>(
      TrackingNotifier.new,
    );

class TrackingNotifier extends Notifier<TrackingState> {
  final TrackingconService _dbService = TrackingconService();
  Timer? _pollingTimer;

  @override
  TrackingState build() {
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });
    return const TrackingState();
  }

  Future<void> loadDevices(String userId, {bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(
        isLoading: true,
        hasError: false,
        errorMessage: null,
      );
    }

    try {
      final tracking = await _dbService.getDevicesBySubAccount(userId);

      if (tracking.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          devices: [],
          hasError: true,
          errorMessage:
              'No se encontraron vehículos disponibles en esta cuenta.',
        );
        return;
      }

      final Map<String, String> timeMap = {};
      for (final device in tracking) {
        final idStr = device['id'].toString();
        timeMap[idStr] = _calculateDeviceTimeElapsed(device);
      }

      state = state.copyWith(
        isLoading: false,
        hasError: false,
        devices: tracking,
        deviceTimeElapsed: timeMap,
      );

      // Iniciar polling periódico para actualización en vivo
      startPolling(userId);
    } catch (e) {
      debugPrint('Error en loadDevices: $e');
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: 'Error al conectar con el servidor: $e',
      );
    }
  }

  void startPolling(String userId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _pollUpdates(userId);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _pollUpdates(String userId) async {
    // Si no hay un vehículo seleccionado, NO consultamos la base de datos automáticamente
    // para no saturar el servidor con consultas masivas de toda la flota
    if (state.selectedVehicleId == null ||
        state.isUpdating ||
        state.devices.isEmpty) {
      return;
    }

    try {
      final trackingData = await _dbService.obtenerTracking(
        state.selectedVehicleId!,
      );
      if (trackingData.isNotEmpty) {
        final updated = trackingData.first;
        final updatedLat = updated['lat'];
        final updatedLng = updated['lng'];
        final bool hasValidCoords = updatedLat != null &&
            updatedLng != null &&
            updatedLat.toString() != '0' &&
            updatedLng.toString() != '0' &&
            updatedLat.toString() != '0.0' &&
            updatedLng.toString() != '0.0';

        final updatedDevices = state.devices.map((d) {
          if (d['id'].toString() == state.selectedVehicleId) {
            return {
              ...d,
              if (hasValidCoords) 'lat': updatedLat,
              if (hasValidCoords) 'lng': updatedLng,
              'ignStatus': updated['ignStatus'] ?? d['ignStatus'],
              'driveStat': updated['driveStat'] ?? d['driveStat'],
              'dir': updated['dir'] ?? d['dir'],
              'rumbo': updated['rumbo'] ?? d['rumbo'],
              'course': updated['course'] ?? d['course'],
              'speed': updated['speed'] ?? d['speed'],
              'velocidad': updated['velocidad'] ?? d['velocidad'],
              'batc': updated['batc'] ?? d['batc'],
              'bateria': updated['bateria'] ?? d['bateria'],
              'bath': updated['bath'] ?? d['bath'],
              'timApagado': updated['timApagado'] ?? d['timApagado'],
            };
          }
          return d;
        }).toList();

        final updatedTimeMap = Map<String, String>.from(
          state.deviceTimeElapsed,
        );
        updatedTimeMap[state.selectedVehicleId!] = _calculateDeviceTimeElapsed(
          updated,
        );

        state = state.copyWith(
          devices: updatedDevices,
          deviceTimeElapsed: updatedTimeMap,
        );
      }
    } catch (e) {
      debugPrint('Error durante actualización periódica del vehículo: $e');
    }
  }

  Future<void> refreshSelectedVehicle(String userId) async {
    if (state.selectedVehicleId != null) {
      await _pollUpdates(userId);
    } else {
      await loadDevices(userId, showLoading: false);
    }
  }

  void selectVehicle(String? vehicleId, {String? userId}) {
    state = state.copyWith(
      selectedVehicleId: vehicleId,
      clearSelectedVehicle: vehicleId == null,
    );
    if (vehicleId != null) {
      _pollUpdates(userId ?? '');
    }
  }

  void toggleMapType() {
    final nextType = switch (state.mapType) {
      MapType.normal => MapType.hybrid,
      MapType.hybrid => MapType.terrain,
      _ => MapType.normal,
    };
    state = state.copyWith(mapType: nextType);
  }

  void toggleTraffic() {
    state = state.copyWith(showTraffic: !state.showTraffic);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String filter) {
    state = state.copyWith(statusFilter: filter);
  }

  String _calculateDeviceTimeElapsed(Map<String, dynamic> device) {
    final lastUpdate =
        int.tryParse(device['timApagado']?.toString() ?? '0') ?? 0;
    final offsetLocalHours =
        int.tryParse(device['timOper']?.toString() ?? '0') ?? 0;

    if (lastUpdate <= 0) {
      final fechaRaw =
          device['fechaHora'] ?? device['fecha'] ?? device['lastUpdate'];
      if (fechaRaw != null && fechaRaw.toString().isNotEmpty) {
        try {
          final dt = DateTime.tryParse(fechaRaw.toString());
          if (dt != null) {
            final diff = DateTime.now().difference(dt);
            if (diff.isNegative || diff.inMinutes < 2) return 'En línea';
            if (diff.inDays > 0) return '${diff.inDays} d';
            if (diff.inHours > 0) return '${diff.inHours} h ${diff.inMinutes % 60} min';
            return '${diff.inMinutes} min';
          }
        } catch (_) {}
      }
      return 'Reciente';
    }

    try {
      final nowUtc = DateTime.now().toUtc();
      final nowUtcRounded = DateTime(
        nowUtc.year,
        nowUtc.month,
        nowUtc.day,
        nowUtc.hour,
        nowUtc.minute,
        nowUtc.second,
      );

      final utcDateTime = DateTime.fromMillisecondsSinceEpoch(
        lastUpdate * 1000,
        isUtc: true,
      );
      final nowLocal = nowUtcRounded.add(Duration(hours: offsetLocalHours));
      final utcDateTimeLocal = utcDateTime.add(
        Duration(hours: offsetLocalHours),
      );
      final diff = nowLocal.difference(utcDateTimeLocal);

      if (diff.isNegative) return 'En línea';

      final dias = diff.inDays;
      final horas = diff.inHours % 24;
      final minutos = diff.inMinutes % 60;

      if (dias > 0) return '$dias d $horas h';
      if (horas > 0) return '$horas h $minutos min';
      if (minutos > 0) return '$minutos min';
      return 'Hace un momento';
    } catch (_) {
      return 'Sin registro';
    }
  }
}

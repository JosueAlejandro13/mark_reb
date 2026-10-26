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
  int _siguienteSeg = 10; // Ronda 156: cada 10 s y no cada 2
  bool _isPollingPaused = false;
  String _currentUserId = '';

  @override
  TrackingState build() {
    ref.onDispose(() {
      stopPolling();
    });
    return const TrackingState();
  }

  Future<void> loadDevices(String userId, {bool showLoading = true}) async {
    _currentUserId = userId;
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

      // Ronda 156: Iniciar sondeo con a=posicion cada 10 segundos
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

  /// Ronda 156: Inicia el timer dinámico usando siguienteSeg (10 s)
  void startPolling(String userId) {
    _currentUserId = userId;
    _isPollingPaused = false;
    _scheduleNextPoll();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void pausePolling() {
    _isPollingPaused = true;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void resumePolling(String userId) {
    _currentUserId = userId;
    _isPollingPaused = false;
    // Sondeo inmediato al volver al primer plano y programar siguientes
    _pollUpdates(userId);
  }

  void _scheduleNextPoll() {
    _pollingTimer?.cancel();
    if (_isPollingPaused) return;

    final delay = Duration(seconds: _siguienteSeg > 0 ? _siguienteSeg : 10);
    _pollingTimer = Timer(delay, () async {
      await _pollUpdates(_currentUserId);
    });
  }

  /// Ronda 156: Consultar a=posicion mandando idVehic y desde
  Future<void> _pollUpdates(String userId) async {
    if (_isPollingPaused || state.isUpdating || state.devices.isEmpty) {
      _scheduleNextPoll();
      return;
    }

    // Determinar vehículos a consultar
    dynamic idVehicParam;
    String? desdeParam;

    if (state.selectedVehicleId != null) {
      final intId = int.tryParse(state.selectedVehicleId!) ?? 0;
      if (intId <= 0) {
        _scheduleNextPoll();
        return;
      }
      idVehicParam = intId;
      final sel = state.selectedVehicle;
      final rawFecha = sel?['fechaHora'] ?? sel?['fecha'] ?? sel?['lastUpdate'];
      if (rawFecha != null && rawFecha.toString().isNotEmpty) {
        desdeParam = rawFecha.toString();
      }
    } else {
      // Si no hay vehículo individual seleccionado, consultar hasta 50 de la flota
      final ids = state.devices
          .map((d) => int.tryParse(d['id'].toString()) ?? 0)
          .where((id) => id > 0)
          .take(50)
          .toList();
      if (ids.isEmpty) {
        _scheduleNextPoll();
        return;
      }
      idVehicParam = ids;
      // Enviar la fecha más antigua conocida entre ellos como 'desde'
      String? oldestDate;
      for (final d in state.devices) {
        final f = (d['fechaHora'] ?? d['fecha'] ?? d['lastUpdate'])?.toString();
        if (f != null && f.isNotEmpty) {
          if (oldestDate == null || f.compareTo(oldestDate) < 0) {
            oldestDate = f;
          }
        }
      }
      desdeParam = oldestDate;
    }

    try {
      final res = await _dbService.obtenerPosicion(
        idVehic: idVehicParam,
        desde: desdeParam,
      );

      // Ronda 156: siguienteSeg define el próximo intervalo (default 10)
      if (res['siguienteSeg'] is num) {
        final seg = (res['siguienteSeg'] as num).toInt();
        _siguienteSeg = seg > 0 ? seg : 10;
      } else {
        _siguienteSeg = 10;
      }

      final rawPosiciones = res['posiciones'];
      if (rawPosiciones is List && rawPosiciones.isNotEmpty) {
        final List<Map<String, dynamic>> updatedDevices = List.from(state.devices);
        final Map<String, String> updatedTimeMap = Map.from(state.deviceTimeElapsed);
        bool anyUpdated = false;

        for (final posItem in rawPosiciones) {
          if (posItem is! Map) continue;
          final pos = Map<String, dynamic>.from(posItem);
          final idStr = (pos['idVehic'] ?? pos['id'] ?? pos['idEq'])?.toString();
          if (idStr == null) continue;

          final gps = pos['gps'] is Map
              ? Map<String, dynamic>.from(pos['gps'] as Map)
              : <String, dynamic>{};

          final newLat = gps['lat'];
          final newLng = gps['lng'];
          final bool hasValidCoords = newLat != null &&
              newLng != null &&
              newLat.toString() != '0' &&
              newLng.toString() != '0' &&
              newLat.toString() != '0.0' &&
              newLng.toString() != '0.0';

          final idx = updatedDevices.indexWhere((d) => d['id'].toString() == idStr);
          if (idx >= 0) {
            final current = updatedDevices[idx];
            final updatedDev = {
              ...current,
              if (hasValidCoords) 'lat': newLat.toString(),
              if (hasValidCoords) 'lng': newLng.toString(),
              if (gps.containsKey('ignicion'))
                'ignStatus': (gps['ignicion'] == 1 || gps['ignicion'] == true) ? 1 : 0,
              if (gps.containsKey('velocidad'))
                'velocidad': gps['velocidad'].toString(),
              if (gps.containsKey('velocidad'))
                'speed': gps['velocidad'].toString(),
              if (gps.containsKey('rumbo')) 'rumbo': gps['rumbo'],
              if (gps.containsKey('rumbo')) 'dir': gps['rumbo'],
              if (gps.containsKey('rumbo')) 'course': gps['rumbo'].toString(),
              if (gps.containsKey('bateria')) 'bateria': gps['bateria'],
              if (gps.containsKey('bateria')) 'batc': gps['bateria'],
              if (gps.containsKey('satelites'))
                'satelites': gps['satelites'].toString(),
              if (gps.containsKey('satelites'))
                'satellites': gps['satelites'].toString(),
              if (gps.containsKey('odometro'))
                'odometro': gps['odometro'].toString(),
              if (gps.containsKey('fecha')) 'fecha': gps['fecha'].toString(),
              if (gps.containsKey('fecha')) 'fechaHora': gps['fecha'].toString(),
              if (gps.containsKey('fecha')) 'lastUpdate': gps['fecha'].toString(),
            };

            updatedDevices[idx] = updatedDev;
            updatedTimeMap[idStr] = _calculateDeviceTimeElapsed(updatedDev);
            anyUpdated = true;
          }
        }

        // Ronda 156: Mover el marcador solo si llega algo en posiciones
        if (anyUpdated) {
          state = state.copyWith(
            devices: updatedDevices,
            deviceTimeElapsed: updatedTimeMap,
          );
        }
      }
    } catch (e) {
      debugPrint('Error en sondeo a=posicion: $e');
      // Ronda 156 Regla 4: Con HTTP 429 o sin red, esperar al siguiente turno (o el doble); nunca reintentar de inmediato
      _siguienteSeg = _siguienteSeg * 2;
      if (_siguienteSeg > 60) _siguienteSeg = 60;
    } finally {
      _scheduleNextPoll();
    }
  }

  Future<void> refreshSelectedVehicle(String userId) async {
    _currentUserId = userId;
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
      _pollUpdates(userId ?? _currentUserId);
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

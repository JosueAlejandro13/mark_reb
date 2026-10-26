import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mark_v3/services/mark_api_client.dart';

/// Servicio de Telemetría y Rastreo GPS migrado a Mark V3.1 (api.php?a=vehiculos y a=historico)
class TrackingconService {
  final MarkApiClient _client = MarkApiClient.instance;

  /// Obtener lista de vehículos con coordenadas GPS en vivo
  Future<List<Map<String, dynamic>>> getDevicesBySubAccount(
    String idSubAccount,
  ) async {
    try {
      final list = await _client.getVehiculos();
      return list.map((v) => _normalizeDevice(v)).toList();
    } catch (e) {
      debugPrint('Error en TrackingconService.getDevicesBySubAccount: $e');
      return [];
    }
  }

  /// Obtener tracking / telemetría en vivo de la unidad (optimizado por idVehic)
  Future<List<Map<String, dynamic>>> obtenerTracking(String id) async {
    try {
      final intId = int.tryParse(id) ?? 0;
      if (intId <= 0) return [];

      // Optimización: pasamos idVehic y silent: true para no saturar los logs de la consola en cada sondeo
      final list = await _client.getVehiculos(idVehic: intId, silent: true);
      final match = list.where((v) {
        final vId = (v['idVehic'] ?? v['id'] ?? v['idEq'])?.toString();
        return vId == id;
      });

      if (match.isNotEmpty) {
        return [_normalizeDevice(match.first)];
      }

      return [];
    } catch (e) {
      debugPrint('Error en TrackingconService.obtenerTracking: $e');
      return [];
    }
  }

  /// Ronda 156: Obtener posiciones nuevas de vehículos mediante a=posicion
  Future<Map<String, dynamic>> obtenerPosicion({
    required dynamic idVehic,
    String? desde,
  }) async {
    try {
      return await _client.getPosicion(
        idVehic: idVehic,
        desde: desde,
        silent: true,
      );
    } catch (e) {
      debugPrint('Error en TrackingconService.obtenerPosicion: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _normalizeDevice(Map<String, dynamic> v) {
    final gps = v['gps'] is Map<String, dynamic>
        ? v['gps'] as Map<String, dynamic>
        : (v['gps'] is Map
            ? Map<String, dynamic>.from(v['gps'] as Map)
            : <String, dynamic>{});

    final id = (v['idVehic'] ?? v['id'] ?? v['idEq'] ?? '').toString();
    final eco = (v['economico'] ??
            v['eco'] ??
            v['name'] ??
            v['economic'] ??
            (id.isNotEmpty ? 'Unidad $id' : 'Unidad'))
        .toString();
    final placas = (v['placas'] ?? v['plates'] ?? '').toString();
    final make = (v['marca'] ?? v['make'] ?? v['brand'] ?? '').toString();
    final model = (v['modelo'] ?? v['model'] ?? '').toString();
    final year = (v['anio'] ?? v['year'] ?? '').toString();
    final color = (v['color'] ?? v['ColorEngo'] ?? '').toString();
    final vin = (v['vin'] ?? v['engineNumber'] ?? '').toString();
    final subAccount =
        (v['idSubAccount'] ?? v['idEmpresa'] ?? v['subcuenta'] ?? 'N/A')
            .toString();

    final isIgnitionOn = gps['ignicion'] == 1 ||
        gps['ignicion'] == true ||
        gps['ignStatus'] == 1 ||
        v['ignStatus'] == 1 ||
        v['ignicion'] == 1;

    final lat = (gps['lat'] ?? v['lat'] ?? '0').toString();
    final lng = (gps['lng'] ?? v['lng'] ?? '0').toString();
    final speed = (gps['velocidad'] ??
            gps['speed'] ??
            v['speed'] ??
            v['velocidad'] ??
            '0')
        .toString();
    final dir = (gps['rumbo'] ??
        gps['dir'] ??
        gps['course'] ??
        v['dir'] ??
        v['rumbo'] ??
        0);
    final battery = (gps['batc'] ??
        gps['bateria'] ??
        gps['battery'] ??
        v['batc'] ??
        v['bateria'] ??
        0);
    final batteryHealth =
        (gps['bath'] ?? gps['saludBateria'] ?? v['bath'] ?? 0);
    final satellites =
        (gps['satelites'] ?? gps['satellites'] ?? v['satelites'] ?? '0')
            .toString();
    final odometer = (gps['odometro'] ??
            gps['odometer'] ??
            v['odometro'] ??
            v['odom'] ??
            '0')
        .toString();
    final fechaHora = (gps['fecha'] ??
            gps['fechaHora'] ??
            gps['hora'] ??
            v['fechaHora'] ??
            v['fecha'] ??
            '')
        .toString();
    final timApagado =
        gps['timApagado'] ?? gps['tiempoApagado'] ?? v['timApagado'] ?? 0;
    final timOper = gps['timOper'] ?? v['timOper'] ?? 0;

    return _cleanDeviceData({
      ...v,
      'id': id,
      'idVehic': v['idVehic'] ?? int.tryParse(id),
      'idEq': v['idEq'] ?? v['idVehic'] ?? int.tryParse(id),
      'name': eco,
      'economico': eco,
      'eco': eco,
      'economic': eco,
      'placas': placas,
      'plates': placas,
      'make': make,
      'marca': make,
      'brand': make,
      'model': model,
      'modelo': model,
      'year': year,
      'anio': year,
      'color': color,
      'vin': vin,
      'idSubAccount': subAccount,
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'velocidad': speed,
      'course': dir.toString(),
      'dir': dir,
      'rumbo': dir,
      'ignition': isIgnitionOn,
      'ignStatus': isIgnitionOn ? 1 : 0,
      'batc': battery,
      'bath': batteryHealth,
      'bateria': battery,
      'satellites': satellites,
      'satelites': satellites,
      'odometer': odometer,
      'odometro': odometer,
      'odom': odometer,
      'lastUpdate': fechaHora,
      'fechaHora': fechaHora,
      'fecha': fechaHora,
      'timApagado': timApagado,
      'timOper': timOper,
    });
  }

  Map<String, dynamic> _cleanDeviceData(Map<String, dynamic> item) {
    final cleanItem = Map<String, dynamic>.from(item);
    if (cleanItem['lat'] != null) {
      cleanItem['lat'] = _cleanCoord(cleanItem['lat']);
    }
    if (cleanItem['lng'] != null) {
      cleanItem['lng'] = _cleanCoord(cleanItem['lng']);
    }
    return cleanItem;
  }

  dynamic _cleanCoord(dynamic val) {
    if (val == null) return val;
    String s = val.toString().trim();
    if (s.startsWith('+')) {
      s = s.substring(1).trim();
    }
    if (s.endsWith('.')) {
      s = '${s}0';
    }
    return s;
  }
}

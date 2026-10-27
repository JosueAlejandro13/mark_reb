import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:mark_v3/services/mark_api_client.dart';

/// Servicio de Reabastecimiento de Combustible migrado a Mark V3.1
/// (api.php?a=acciones tipo: combustible y a=catalogos)
class StationService {
  final MarkApiClient _client = MarkApiClient.instance;

  /// Registrar recarga de combustible mediante la cola transaccional (tipo: combustible)
  Future<bool> EstacionesDeServicio({
    required int id,
    required int idUs,
    required int idSubAcco,
    required int idVehic,
    required String odom,
    required String codeES,
    required String typFuel,
    required DateTime datePrice,
    required String priceLts,
    required int lts,
    required DateTime dateCreated,
    double? lat,
    double? lng,
  }) async {
    try {
      final double precioUnitario = double.tryParse(priceLts) ?? 0.0;
      final double costoTotal = precioUnitario * lts;

      // Extraer código numérico de estación CRE de forma robusta
      int parsedCodeES = int.tryParse(codeES) ?? 0;
      if (parsedCodeES == 0 && codeES.isNotEmpty) {
        final digits = codeES.replaceAll(RegExp(r'\D'), '');
        parsedCodeES = int.tryParse(digits) ?? 0;
      }
      if (parsedCodeES == 0) {
        parsedCodeES = 2071;
      }

      final String formattedDatePrice = datePrice.year > 1990
          ? datePrice.toIso8601String().substring(0, 10)
          : DateTime.now().toIso8601String().substring(0, 10);

      final double parsedOdom = double.tryParse(odom) ?? 0.0;
      final int parsedTypFuel = int.tryParse(typFuel) ?? 6;

      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'combustible',
          'idVehic': idVehic,
          'idCombustible': parsedTypFuel,
          'typFuel': parsedTypFuel,
          'cantidad': lts,
          'lts': lts,
          if (costoTotal > 0) 'costo': costoTotal,
          'precioUnitario': precioUnitario,
          'priceLts': precioUnitario,
          'precio': precioUnitario,
          'codeES': parsedCodeES,
          'estacion': parsedCodeES,
          'datePrice': formattedDatePrice,
          'fechaPrecio': formattedDatePrice,
          'fecha': formattedDatePrice,
          'odom': parsedOdom,
          'odometro': parsedOdom,
          'fecHor': dateCreated
              .toIso8601String()
              .replaceFirst('T', ' ')
              .substring(0, 19),
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        }
      ];

      final res = await _client.sendActions(acciones);
      debugPrint('Resultado EstacionesDeServicio via a=acciones: $res');
      if (res.isNotEmpty &&
          (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error al registrar recarga en StationService: $e');
      return false;
    }
  }

  /// Obtener vehículos asignados para el módulo de reabastecimiento (con GPS del vehículo)
  Future<List<Map<String, dynamic>>> getresupply(String collaboratorId) async {
    try {
      final list = await _client.getVehiculos();
      if (list.isEmpty) return [];

      final results = <Map<String, dynamic>>[];

      for (final v in list) {
        final idVehic = v['idVehic'] ?? v['id'] ?? 0;
        final intVehicId = int.tryParse(idVehic.toString()) ?? 0;

        String combustible = 'Gasolina Regular';
        int capacidadTanque = 60;
        final dynamic odomGps = v['gps']?['odometro'] ?? 0;

        // Extraer coordenadas de GPS del vehículo
        double? latGps;
        double? lngGps;

        final gpsMap = v['gps'] is Map ? (v['gps'] as Map) : null;
        if (gpsMap != null) {
          if (gpsMap['lat'] != null) {
            latGps = double.tryParse(gpsMap['lat'].toString());
          }
          if (gpsMap['lng'] != null) {
            lngGps = double.tryParse(gpsMap['lng'].toString());
          }
        }
        if (latGps == null && v['lat'] != null) {
          latGps = double.tryParse(v['lat'].toString());
        }
        if (lngGps == null && v['lng'] != null) {
          lngGps = double.tryParse(v['lng'].toString());
        }

        // Si es el primer vehículo o la unidad del chofer, enriquecer con a=vehiculo
        if (results.isEmpty && intVehicId > 0) {
          try {
            final ficha = await _client.getVehiculo(intVehicId);
            final vData = ficha['vehiculo'] ?? {};
            if (vData['combustible'] != null &&
                vData['combustible'].toString().isNotEmpty) {
              combustible = vData['combustible'].toString();
            }
            if (vData['capacidadTanque'] != null) {
              capacidadTanque =
                  int.tryParse(vData['capacidadTanque'].toString()) ?? 60;
            }
            final fichaGps =
                vData['gps'] is Map ? (vData['gps'] as Map) : null;
            if (fichaGps != null) {
              if (fichaGps['lat'] != null) {
                final l = double.tryParse(fichaGps['lat'].toString());
                if (l != null && l != 0.0) latGps = l;
              }
              if (fichaGps['lng'] != null) {
                final l = double.tryParse(fichaGps['lng'].toString());
                if (l != null && l != 0.0) lngGps = l;
              }
            }
          } catch (_) {}

          // Si aún no hay GPS en ficha y se requiere telemetría en tiempo real:
          if ((latGps == null || latGps == 0.0) && intVehicId > 0) {
            try {
              final posData = await _client.getPosicion(
                idVehic: intVehicId,
                silent: true,
              );
              final posiciones = posData['posiciones'];
              if (posiciones is List && posiciones.isNotEmpty) {
                final lastPos = posiciones.last;
                final pGps =
                    lastPos['gps'] is Map ? lastPos['gps'] as Map : lastPos;
                if (pGps['lat'] != null) {
                  latGps = double.tryParse(pGps['lat'].toString());
                }
                if (pGps['lng'] != null) {
                  lngGps = double.tryParse(pGps['lng'].toString());
                }
              }
            } catch (_) {}
          }
        }

        results.add({
          'id': idVehic,
          'idVehic': idVehic,
          'idvehic': idVehic,
          'economic': v['economico'] ?? '',
          'plates': v['placas'] ?? '',
          'brand': v['marca'] ?? '',
          'model': v['modelo'] ?? '',
          'fuelTankCapacity': capacidadTanque,
          'odometer': odomGps,
          'odom': odomGps,
          'tipoCombustibleNombre': combustible,
          'combustible': combustible,
          'lat': latGps,
          'lng': lngGps,
          'latitude': latGps,
          'longitude': lngGps,
        });
      }

      return results;
    } catch (e) {
      debugPrint('Error al obtener datos de vehículo para resupply: $e');
      return [];
    }
  }

  /// Obtener catálogo de tipos de combustible desde a=catalogos
  Future<List<Map<String, dynamic>>> getTypeFuel() async {
    try {
      final cats = await _client.getCatalogos();
      final list = cats['combustibles'] ?? [];
      if (list is List && list.isNotEmpty) {
        return list.map((item) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final name = (m['nombre'] ?? m['name'] ?? '').toString();
            return {
              'id': m['id'],
              'name': name,
              'nombre': name,
            };
          }
          final str = item.toString();
          return {'id': str, 'name': str, 'nombre': str};
        }).toList();
      }
      return [
        {'id': 6, 'name': 'Gasolina Regular', 'nombre': 'Gasolina Regular'},
        {'id': 8, 'name': 'Gasolina Premium', 'nombre': 'Gasolina Premium'},
        {'id': 3, 'name': 'Diésel', 'nombre': 'Diésel'},
      ];
    } catch (e) {
      debugPrint('Error al obtener tipos de combustible: $e');
      return [
        {'id': 6, 'name': 'Gasolina Regular', 'nombre': 'Gasolina Regular'},
        {'id': 8, 'name': 'Gasolina Premium', 'nombre': 'Gasolina Premium'},
        {'id': 3, 'name': 'Diésel', 'nombre': 'Diésel'},
      ];
    }
  }

  /// Buscar estación cercana con precios de combustible consultando a la API
  Future<Map<String, dynamic>?> buscarEstacionCercanaConPrecio(
    double lat,
    double lng,
  ) async {
    // Si el GPS del vehículo es inválido o 0,0, no hay estación disponible
    if (lat == 0.0 && lng == 0.0) {
      debugPrint('Coordenadas GPS del vehículo no válidas ($lat, $lng)');
      return null;
    }

    try {
      // 1. Intentar consulta vía endpoint dedicado de gasolineras / estación cercana
      final Uri uri = Uri.parse('${_client.serverBaseUrl}deliveryPHP/operacion/get_nearest_station.php');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (_client.token != null) 'Authorization': 'Bearer ${_client.token}',
        },
        body: jsonEncode({
          'lat': lat,
          'lng': lng,
          if (_client.token != null) 'token': _client.token,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && (data['ok'] == true || data['success'] == true)) {
          final raw = data['data'] ?? data['estacion'] ?? data;
          if (raw is Map) {
            return Map<String, dynamic>.from(raw);
          }
        }
      }
    } catch (e) {
      debugPrint('Error al consultar estación cercana en la API: $e');
    }

    return null;
  }
}

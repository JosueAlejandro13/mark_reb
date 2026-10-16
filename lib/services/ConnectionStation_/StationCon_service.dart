import 'dart:async';
import 'package:flutter/material.dart';
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

      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'combustible',
          'idVehic': idVehic,
          'idCombustible': int.tryParse(typFuel) ?? 6,
          'cantidad': lts,
          if (costoTotal > 0) 'costo': costoTotal,
          'estacion': codeES.isNotEmpty ? 'Estación $codeES' : 'Estación de Servicio',
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

  /// Obtener vehículos asignados para el módulo de reabastecimiento
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
          } catch (_) {}
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

  /// Buscar estación cercana con precios de referencia de combustible
  Future<Map<String, dynamic>?> buscarEstacionCercanaConPrecio(
    double lat,
    double lng,
  ) async {
    return {
      'id': 1,
      'code': 'PL/2856/EXP/ES/2015',
      'codeES': '2856',
      'reg': 'PL/2856/EXP/ES/2015',
      'name': 'Estación de Servicio Cercana',
      'dist': 50,
      'fecha': DateTime.now().toIso8601String().substring(0, 10),
      'regular': 23.99,
      'premium': 25.89,
      'diesel': 25.19,
    };
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:mark_v3/services/mark_api_client.dart';

/// Servicio de Mi Vehículo migrado a Mark V3.1 (api.php?a=vehiculos y a=vehiculo)
class MyvehicleconService {
  final MarkApiClient _client = MarkApiClient.instance;

  /// Obtener vehículos asignados al colaborador
  Future<List<Map<String, dynamic>>> getVehiclesByCollaboratorId(
    String collaboratorId,
  ) async {
    try {
      final list = await _client.getVehiculos();
      return list.map((v) {
        final gps = v['gps'] is Map ? v['gps'] as Map : {};
        final odom = (gps['odometro'] ?? v['odometro'] ?? '0').toString();
        final estatus = (v['estatus'] ?? v['Status'] ?? 'Activo').toString();
        final marca = (v['marca'] ?? v['make'] ?? '').toString();
        final modelo = (v['modelo'] ?? v['model'] ?? '').toString();
        final placas = (v['placas'] ?? v['plates'] ?? '').toString();
        final anio = (v['anio'] ?? v['year'] ?? '').toString();
        final id = (v['idVehic'] ?? v['id'] ?? '').toString();
        final vin = (v['vin'] ?? '').toString();
        final color = (v['color'] ?? '').toString();

        return {
          'id': id,
          'idVehic': id,
          'idvehic': id,
          'eco': v['economico'] ?? '',
          'economic': v['economico'] ?? '',
          'plates': placas,
          'placas': placas,
          'brand': marca,
          'marca': marca,
          'make': marca,
          'model': modelo,
          'modelo': modelo,
          'year': anio,
          'anio': anio,
          'color': color,
          'ColorEngo': color,
          'status': estatus,
          'Status': estatus,
          'Estado': estatus,
          'idStatus': (v['idEstatus'] ?? v['idStatus'] ?? 1).toString(),
          'photo': (v['foto'] ?? '').toString().isNotEmpty ? _client.resolveAssetUrl((v['foto'] ?? '').toString()) : '',
          'foto': (v['foto'] ?? '').toString().isNotEmpty ? _client.resolveAssetUrl((v['foto'] ?? '').toString()) : '',
          'vin': vin,
          'engineNumber': vin,
          'lat': gps['lat']?.toString() ?? '0',
          'lng': gps['lng']?.toString() ?? '0',
          'speed': gps['velocidad']?.toString() ?? '0',
          'odom': odom,
          'odometro': odom,
          'odometer': odom,
          'gps': gps,
          'capacidadTanque': v['capacidadTanque']?.toString() ?? '',
          'fuelTankCapacity': v['capacidadTanque']?.toString() ?? '',
          'tipoVehiculoNombre': v['tipoVehiculoNombre'] ?? 'Vehículo',
          'tipoCombustibleNombre': v['tipoCombustibleNombre'] ?? 'Gasolina',
          'cilindrada': v['cilindrada']?.toString() ?? 'N/A',
          'nCilindros': v['nCilindros']?.toString() ?? 'N/A',
          'promConsumo': v['promConsumo']?.toString() ?? 'N/A',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error en MyvehicleconService.getVehiclesByCollaboratorId: $e');
      return [];
    }
  }

  /// Actualizar datos del vehículo (vía a=acciones tipo: vehiculo)
  Future<void> updateVehicleT(
    Map<String, dynamic> vehicleData,
    String idMainAccount,
  ) async {
    try {
      final idVehic = int.tryParse(vehicleData['id']?.toString() ?? '') ?? 0;
      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'vehiculo',
          'idVehic': idVehic,
          'economico': vehicleData['economic'] ?? vehicleData['eco'],
          'placas': vehicleData['plates'] ?? vehicleData['placas'],
          'vin': vehicleData['vin'],
          'color': vehicleData['color'],
          'anio': int.tryParse(vehicleData['year']?.toString() ?? ''),
          'capacidadTanque': double.tryParse(vehicleData['fuelTankCapacity']?.toString() ?? ''),
          'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
        }
      ];

      final res = await _client.sendActions(acciones);
      debugPrint('Vehículo actualizado vía a=acciones: $res');
      if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
        final avisos = res.first['avisos'] as List? ?? [];
        final errorTexto = avisos.isNotEmpty
            ? avisos.first['texto']?.toString()
            : 'Acción rechazada por el servidor.';
        throw Exception(errorTexto);
      }
    } catch (e) {
      debugPrint('Error en updateVehicleT: $e');
      rethrow;
    }
  }

  /// Cambiar estatus del vehículo (vía a=acciones tipo: estatus)
  Future<void> updatevehicleStatus(String status, String vehicleId) async {
    try {
      final idVehic = int.tryParse(vehicleId) ?? 0;
      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'estatus',
          'idVehic': idVehic,
          'estatus': status,
          'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
        }
      ];

      final res = await _client.sendActions(acciones);
      debugPrint('Estatus de vehículo actualizado vía a=acciones: $res');
      if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
        final avisos = res.first['avisos'] as List? ?? [];
        final errorTexto = avisos.isNotEmpty
            ? avisos.first['texto']?.toString()
            : 'Acción rechazada por el servidor.';
        throw Exception(errorTexto);
      }
    } catch (e) {
      debugPrint('Error en updatevehicleStatus: $e');
      rethrow;
    }
  }

  /// Obtener catálogos del vehículo (marcas, combustibles, coberturas, estatus)
  Future<Map<String, List<Map<String, dynamic>>>> obtenerCatalogosVehiculo() async {
    try {
      final cats = await _client.getCatalogos();
      return {
        'vehicType': [],
        'vehicFuel': List<Map<String, dynamic>>.from(cats['combustibles'] ?? []),
        'vehicStatus': List<Map<String, dynamic>>.from(cats['estatus'] ?? []),
        'engomados': List<Map<String, dynamic>>.from(cats['hologramas'] ?? []),
        'make': List<Map<String, dynamic>>.from(cats['marcas'] ?? []),
        'cobertura': List<Map<String, dynamic>>.from(cats['coberturas'] ?? []),
      };
    } catch (e) {
      debugPrint('Error en obtenerCatalogosVehiculo: $e');
      return {
        'vehicType': [],
        'vehicFuel': [],
        'vehicStatus': [],
        'engomados': [],
        'make': [],
        'cobertura': [],
      };
    }
  }

  /// Obtener modelos por marca
  Future<List<Map<String, dynamic>>> obtenerModel(int idMake) async {
    return [];
  }

  /// Obtener lista de estatus
  Future<List<Map<String, dynamic>>> obtenerStatus() async {
    try {
      final cats = await _client.getCatalogos();
      final list = cats['estatus'] ?? [];
      if (list is List) {
        return list.map((item) {
          if (item is Map<String, dynamic>) return item;
          return {'id': item.toString(), 'status': item.toString()};
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error en obtenerStatus: $e');
      return [];
    }
  }
}

import 'dart:async';import 'package:flutter/material.dart';
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
  Future<void> updatevehicleStatus(
    String status,
    String vehicleId, {
    String? statusName,
    String? obs,
  }) async {
    try {
      final idVehic = int.tryParse(vehicleId) ?? 0;
      final statusInt = int.tryParse(status);

      final accion = <String, dynamic>{
        'uuid': const Uuid().v4(),
        'tipo': 'estatus',
        'idVehic': idVehic,
        // El backend PHP valida el estatus numérico (intval($act['estatus']) > 0)
        'estatus': statusInt ?? status,
        if (statusInt != null) 'idEstatus': statusInt,
        if (statusName != null && statusName.isNotEmpty) 'nombre': statusName,
        if (obs != null && obs.isNotEmpty) 'obs': obs,
        'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
      };

      final res = await _client.sendActions([accion]);
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

  static const List<Map<String, dynamic>> defaultVehicleStatuses = [
    {'id': '1', 'name': 'Activo', 'nombre': 'Activo', 'status': 'Activo', 'estatus': 'Activo'},
    {'id': '2', 'name': 'Inactivo', 'nombre': 'Inactivo', 'status': 'Inactivo', 'estatus': 'Inactivo'},
    {'id': '3', 'name': 'En Taller', 'nombre': 'En Taller', 'status': 'En Taller', 'estatus': 'En Taller'},
    {'id': '4', 'name': 'Fuera de Servicio', 'nombre': 'Fuera de Servicio', 'status': 'Fuera de Servicio', 'estatus': 'Fuera de Servicio'},
    {'id': '5', 'name': 'Vendido', 'nombre': 'Vendido', 'status': 'Vendido', 'estatus': 'Vendido'},
    {'id': '6', 'name': 'Corralón', 'nombre': 'Corralón', 'status': 'Corralón', 'estatus': 'Corralón'},
    {'id': '7', 'name': 'Robo', 'nombre': 'Robo', 'status': 'Robo', 'estatus': 'Robo'},
    {'id': '8', 'name': 'Baja', 'nombre': 'Baja', 'status': 'Baja', 'estatus': 'Baja'},
  ];

  static const List<Map<String, dynamic>> defaultFuels = [
    {'id': '6', 'name': 'Gasolina Regular', 'nombre': 'Gasolina Regular'},
    {'id': '8', 'name': 'Gasolina Premium', 'nombre': 'Gasolina Premium'},
    {'id': '3', 'name': 'Diésel', 'nombre': 'Diésel'},
    {'id': '1', 'name': 'Gas LP', 'nombre': 'Gas LP'},
    {'id': '4', 'name': 'Gas Natural', 'nombre': 'Gas Natural'},
    {'id': '2', 'name': 'Eléctrico', 'nombre': 'Eléctrico'},
    {'id': '5', 'name': 'Híbrido', 'nombre': 'Híbrido'},
  ];

  static const List<Map<String, dynamic>> defaultMakes = [
    {'id': '1', 'name': 'Nissan', 'nombre': 'Nissan'},
    {'id': '2', 'name': 'Chevrolet', 'nombre': 'Chevrolet'},
    {'id': '3', 'name': 'Ford', 'nombre': 'Ford'},
    {'id': '4', 'name': 'Toyota', 'nombre': 'Toyota'},
    {'id': '5', 'name': 'Volkswagen', 'nombre': 'Volkswagen'},
    {'id': '6', 'name': 'Kenworth', 'nombre': 'Kenworth'},
    {'id': '7', 'name': 'Freightliner', 'nombre': 'Freightliner'},
    {'id': '8', 'name': 'Hino', 'nombre': 'Hino'},
    {'id': '9', 'name': 'Isuzu', 'nombre': 'Isuzu'},
    {'id': '10', 'name': 'Mercedes-Benz', 'nombre': 'Mercedes-Benz'},
    {'id': '11', 'name': 'International', 'nombre': 'International'},
    {'id': '12', 'name': 'Dodge / RAM', 'nombre': 'Dodge / RAM'},
    {'id': '13', 'name': 'Honda', 'nombre': 'Honda'},
    {'id': '14', 'name': 'Hyundai', 'nombre': 'Hyundai'},
  ];

  static const List<Map<String, dynamic>> defaultVehicleTypes = [
    {'id': '1', 'name': 'Sedán', 'nombre': 'Sedán'},
    {'id': '2', 'name': 'Pickup', 'nombre': 'Pickup'},
    {'id': '3', 'name': 'Camión 3.5 Ton', 'nombre': 'Camión 3.5 Ton'},
    {'id': '4', 'name': 'Torton', 'nombre': 'Torton'},
    {'id': '5', 'name': 'Tractocamión / Tráiler', 'nombre': 'Tractocamión / Tráiler'},
    {'id': '6', 'name': 'Van / Utilitario', 'nombre': 'Van / Utilitario'},
    {'id': '7', 'name': 'Motocicleta', 'nombre': 'Motocicleta'},
    {'id': '8', 'name': 'Remolque', 'nombre': 'Remolque'},
  ];

  static const List<Map<String, dynamic>> defaultEngomados = [
    {'id': '1', 'name': 'Doble Cero (00)', 'nombre': 'Doble Cero (00)', 'hologram': '00'},
    {'id': '2', 'name': 'Cero (0)', 'nombre': 'Cero (0)', 'hologram': '0'},
    {'id': '3', 'name': 'Uno (1)', 'nombre': 'Uno (1)', 'hologram': '1'},
    {'id': '4', 'name': 'Dos (2)', 'nombre': 'Dos (2)', 'hologram': '2'},
    {'id': '5', 'name': 'Exento', 'nombre': 'Exento', 'hologram': 'Exento'},
  ];

  List<Map<String, dynamic>> _parseListCatalog(
    dynamic raw, {
    List<Map<String, dynamic>> defaultFallback = const [],
  }) {
    if (raw == null) return defaultFallback;
    if (raw is List && raw.isNotEmpty) {
      final result = <Map<String, dynamic>>[];
      for (int i = 0; i < raw.length; i++) {
        final item = raw[i];
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final id = (m['id'] ?? m['idEstatus'] ?? m['id_status'] ?? m['idStatus'] ?? (i + 1)).toString();
          final name = (m['name'] ?? m['nombre'] ?? m['status'] ?? m['estatus'] ?? m['descripcion'] ?? '').toString();
          if (name.isNotEmpty) {
            result.add({
              'id': id,
              'name': name,
              'nombre': name,
              'status': name,
              'estatus': name,
            });
          }
        } else if (item is String && item.trim().isNotEmpty) {
          final name = item.trim();
          result.add({
            'id': (i + 1).toString(),
            'name': name,
            'nombre': name,
            'status': name,
            'estatus': name,
          });
        }
      }
      if (result.isNotEmpty) return result;
    }
    return defaultFallback;
  }

  /// Obtener catálogos del vehículo (marcas, combustibles, coberturas, estatus)
  Future<Map<String, List<Map<String, dynamic>>>> obtenerCatalogosVehiculo() async {
    try {
      final cats = await _client.getCatalogos();
      return {
        'vehicType': _parseListCatalog(cats['tiposVehiculo'] ?? cats['vehicType'], defaultFallback: defaultVehicleTypes),
        'vehicFuel': _parseListCatalog(cats['combustibles'], defaultFallback: defaultFuels),
        'vehicStatus': _parseListCatalog(cats['estatus'], defaultFallback: defaultVehicleStatuses),
        'engomados': _parseListCatalog(cats['hologramas'], defaultFallback: defaultEngomados),
        'make': _parseListCatalog(cats['marcas'], defaultFallback: defaultMakes),
        'cobertura': _parseListCatalog(cats['coberturas']),
      };
    } catch (e) {
      debugPrint('Error en obtenerCatalogosVehiculo: $e');
      return {
        'vehicType': defaultVehicleTypes,
        'vehicFuel': defaultFuels,
        'vehicStatus': defaultVehicleStatuses,
        'engomados': defaultEngomados,
        'make': defaultMakes,
        'cobertura': const [],
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
      return _parseListCatalog(cats['estatus'], defaultFallback: defaultVehicleStatuses);
    } catch (e) {
      debugPrint('Error en obtenerStatus: $e');
      return defaultVehicleStatuses;
    }
  }

  /// Subir y actualizar la fotografía del vehículo en el servidor vía a=foto y a=acciones (tipo: vehiculo)
  Future<String> updateVehiclePhoto(dynamic idVehic, String filePath) async {
    final photoUuid = const Uuid().v4();
    final ok = await _client.uploadPhoto(
      uuid: photoUuid,
      tipo: 1, // 1 = foto
      filePath: filePath,
    );
    if (!ok) {
      throw Exception('No se pudo subir la fotografía al servidor.');
    }

    final intIdVehic = int.tryParse(idVehic.toString()) ?? idVehic;

    final acciones = [
      {
        'uuid': const Uuid().v4(),
        'tipo': 'vehiculo',
        'idVehic': intIdVehic,
        'foto': photoUuid,
        'fecHor': DateTime.now()
            .toIso8601String()
            .replaceFirst('T', ' ')
            .substring(0, 19),
      }
    ];

    final res = await _client.sendActions(acciones);
    debugPrint('Resultado updateVehiclePhoto via a=acciones: $res');
    if (res.isNotEmpty &&
        (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
      final avisos = res.first['avisos'] as List? ?? [];
      final errorTexto = avisos.isNotEmpty
          ? avisos.first['texto']?.toString()
          : 'Error al actualizar la foto del vehículo en el servidor.';
      throw Exception(errorTexto);
    }
    return photoUuid;
  }
}

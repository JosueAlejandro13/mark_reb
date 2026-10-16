import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:mark_v3/services/mark_api_client.dart';

/// Servicio de Inspecciones de Seguridad migrado a Mark V3.1
/// (api.php?a=inspecciones y a=acciones tipo: inspeccion)
class InspeccionconService {
  final MarkApiClient _client = MarkApiClient.instance;

  /// Crear inspección con todos sus ítems mediante la cola transaccional (tipo: inspeccion)
  Future<String?> crearInspeccionYItems(
    String idUs,
    String idVehic,
    String idTemplateInspection,
    DateTime startDate,
    DateTime endDate,
    String idResponsible,
    int status,
    String location,
    String obs,
    int typSource,
    String idSource,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      // Mapear los items al formato oficial de la guía de Nelson:
      // items: [{idItem, ok: true · false · "na", comentario, foto}]
      final mappedItems = items.map((it) {
        final okVal = it['status'] == 1 || it['ok'] == true;
        final isNa = it['status'] == 3 || it['ok'] == 'na';
        return {
          'idItem': it['idItem'] ?? it['id'] ?? 0,
          'ok': isNa ? 'na' : okVal,
          if (it['comment'] != null && it['comment'].toString().isNotEmpty)
            'comentario': it['comment'],
          if (it['imgUrl'] != null && it['imgUrl'].toString().isNotEmpty)
            'foto': it['imgUrl'],
        };
      }).toList();

      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'inspeccion',
          'idVehic': int.tryParse(idVehic) ?? 0,
          'idPlantilla': int.tryParse(idTemplateInspection) ?? 1,
          'estatus': status, // 1: Excelente, 2: Con detalles, 3: Fallida
          'obs': obs,
          'items': mappedItems,
          'fecHor': startDate
              .toIso8601String()
              .replaceFirst('T', ' ')
              .substring(0, 19),
        }
      ];

      final res = await _client.sendActions(acciones);
      debugPrint('Resultado crearInspeccionYItems via a=acciones: $res');
      if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
        final avisos = res.first['avisos'] as List? ?? [];
        final errorTexto = avisos.isNotEmpty
            ? avisos.first['texto']?.toString()
            : 'Acción rechazada por el servidor.';
        throw Exception(errorTexto);
      }
      return null;
    } catch (e) {
      debugPrint('Error al crear la inspección en InspeccionconService: $e');
      rethrow;
    }
  }

  Future<int> CrearItemInsepeccion(
    int idInspection,
    int idItem,
    int status,
    String auxval,
    String comment,
    String imgUrl,
    int idUs,
  ) async {
    return 0;
  }

  /// Obtener plantillas de inspección asignadas al vehículo (a=inspecciones)
  Future<List<Map<String, dynamic>>> obtenerPlantillasPorUsuarioYVehiculo(
    String idUs,
    int idVehic,
  ) async {
    try {
      final res = await _client.getInspecciones(idVehic);
      final plantillas = res['plantillas'] ?? res['data'] ?? [];

      if (plantillas is List && plantillas.isNotEmpty) {
        return plantillas.map((p) {
          return {
            'id': p['id'] ?? p['idPlantilla'] ?? 1,
            'name': p['nombre'] ?? p['name'] ?? 'Inspección General',
            'decription': p['descripcion'] ?? p['decription'] ?? '',
            'enableStorePhoto': p['fotoSiFalla'] == true || p['enableStorePhoto'] == 1 ? 1 : 0,
            'periodicity': p['periodicidad'] ?? p['periodicity'] ?? 1,
            'lastInspectionDate': p['ultima']?.toString(),
          };
        }).toList();
      }

      // Fallback predeterminado si el servidor no tiene plantillas configuradas
      return [
        {
          'id': 1,
          'name': 'Inspección Preoperativa Diaria',
          'decription': 'Revisión mecánica, niveles de fluidos, luces y seguridad.',
          'enableStorePhoto': 1,
          'periodicity': 1,
          'lastInspectionDate': null,
        }
      ];
    } catch (e) {
      debugPrint('Error en obtenerPlantillasPorUsuarioYVehiculo: $e');
      return [
        {
          'id': 1,
          'name': 'Inspección Preoperativa Diaria',
          'decription': 'Revisión mecánica, niveles de fluidos, luces y seguridad.',
          'enableStorePhoto': 1,
          'periodicity': 1,
          'lastInspectionDate': null,
        }
      ];
    }
  }

  /// Obtener ítems / puntos de una plantilla
  Future<List<Map<String, dynamic>>> obtenerInspeccionesPorVehiculo({
    required String idVehic,
    required String idItemTemplate,
  }) async {
    try {
      final intVehic = int.tryParse(idVehic) ?? 0;
      final res = await _client.getInspecciones(intVehic);
      final plantillas = res['plantillas'] ?? res['data'] ?? [];

      if (plantillas is List) {
        for (final p in plantillas) {
          if (p['id']?.toString() == idItemTemplate ||
              p['idPlantilla']?.toString() == idItemTemplate) {
            final puntos = p['puntos'] ?? p['items'] ?? [];
            if (puntos is List) {
              return List<Map<String, dynamic>>.from(puntos);
            }
          }
        }
      }

      // Puntos estándar de inspección si no vienen asignados
      return [
        {'id': 1, 'name': 'Nivel de aceite de motor', 'category': 'Fluidos'},
        {'id': 2, 'name': 'Presión y estado de neumáticos', 'category': 'Neumáticos'},
        {'id': 3, 'name': 'Luces principales y direccionales', 'category': 'Eléctrico'},
        {'id': 4, 'name': 'Líquido de frenos', 'category': 'Frenos'},
        {'id': 5, 'name': 'Estado de carrocería y espejos', 'category': 'Carrocería'},
      ];
    } catch (e) {
      debugPrint('Error en obtenerInspeccionesPorVehiculo: $e');
      return [
        {'id': 1, 'name': 'Nivel de aceite de motor', 'category': 'Fluidos'},
        {'id': 2, 'name': 'Presión y estado de neumáticos', 'category': 'Neumáticos'},
        {'id': 3, 'name': 'Luces principales y direccionales', 'category': 'Eléctrico'},
        {'id': 4, 'name': 'Líquido de frenos', 'category': 'Frenos'},
        {'id': 5, 'name': 'Estado de carrocería y espejos', 'category': 'Carrocería'},
      ];
    }
  }

  /// Obtener última inspección del vehículo
  Future<Map<String, dynamic>?> obtenerUltimaInspeccion(
    String idVehic,
    String idTemplateInspection,
    String idUs,
  ) async {
    try {
      final intVehic = int.tryParse(idVehic) ?? 0;
      final res = await _client.getInspecciones(intVehic);
      final ultima = res['ultima'];
      if (ultima is Map<String, dynamic>) {
        return {
          'startDate': DateTime.tryParse(ultima['fecha'] ?? '') ?? DateTime.now(),
          'endDate': DateTime.tryParse(ultima['fecha'] ?? '') ?? DateTime.now(),
          'periodicity': 1,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error en obtenerUltimaInspeccion: $e');
      return null;
    }
  }
}

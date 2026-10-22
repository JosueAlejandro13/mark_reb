import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      // Mapear los items al formato oficial de la guía de Nelson (Pág. 7 y 14):
      // items: [{idItem, ok: true · false · "na", comentario, foto}]
      final List<Map<String, dynamic>> mappedItems = [];

      for (final it in items) {
        final okVal = it['status'] == 1 || it['ok'] == true;
        final isNa = it['status'] == 3 || it['ok'] == 'na';
        String? fotoUuid;

        final imgPath = it['imgUrl']?.toString();
        if (imgPath != null && imgPath.isNotEmpty) {
          final isUuid = RegExp(
                  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
              .hasMatch(imgPath);

          if (isUuid) {
            fotoUuid = imgPath;
          } else {
            final f = File(imgPath);
            if (f.existsSync()) {
              fotoUuid = const Uuid().v4();
              try {
                // Subir cada foto con a=foto (multipart, tipo 1 = foto) según la guía (Pág. 10 y 14)
                await _client.uploadPhoto(
                  uuid: fotoUuid,
                  tipo: 1,
                  filePath: imgPath,
                );
              } catch (e) {
                debugPrint('Aviso: no se pudo subir foto previa a inspección: $e');
              }
            }
          }
        }

        mappedItems.add({
          'idItem': it['idItem'] ?? it['id'] ?? 0,
          'ok': isNa ? 'na' : okVal,
          if (it['comment'] != null && it['comment'].toString().isNotEmpty)
            'comentario': it['comment'],
          if (fotoUuid != null && fotoUuid.isNotEmpty) 'foto': fotoUuid,
        });
      }

      // Parsear lat y lng de location
      double? lat;
      double? lng;
      if (location.contains(',')) {
        final parts = location.split(',');
        lat = double.tryParse(parts[0].trim());
        lng = double.tryParse(parts[1].trim());
      }

      // Estatus general estricto de la guía (1: Excelente, 2: Con detalles, 3: Fallida)
      final int validStatus = (status >= 1 && status <= 3) ? status : 2;

      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'inspeccion',
          'idVehic': int.tryParse(idVehic) ?? 0,
          'idPlantilla': int.tryParse(idTemplateInspection) ?? 1,
          'estatus': validStatus,
          'obs': obs,
          if (lat != null && lng != null) ...{
            'lat': lat,
            'lng': lng,
          },
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
        final primerAviso = avisos.isNotEmpty ? avisos.first as Map? : null;
        final codigoAviso = primerAviso?['codigo']?.toString();
        final errorTexto = primerAviso?['texto']?.toString() ?? 'Acción rechazada por el servidor.';

        if (codigoAviso == 'INSPECCION_DUPLICADA') {
          throw Exception('Ya se realizó una inspección preoperativa para esta unidad hoy.');
        }
        throw Exception(errorTexto);
      }

      // Guardar registro local en SharedPreferences para evitar inspecciones duplicadas
      // inmediatamente en la app antes de que el servidor actualice su lectura
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'last_inspection_${idVehic}_$idTemplateInspection',
          DateTime.now().toIso8601String(),
        );
      } catch (e) {
        debugPrint('Aviso: no se pudo guardar fecha local de inspección: $e');
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
            // Ronda 144 additions:
            'puedeHoy': p['puedeHoy'],
            'hoyHecha': p['hoyHecha'],
            'idInspeccionHoy': p['idInspeccionHoy'],
            'ultimaInspeccion': p['ultimaInspeccion'],
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

  /// Obtener última inspección del vehículo considerando backend (ultima, historial, plantillas) y caché local
  Future<Map<String, dynamic>?> obtenerUltimaInspeccion(
    String idVehic,
    String idTemplateInspection,
    String idUs,
  ) async {
    try {
      final intVehic = int.tryParse(idVehic) ?? 0;
      final res = await _client.getInspecciones(intVehic);
      
      DateTime? latestDate;
      int periodicity = 1;

      // 1. Revisar si el backend entrega 'ultima' directamente
      final ultima = res['ultima'];
      if (ultima is Map<String, dynamic>) {
        final rawDate = ultima['fecha'] ?? ultima['fecHor'] ?? ultima['date'];
        if (rawDate != null) {
          latestDate = DateTime.tryParse(rawDate.toString());
        }
      }

      // 2. Revisar si viene en 'historial' o 'inspecciones'
      final historial = res['historial'] ?? res['inspecciones'] ?? res['data'];
      if (historial is List && historial.isNotEmpty) {
        for (final item in historial) {
          if (item is Map<String, dynamic>) {
            final tplId = item['idPlantilla']?.toString() ?? item['plantillaId']?.toString();
            // Si la inspección es de esta plantilla o general
            if (tplId == null || tplId == idTemplateInspection) {
              final rawDate = item['fecha'] ?? item['fecHor'] ?? item['endDate'] ?? item['fechaHora'];
              if (rawDate != null) {
                final d = DateTime.tryParse(rawDate.toString());
                if (d != null) {
                  if (latestDate == null || d.isAfter(latestDate)) {
                    latestDate = d;
                  }
                }
              }
            }
          }
        }
      }

      // 3. Revisar en las plantillas si la plantilla reporta 'lastInspectionDate' / 'ultimaFecha'
      final plantillas = res['plantillas'];
      if (plantillas is List) {
        for (final p in plantillas) {
          if (p is Map<String, dynamic> &&
              (p['id']?.toString() == idTemplateInspection ||
               p['idPlantilla']?.toString() == idTemplateInspection)) {
            final pPer = p['periodicidad'] ?? p['periodicity'];
            if (pPer != null) {
              periodicity = int.tryParse(pPer.toString()) ?? periodicity;
            }
            final rawDate = p['ultimaFecha'] ?? p['lastInspectionDate'] ?? p['fechaUltima'];
            if (rawDate != null) {
              final d = DateTime.tryParse(rawDate.toString());
              if (d != null) {
                if (latestDate == null || d.isAfter(latestDate)) {
                  latestDate = d;
                }
              }
            }
          }
        }
      }

      // 4. Revisar respaldo local en SharedPreferences por si el backend aún no ha sincronizado la lectura
      try {
        final prefs = await SharedPreferences.getInstance();
        final localDateStr = prefs.getString('last_inspection_${idVehic}_$idTemplateInspection');
        if (localDateStr != null) {
          final localDate = DateTime.tryParse(localDateStr);
          if (localDate != null) {
            if (latestDate == null || localDate.isAfter(latestDate)) {
              latestDate = localDate;
            }
          }
        }
      } catch (e) {
        debugPrint('Aviso al leer SharedPreferences para última inspección: $e');
      }

      if (latestDate != null) {
        return {
          'startDate': latestDate,
          'endDate': latestDate,
          'periodicity': periodicity,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error en obtenerUltimaInspeccion: $e');
      return null;
    }
  }
}

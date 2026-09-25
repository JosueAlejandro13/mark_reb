import 'dart:async';
import 'package:mark_v3/services/database_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

//Autor: Josue Hernandez
class InspeccionconService {
  final String _baseUrl = '${DatabaseService.apiUrl}/inspecciones';

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
      final response = await http.post(
        Uri.parse('$_baseUrl/create_inspection.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idUs': idUs,
          'idVehic': idVehic,
          'idTemplateInspection': idTemplateInspection,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'idResponsible': idResponsible,
          'status': status,
          'location': location,
          'obs': obs,
          'typSource': typSource,
          'idSource': idSource,
          'items': items,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint(
              'Inspección creada con éxito con ID: ${data['idInspection']}');
          return null;
        } else {
          debugPrint('Error del servidor: ${data['message']}');
          throw Exception(data['message']);
        }
      } else {
        throw Exception(
            'Error al conectar con el servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al crear la inspección y los ítems: $e');
      rethrow;
    }
  }

  // Se mantiene el método por compatibilidad si otras partes del código lo llaman,
  // aunque el backend PHP ya se encarga de guardar los items internamente.
  Future<int> CrearItemInsepeccion(
    int idInspection,
    int idItem,
    int status,
    String auxval,
    String comment,
    String imgUrl,
    int idUs,
  ) async {
    debugPrint(
        'CrearItemInsepeccion: Delegado al backend php en create_inspection.php');
    return 0;
  }

  Future<List<Map<String, dynamic>>> obtenerPlantillasPorUsuarioYVehiculo(
      String idUs, int idVehic) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_templates.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idUs': idUs,
          'idVehic': idVehic,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          List<dynamic> results = data['data'];
          if (results.isEmpty) {
            debugPrint(
                'No se encontraron platillas para el usuario $idUs y vehículo $idVehic');
            return [];
          }
          return results.map((row) {
            return {
              'id': row['id'],
              'name': row['name'],
              'decription': row['decription'],
              'enableStorePhoto': row['enableStorePhoto'],
              'periodicity': row['periodicity'],
              'lastInspectionDate': row['lastInspectionDate']?.toString(),
            };
          }).toList();
        } else {
          debugPrint('Error: ${data['message']}');
          return [];
        }
      } else {
        debugPrint('Error al conectar con el servidor: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error al obtener plantillas: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerInspeccionesPorVehiculo({
    required String idVehic,
    required String idItemTemplate,
  }) async {
    if (idVehic.isEmpty || idItemTemplate.isEmpty) {
      debugPrint('El ID del vehículo o el ID de la plantilla están vacíos.');
      return [];
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_items.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idVehic': idVehic,
          'idItemTemplate': idItemTemplate,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          List<dynamic> results = data['data'];
          if (results.isEmpty) {
            debugPrint(
                'No se encontraron inspecciones para el vehículo $idVehic y el assignment $idItemTemplate.');
            return [];
          }
          return List<Map<String, dynamic>>.from(results);
        } else {
          debugPrint('Error: ${data['message']}');
          return [];
        }
      } else {
        debugPrint('Error al conectar con el servidor: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error al obtener inspecciones por vehículo: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> obtenerUltimaInspeccion(
    String idVehic,
    String idTemplateInspection,
    String idUs,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_last_inspection.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idVehic': idVehic,
          'idTemplateInspection': idTemplateInspection,
          'idUs': idUs,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final row = data['data'];
          if (row != null) {
            return {
              'endDate': DateTime.parse(row['endDate']),
              'startDate': DateTime.parse(row['startDate']),
              'periodicity': row['periodicity'] is int
                  ? row['periodicity']
                  : int.tryParse(row['periodicity'].toString()) ?? 0,
            };
          } else {
            debugPrint(
                'No se encontraron resultados para el vehículo $idVehic, plantilla $idTemplateInspection y usuario $idUs');
            return null;
          }
        } else {
          debugPrint('Error: ${data['message']}');
          return null;
        }
      } else {
        debugPrint('Error al conectar con el servidor: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error al obtener la última inspección: $e');
      return null;
    }
  }
}

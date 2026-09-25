import 'dart:async';
import 'package:mark_v3/services/database_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

//Autor: Josue Hernandez
class StationService {
  final String _baseUrl = '${DatabaseService.apiUrl}/station';

  Future<void> EstacionesDeServicio({
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
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/create_refuel.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'idUs': idUs,
          'idSubAcco': idSubAcco,
          'idVehic': idVehic,
          'odom': double.parse(odom),
          'codeES': int.parse(codeES),
          'typFuel': int.parse(typFuel),
          'datePrice': datePrice.toIso8601String(),
          'priceLts': double.parse(priceLts),
          'lts': lts,
          'dateCreated': dateCreated.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('Datos insertados correctamente en vehic_HistoricalRefuel.');
        } else {
          debugPrint('Error del servidor: ${data['message']}');
        }
      } else {
        debugPrint('Error al conectar con el servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al registrar recarga: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getresupply(String collaboratorId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_resupply.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'collaboratorId': collaboratorId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('Error al obtener datos de vehículo para resupply: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getTypeFuel() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_type_fuel.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('Error al obtener tipos de combustible: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> buscarEstacionCercanaConPrecio(
      double lat, double lng) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_nearest_station.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lat': lat, 'lng': lng}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
    } catch (e) {
      debugPrint('Error al buscar estación cercana: $e');
    }
    return null;
  }
}

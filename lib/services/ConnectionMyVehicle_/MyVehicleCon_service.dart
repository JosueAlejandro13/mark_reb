import 'dart:async';
import 'package:mark_v3/services/database_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

//Autor: Josue Hernandez
class MyvehicleconService {
  final String _baseUrl = '${DatabaseService.apiUrl}/Myvehicles';

  Future<List<Map<String, dynamic>>> getVehiclesByCollaboratorId(
      String collaboratorId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_vehicles.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'collaboratorId': collaboratorId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          debugPrint('Error: ${data['message']}');
          return [];
        }
      } else {
        debugPrint('Error al conectar con el servidor: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error al obtener vehículos: $e');
      return [];
    }
  }

  Future<void> updateVehicleT(
      Map<String, dynamic> vehicleData, String idMainAccount) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/update_vehicle.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vehicleData': vehicleData,
          'idMainAccount': idMainAccount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('Vehículo actualizado y registrado en historial con éxito');
        } else {
          debugPrint('Error del servidor: ${data['message']}');
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error al conectar con el servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al actualizar vehículo: $e');
      rethrow;
    }
  }

  Future<void> updatevehicleStatus(String status, String vehicleId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/update_status.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': status,
          'vehicleId': vehicleId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('Estado del vehículo actualizado. Filas afectadas: ${data['affected']}');
        } else {
          debugPrint('Error del servidor: ${data['message']}');
        }
      } else {
        debugPrint('Error al conectar con el servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al actualizar estado del vehículo: $e');
    }
  }

  Future<List<Map<String, dynamic>>> obtenerModel(int idMake) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_models.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idMake': idMake}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          debugPrint('Error: ${data['message']}');
          return [];
        }
      } else {
        debugPrint('Error al conectar con el servidor: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error al obtener modelos: $e');
      return [];
    }
  }

  // Obtener estatus de inspección
  Future<List<Map<String, dynamic>>> obtenerStatus() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_status.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          debugPrint('Error: ${data['message']}');
          return [];
        }
      } else {
        debugPrint('Error al conectar con el servidor: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error al obtener estatus: $e');
      return [];
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> obtenerCatalogosVehiculo() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_catalogs.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final catalogs = data['data'];
          return {
            'vehicType': List<Map<String, dynamic>>.from(catalogs['vehicType']),
            'vehicFuel': List<Map<String, dynamic>>.from(catalogs['vehicFuel']),
            'vehicStatus': List<Map<String, dynamic>>.from(catalogs['vehicStatus']),
            'engomados': List<Map<String, dynamic>>.from(catalogs['engomados']),
            'make': List<Map<String, dynamic>>.from(catalogs['make']),
            'cobertura': List<Map<String, dynamic>>.from(catalogs['cobertura']),
          };
        } else {
          debugPrint('Error: ${data['message']}');
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error al conectar con el servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al obtener catálogos: $e');
      rethrow;
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:mark_v3/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

//Autor: Josue Hernandez
class RoutesconService {
  final String _baseUrl = '${DatabaseService.apiUrl}/routes';

  Future<List<Map<String, dynamic>>> obtenerIdVehicPorOperador(
      String idOperador) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_vehicle_by_operator.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idOperador': idOperador}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('Error al obtener idvehic: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> obtenerCliente(
      String idClient, String idUser) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_client.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idClient': idClient, 'idUser': idUser}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message']);
        }
      }
    } on TimeoutException {
      throw TimeoutException('El tiempo de espera para la consulta ha expirado');
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> obtenerCapacidadYProductosPorCliente(
      int idClie, String idUs, String idUser) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_client_products.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idClie': idClie,
          'idUs': idUs,
          'idUser': idUser,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('Error al obtener los datos de capacidad y producto: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> obtenerRutasActivasUser(
      String idVehic, String idUs) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_active_routes.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idVehic': idVehic,
          'idUs': idUs,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      rethrow;
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> obtenerRutasPorIdRut(
      int idRut, int idUs) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_route_details.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idRut': idRut,
          'idUs': idUs,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('Error al obtener las rutas y habilidades: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getRouteConfigurationById(int idRoute) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_route_configuration.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idRoute': idRoute}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
    } catch (e) {
      debugPrint('Error al obtener configuracion de ruta: $e');
      rethrow;
    }
    return null;
  }

  Future<void> insertHistoricalJob({
    required int idAssignClients,
    required int idDelivVehic,
    required int idClie,
    required int idRoute,
    required int idPos,
    required DateTime routeDay,
    required DateTime dateCreate,
    required DateTime dateRecord,
    required double dist,
    required int st,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/insert_historical_job.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idAssignClients': idAssignClients,
          'idDelivVehic': idDelivVehic,
          'idClie': idClie,
          'idRoute': idRoute,
          'idPos': idPos,
          'routeDay': routeDay.toIso8601String().split('T').first,
          'dateCreate': dateCreate.toIso8601String(),
          'dateRecord': dateRecord.toIso8601String(),
          'dist': dist,
          'st': st,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('Registro insertado correctamente.');
        } else {
          debugPrint('Error del servidor al insertar en historicaljobs: ${data['message']}');
        }
      }
    } catch (e) {
      debugPrint('Error al insertar en historicaljobs: $e');
    }
  }

  Future<Map<String, dynamic>?> getarriveClient(int idClient, int idRut) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_arrive_client.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idClient': idClient,
          'idRut': idRut,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
    } catch (e) {
      debugPrint('Error al obtener la configuracion de la ruta (arriveClient): $e');
      rethrow;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getConteoTypeandDeliver(int idRut) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_conteo_type_and_deliver.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idRut': idRut}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('Error al obtener la configuracion de la ruta (conteoType): $e');
      rethrow;
    }
    return [];
  }

  Future<Map<String, dynamic>?> getarriveTiempoClient(int idClient) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_arrive_tiempo_client.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idClient': idClient}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
    } catch (e) {
      debugPrint('Error al obtener las fechas de entrega: $e');
      rethrow;
    }
    return null;
  }
}

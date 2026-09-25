import 'dart:async';
import 'package:mark_v3/services/database_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

//Autor: Josue Hernandez
class TrackingconService {
  final String _baseUrl = '${DatabaseService.apiUrl}/tracking';

  Future<List<Map<String, dynamic>>> getDevicesBySubAccount(
      String idSubAccount) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_devices_by_subaccount.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idSubAccount': idSubAccount}),
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
      debugPrint('Error al obtener devices: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerTracking(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_tracking.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
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
      debugPrint('Error al obtener tracking: $e');
      return [];
    }
  }
}

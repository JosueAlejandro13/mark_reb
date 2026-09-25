import 'package:flutter/material.dart';
import 'package:mark_v3/services/RemoteConfigService.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

//Autor: Josue Hernandez
class DatabaseService {
  final RemoteConfigService remoteConfigService = RemoteConfigService();
  bool isConnectionEstablished = false;

  static const String apiUrl = 'http://192.168.1.84/ApiMark_v3';

  Future<dynamic> _post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      // --- AGREGA ESTAS DOS LÍNEAS AQUÍ ---
      debugPrint('========= RESPUESTA DE $endpoint =========');
      debugPrint('Body: ${response.body}');
      // ------------------------------------

      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('Error de servidor en $endpoint: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Excepción en $endpoint: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> authenticateUser(
      String usuario, String password) async {
    if (usuario.isEmpty || password.isEmpty) {
      debugPrint('Usuario o contraseña no pueden estar vacios');
      return {};
    }

    final data = await _post('login.php', {
      'email': usuario,
      'password': password,
    });

    if (data != null && data['success'] == true) {
      final user = data['user'];
      return {
        'id': user['id'].toString(),
        'usuario': user['usuario'],
        'idCollaborator': user['idCollaborator'].toString(),
        'idMainAccount': user['idMainAccount'].toString(),
        'permissions': data['permissions'],
      };
    }
    return {};
  }

  Future<int?> insertTokenFire(
    int userId,
    String token,
    DateTime date,
  ) async {
    final data = await _post('save_fcm_token.php', {
      'userId': userId,
      'token': token,
      'date': date.toIso8601String(),
    });
    if (data != null && data['success'] == true) {
      return data['insertedId'] as int?;
    }
    return null;
  }

  Future<int?> insertAccessRecord(
    int userId,
    String uuid,
    int state,
    DateTime startTime,
    String manufacturer,
    String model,
    String os,
    String ver,
    String lat,
    String lng,
    String acur, {
    int err = 0,
    DateTime? fechorOut,
  }) async {
    final data = await _post('access_records/insert.php', {
      'userId': userId,
      'uuid': uuid,
      'state': state,
      'manufacturer': manufacturer,
      'model': model,
      'os': os,
      'ver': ver,
      'lat': lat,
      'lng': lng,
      'acur': acur,
      'err': err,
    });
    if (data != null && data['success'] == true) {
      return data['insertedId'] as int?;
    }
    return null;
  }

  Future<void> updateAccessRecord(int creationId, String uuid) async {
    await _post('access_records/update_close.php', {
      'creationId': creationId,
      'uuid': uuid,
    });
  }

  Future<void> updateAccessRecordOpen(int creationId, String uuid) async {
    await _post('access_records/update_open.php', {
      'creationId': creationId,
      'uuid': uuid,
    });
  }

  Future<void> enviarOTPSMS(String telefono, int otp) async {
    debugPrint('Enviando OTP $otp al número $telefono');
  }

  Future<Map<String, dynamic>> getUserData(
    int codProducto,
    String idMainAccout,
  ) async {
    final data = await _post('products/get_user_data.php', {
      'codProducto': codProducto,
      'idMainAccount': idMainAccout,
    });
    if (data != null && data['success'] == true) {
      return data['data'];
    }
    throw Exception('Producto no encontrado');
  }
}

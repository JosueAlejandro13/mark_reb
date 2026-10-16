import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Autor: Josue Hernandez
class AuthConService {
  final String _baseUrl = 'https://calenigps.com/markv3.1/ApiMark_v3/auth';

  /// 1. Enviar código de verificación al correo electrónico
  Future<Map<String, dynamic>> sendRecoveryCode(
    String email, {
    bool isResend = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.post(
        Uri.parse('$_baseUrl/recover_password.php'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'email': email.trim(),
          'is_resend': isResend ? '1' : '0',
        }),
      );

      debugPrint('recover_password status: ${response.statusCode}');
      debugPrint('recover_password body: ${response.body}');

      debugPrint(
          '========= [${response.request?.url}] HTTP ${response.statusCode} =========');
      if (response.statusCode != 200) {
        debugPrint('Headers: ${response.request?.headers}');
      }
      debugPrint('Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] == true,
          'message': data['message'] ?? 'Código enviado exitosamente.',
        };
      } else {
        return {
          'success': false,
          'message':
              'Error de conexión con el servidor (${response.statusCode}).',
        };
      }
    } catch (e) {
      debugPrint('Error en sendRecoveryCode: $e');
      return {
        'success': false,
        'message': 'Error de red al enviar el código: $e',
      };
    }
  }

  /// 2. Validar que el código de 6 dígitos sea correcto y esté activo
  Future<Map<String, dynamic>> verifyCode(
    String email,
    String code,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.post(
        Uri.parse('$_baseUrl/verify_code.php'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'email': email.trim(),
          'code': code.trim(),
        }),
      );

      debugPrint('verify_code status: ${response.statusCode}');
      debugPrint('verify_code body: ${response.body}');

      debugPrint(
          '========= [${response.request?.url}] HTTP ${response.statusCode} =========');
      if (response.statusCode != 200) {
        debugPrint('Headers: ${response.request?.headers}');
      }
      debugPrint('Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] == true,
          'message': data['message'] ?? 'Código verificado correctamente.',
        };
      } else {
        return {
          'success': false,
          'message':
              'Error de conexión con el servidor (${response.statusCode}).',
        };
      }
    } catch (e) {
      debugPrint('Error en verifyCode: $e');
      return {
        'success': false,
        'message': 'Error de red al verificar el código: $e',
      };
    }
  }

  /// 3. Actualizar la contraseña del usuario
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.post(
        Uri.parse('$_baseUrl/reset_password.php'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'email': email.trim(),
          'code': code.trim(),
          'newPassword': newPassword,
        }),
      );

      debugPrint('reset_password status: ${response.statusCode}');
      debugPrint('reset_password body: ${response.body}');

      debugPrint(
          '========= [${response.request?.url}] HTTP ${response.statusCode} =========');
      if (response.statusCode != 200) {
        debugPrint('Headers: ${response.request?.headers}');
      }
      debugPrint('Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] == true,
          'message': data['message'] ?? 'Contraseña actualizada con éxito.',
        };
      } else {
        return {
          'success': false,
          'message':
              'Error de conexión con el servidor (${response.statusCode}).',
        };
      }
    } catch (e) {
      debugPrint('Error en resetPassword: $e');
      return {
        'success': false,
        'message': 'Error de red al actualizar la contraseña: $e',
      };
    }
  }
}

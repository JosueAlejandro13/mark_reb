import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mark_v3/services/database_service.dart';

//Autor: Josue Hernandez
class ProfileconService {
  final String _baseUrl = '${DatabaseService.apiUrl}/profile';

  Future<Map<String, dynamic>> getUserData(
      String collaboratorId, String idUs) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_user_data.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'collaboratorId': collaboratorId,
          'idUs': idUs,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error al conectar con el servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al obtener datos del usuario: $e');
      rethrow;
    }
  }

  Future<void> updateUserData({
    required String userId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String mobilPhone,
    required String address,
    required String dateOfBirth,
    required String employeeNum,
    required String idJobTitle,
    required String idMainAccount,
  }) async {
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        phone.isEmpty ||
        mobilPhone.isEmpty ||
        dateOfBirth.isEmpty) {
      debugPrint('Algunos de los campos requeridos están vacíos');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/update_user_data.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
          'mobilPhone': mobilPhone,
          'address': address,
          'dateOfBirth': dateOfBirth,
          'employeeNum': employeeNum,
          'idJobTitle': idJobTitle,
          'idMainAccount': idMainAccount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('Datos del usuario actualizados y registrados en historial con éxito');
        } else {
          debugPrint('Error del servidor: ${data['message']}');
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error al conectar con el servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al actualizar usuario: $e');
      rethrow;
    }
  }

  Future<bool> updatePassword({
    required String usuario,
    required String currentPassword,
    required String newPassword,
    required String idMainAccount,
  }) async {
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      debugPrint('Contraseña actual o nueva están vacíos');
      throw Exception('Uno o más campos requeridos están vacíos');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/update_password.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario': usuario,
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'idMainAccount': idMainAccount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('Contraseña actualizada y registrada en historial con éxito');
          return true;
        } else {
          debugPrint('Error: ${data['message']}');
          return false;
        }
      } else {
        debugPrint('Error al conectar con el servidor: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error al actualizar la contraseña: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> obtenerLicenciaPorColaborador(
      String idCollabo) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get_license.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idCollabo': idCollabo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Licencia no encontrada para el colaborador con ID: $idCollabo');
        }
      } else {
        throw Exception('Error al conectar con el servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al obtener licencia: $e');
      rethrow;
    }
  }

  Future<void> agregarNuevaLicencia(Map<String, dynamic> licenciaData) async {
    try {
      String dueDateString;
      if (licenciaData['dueDate'] is DateTime) {
        dueDateString = (licenciaData['dueDate'] as DateTime).toIso8601String();
      } else if (licenciaData['dueDate'] is String) {
        dueDateString = licenciaData['dueDate'];
      } else {
        throw Exception('El campo dueDate debe ser de tipo DateTime o String');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/add_license.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idCollaborator': licenciaData['idCollaborator'],
          'licNum': licenciaData['licNum'],
          'licClass': licenciaData['licClass'],
          'dueDate': dueDateString,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('Nueva licencia insertada con ID: ${data['insertedId']}');
        } else {
          debugPrint('Error del servidor: ${data['message']}');
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Error al conectar con el servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al agregar la nueva licencia: $e');
      rethrow;
    }
  }
}

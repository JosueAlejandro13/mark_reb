import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:mark_v3/services/mark_api_client.dart';

/// Servicio de Perfil y Licencia migrado a Mark V3.1 (api.php?a=perfil)
class ProfileconService {
  final MarkApiClient _client = MarkApiClient.instance;

  /// Obtener datos del perfil del colaborador logueado y su licencia
  Future<Map<String, dynamic>> getUserData(
    String collaboratorId,
    String idUs,
  ) async {
    try {
      final res = await _client.getPerfil();
      if (res['ok'] == false && res['error'] != null) {
        throw Exception(res['error']);
      }

      final colaborador = res['colaborador'] is Map<String, dynamic>
          ? res['colaborador'] as Map<String, dynamic>
          : <String, dynamic>{};

      final licencia = res['licencia'] is Map<String, dynamic>
          ? res['licencia'] as Map<String, dynamic>
          : <String, dynamic>{};

      final nombreServidor = (colaborador['nombre'] ?? '').toString().trim();
      final apellidoServidor =
          (colaborador['apellido'] ?? '').toString().trim();

      String firstName = nombreServidor;
      String lastName = apellidoServidor;

      if (lastName.isEmpty && firstName.contains(' ')) {
        final partes = firstName.split(' ');
        firstName = partes.first;
        lastName = partes.sublist(1).join(' ');
      }

      final nombreCompleto = '$firstName $lastName'.trim();
      final emailValue = (colaborador['email'] ??
              res['correoUsuario'] ??
              colaborador['correo'] ??
              '')
          .toString()
          .trim();
      final jobTitleValue =
          (colaborador['puesto'] ?? 'Colaborador').toString().trim();
      final dateBirthValue =
          (colaborador['nacimiento'] ?? '').toString().trim();
      final phoneValue = (colaborador['telefono'] ?? '').toString().trim();
      final mobilValue =
          (colaborador['celular'] ?? phoneValue).toString().trim();
      final addressValue = (colaborador['direccion'] ?? '').toString().trim();
      final employeeNumValue =
          (colaborador['numEmpleado'] ?? '').toString().trim();

      String rawFoto = (colaborador['foto'] ?? '').toString().trim();
      String fotoUrl = rawFoto.isNotEmpty ? _client.resolveAssetUrl(rawFoto) : '';

      return {
        'id': colaborador['id'] ?? collaboratorId,
        'firstName': firstName,
        'FirstName': firstName,
        'lastName': lastName,
        'LastName': lastName,
        'name': nombreCompleto,
        'nombre': nombreCompleto,
        'apellido': lastName,
        'email': emailValue,
        'correo': emailValue,
        'phone': phoneValue,
        'telefono': phoneValue,
        'mobilPhone': mobilValue,
        'celular': mobilValue,
        'jobTitle': jobTitleValue,
        'idJobTitle': jobTitleValue,
        'puesto': jobTitleValue,
        'address': addressValue,
        'direccion': addressValue,
        'photo': fotoUrl,
        'foto': fotoUrl,
        'dateOfBirth': dateBirthValue,
        'dateBirth': dateBirthValue,
        'nacimiento': dateBirthValue,
        'employeeNum': employeeNumValue,
        'numEmpleado': employeeNumValue,
        'puedeEditar': res['puedeEditar'] == true,
        // Datos de licencia integrados
        'licNum': licencia['numero'] ?? '',
        'licClass': licencia['clase'] ?? '',
        'dueDate': licencia['vence'] ?? '',
        'semaforo': licencia['semaforo'] ?? 'vigente',
        'fotosLicencia': licencia['fotos'] ?? [],
      };
    } catch (e) {
      debugPrint('Error en ProfileconService.getUserData: $e');
      rethrow;
    }
  }

  /// Actualizar datos del usuario (envía acción tipo perfil a la API)
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
    String? photoUuid,
  }) async {
    try {
      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'perfil',
          'nombre': firstName.trim(),
          'apellido': lastName.trim(),
          'email': email.trim(),
          'telefono': phone.trim(),
          'celular': mobilPhone.trim(),
          'direccion': address.trim(),
          'nacimiento': dateOfBirth.trim(),
          if (photoUuid != null && photoUuid.isNotEmpty) 'foto': photoUuid,
          'fecHor': DateTime.now()
              .toIso8601String()
              .replaceFirst('T', ' ')
              .substring(0, 19),
        }
      ];

      final res = await _client.sendActions(acciones);
      debugPrint('Resultado updateUserData via a=acciones: $res');
      if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
        final avisos = res.first['avisos'] as List? ?? [];
        final errorTexto = avisos.isNotEmpty
            ? avisos.first['texto']?.toString()
            : 'Acción rechazada por el servidor.';
        throw Exception(errorTexto);
      }
    } catch (e) {
      debugPrint('Error al actualizar datos de usuario: $e');
      rethrow;
    }
  }

  /// Subir y actualizar la fotografía de perfil en el servidor
  Future<String> updateProfilePhoto(String filePath) async {
    final photoUuid = const Uuid().v4();
    final ok = await _client.uploadPhoto(
      uuid: photoUuid,
      tipo: 1, // 1 = foto
      filePath: filePath,
    );
    if (!ok) {
      throw Exception('No se pudo subir la fotografía al servidor.');
    }

    final acciones = [
      {
        'uuid': const Uuid().v4(),
        'tipo': 'perfil',
        'foto': photoUuid,
        'fecHor': DateTime.now()
            .toIso8601String()
            .replaceFirst('T', ' ')
            .substring(0, 19),
      }
    ];

    final res = await _client.sendActions(acciones);
    debugPrint('Resultado updateProfilePhoto via a=acciones: $res');
    if (res.isNotEmpty &&
        (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
      final avisos = res.first['avisos'] as List? ?? [];
      final errorTexto = avisos.isNotEmpty
          ? avisos.first['texto']?.toString()
          : 'Error al actualizar la foto de perfil en el servidor.';
      throw Exception(errorTexto);
    }
    return photoUuid;
  }

  /// Cambiar contraseña (a=cambiarPassword)
  Future<bool> updatePassword({
    required String usuario,
    required String currentPassword,
    required String newPassword,
    required String idMainAccount,
    String? userId,
    bool cerrarOtras = true,
  }) async {
    try {
      final res = await _client.cambiarPassword(
        passwordActual: currentPassword,
        passwordNuevo: newPassword,
        cerrarOtras: cerrarOtras,
      );
      return res['ok'] == true;
    } catch (e) {
      debugPrint('Error en ProfileconService.updatePassword: $e');
      rethrow;
    }
  }

  /// Obtener licencia del colaborador actual (extraída desde a=perfil)
  Future<Map<String, dynamic>> obtenerLicenciaPorColaborador(
    String idCollabo,
  ) async {
    try {
      final res = await _client.getPerfil();
      final licencia = res['licencia'];
      final session = _client.currentSession;
      final rol = session?.rol.toLowerCase().trim() ?? '';
      final isPreventa = session?.isPreventa == true || rol == 'preventa' || rol == 'vendedor';

      final bool puedeEditar = !isPreventa && (res['puedeEditar'] == true);

      if (licencia is Map<String, dynamic> &&
          licencia.isNotEmpty &&
          (licencia['numero'] != null &&
              licencia['numero'].toString().trim().isNotEmpty)) {
        return {
          'id': licencia['id'] ?? idCollabo,
          'licNum': licencia['numero'] ?? '',
          'licClass': licencia['clase'] ?? '',
          'dueDate': licencia['vence'] ?? '',
          'semaforo': licencia['semaforo'] ?? 'vigente',
          'fotos': licencia['fotos'] ?? [],
          'puedeEditar': puedeEditar,
        };
      }
      return <String, dynamic>{
        'puedeEditar': puedeEditar,
      };
    } catch (e) {
      debugPrint('Error al obtener licencia: $e');
      return <String, dynamic>{};
    }
  }

  /// Agregar o renovar licencia (envía acción tipo licencia a la API)
  Future<void> agregarNuevaLicencia(Map<String, dynamic> licenciaData) async {
    try {
      String dueDateString;
      if (licenciaData['dueDate'] is DateTime) {
        dueDateString = (licenciaData['dueDate'] as DateTime)
            .toIso8601String()
            .substring(0, 10);
      } else {
        final raw = licenciaData['dueDate'].toString();
        dueDateString = raw.length >= 10 ? raw.substring(0, 10) : raw;
      }

      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'licencia',
          'numero': (licenciaData['licNum'] ?? '').toString().trim(),
          'clase': (licenciaData['licClass'] ?? '').toString().trim(),
          'vence': dueDateString,
          'fotos': licenciaData['fotos'] ?? [],
          'fecHor': DateTime.now()
              .toIso8601String()
              .replaceFirst('T', ' ')
              .substring(0, 19),
        }
      ];

      final res = await _client.sendActions(acciones);
      debugPrint('Resultado agregarNuevaLicencia via a=acciones: $res');
      if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
        final avisos = res.first['avisos'] as List? ?? [];
        final errorTexto = avisos.isNotEmpty
            ? avisos.first['texto']?.toString()
            : 'Acción rechazada por el servidor.';
        throw Exception(errorTexto);
      }
    } catch (e) {
      debugPrint('Error al agregar nueva licencia: $e');
      rethrow;
    }
  }
}

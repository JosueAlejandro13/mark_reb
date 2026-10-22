import 'package:flutter/material.dart';
import 'package:mark_v3/services/mark_api_client.dart';

// Autor: Josue Hernandez
class AuthConService {
  final MarkApiClient _client = MarkApiClient.instance;

  // Guarda temporalmente el resetToken del último código verificado exitosamente (Ronda 144)
  static String? lastResetToken;

  /// 1. Enviar código de verificación al correo electrónico (a=recuperarPassword)
  Future<Map<String, dynamic>> sendRecoveryCode(
    String email, {
    bool isResend = false,
  }) async {
    try {
      final res = await _client.recuperarPassword(email);
      final ok = res['ok'] == true;
      return {
        'success': ok,
        'message': res['mensaje'] ??
            (ok
                ? 'Código enviado exitosamente a tu correo.'
                : (res['error'] ?? 'Error al solicitar recuperación.')),
        'vigenciaMin': res['vigenciaMin'] ?? 15,
      };
    } catch (e) {
      debugPrint('Error en sendRecoveryCode: $e');
      final msg = e is MarkApiException ? e.message : 'Error de conexión: $e';
      return {
        'success': false,
        'message': msg,
      };
    }
  }

  /// 2. Validar que el código de 6 dígitos sea correcto y obtener resetToken (a=verificarCodigoRecuperacion)
  Future<Map<String, dynamic>> verifyCode(
    String email,
    String code,
  ) async {
    try {
      final res = await _client.verificarCodigoRecuperacion(
        usuarioOCorreo: email,
        codigo: code,
      );
      final ok = res['ok'] == true;
      final token = res['resetToken']?.toString();
      if (ok && token != null && token.isNotEmpty) {
        lastResetToken = token;
      }
      return {
        'success': ok,
        'resetToken': token,
        'message': res['mensaje'] ??
            (ok
                ? 'Código verificado correctamente.'
                : (res['error'] ?? 'Código incorrecto o expirado.')),
      };
    } catch (e) {
      debugPrint('Error en verifyCode: $e');
      final msg =
          e is MarkApiException ? e.message : 'Error de verificación: $e';
      return {
        'success': false,
        'message': msg,
      };
    }
  }

  /// 3. Actualizar la contraseña del usuario mediante el resetToken (a=restablecerPassword)
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
    String? resetToken,
  }) async {
    try {
      String? token = resetToken ?? lastResetToken;
      // Si no tenemos el token en memoria, re-verificamos con el código
      if ((token == null || token.isEmpty) &&
          email.isNotEmpty &&
          code.isNotEmpty) {
        final verifyRes = await _client.verificarCodigoRecuperacion(
          usuarioOCorreo: email,
          codigo: code,
        );
        if (verifyRes['ok'] == true && verifyRes['resetToken'] != null) {
          token = verifyRes['resetToken'].toString();
          lastResetToken = token;
        } else {
          return {
            'success': false,
            'message':
                verifyRes['error'] ?? 'El código ha expirado o no es válido.',
          };
        }
      }

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message':
              'Token de restablecimiento no disponible. Por favor ingresa el código nuevamente.',
        };
      }

      final res = await _client.restablecerPassword(
        resetToken: token,
        passwordNuevo: newPassword,
      );
      final ok = res['ok'] == true;
      if (ok) {
        lastResetToken = null;
      }
      return {
        'success': ok,
        'message': res['mensaje'] ??
            (ok
                ? 'Contraseña actualizada con éxito.'
                : (res['error'] ?? 'No se pudo actualizar la contraseña.')),
        'sesionesCerradas': res['sesionesCerradas'],
      };
    } catch (e) {
      debugPrint('Error en resetPassword: $e');
      final msg =
          e is MarkApiException ? e.message : 'Error al actualizar contraseña: $e';
      return {
        'success': false,
        'message': msg,
      };
    }
  }
}

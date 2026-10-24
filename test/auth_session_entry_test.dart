import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/services/mark_api_client.dart';

void main() {
  group('Pruebas de Entrada y Registro de Sesión (Mark V3.1)', () {
    test('Parseo de sesión exitosa con rol chofer y permisos de flota', () {
      final jsonResponse = {
        'ok': true,
        'token': 'mock_token_abc_123',
        'rol': 'chofer',
        'usuario': {
          'id': 105,
          'nombre': 'Josue Chofer',
          'idCuenta': 1,
          'idColaborador': 45,
        },
        'chofer': {
          'id': 45,
          'nombre': 'Josue Chofer',
        },
        'flota': {
          'vehiculo': {'ver': true, 'crear': false, 'editar': false},
          'inspeccion': {'ver': true, 'crear': true},
          'combustible': {'ver': true, 'crear': true},
          'tarjeta': {'ver': true, 'crear': false, 'editar': false},
        },
        'permisos': {
          'pedidos': false,
          'cobranza': false,
        },
        'demo': false,
      };

      final session = DriverSession.fromJson(jsonResponse);

      expect(session.token, equals('mock_token_abc_123'));
      expect(session.rol, equals('chofer'));
      expect(session.isChofer, isTrue);
      expect(session.isPreventa, isFalse);
      expect(session.isSoloFlota, isFalse);
      expect(session.usuario.id, equals(105));
      expect(session.chofer.id, equals(45));
      expect(session.flota.can('inspeccion', 'crear'), isTrue);
      expect(session.flota.can('combustible', 'crear'), isTrue);
    });

    test('Parseo de sesión con rol usuario (supervisor / taller)', () {
      final jsonResponse = {
        'ok': true,
        'token': 'mock_token_usuario_456',
        'rol': 'usuario',
        'usuario': {
          'id': 201,
          'nombre': 'Supervisor Flota',
          'idCuenta': 1,
          'idColaborador': 0,
        },
        'chofer': {
          'id': 0,
          'nombre': '',
        },
        'flota': {
          'vehiculo': {'ver': true, 'crear': true, 'editar': true},
          'inspeccion': {'ver': true, 'crear': true},
          'combustible': {'ver': true, 'crear': true},
        },
        'permisos': {
          'pedidos': false,
          'cobranza': false,
        },
        'demo': false,
      };

      final session = DriverSession.fromJson(jsonResponse);

      expect(session.rol, equals('usuario'));
      expect(session.isSoloFlota, isTrue);
      expect(session.isChofer, isFalse);
      expect(session.flota.can('vehiculo', 'editar'), isTrue);
    });

    test('Manejo de LoginAuthResult para 2FA requerido (Ronda 134)', () {
      final challengeJson = {
        'ok': false,
        'dosPasos': true,
        'desafio': 'desafio_token_789',
        'enviado': 'correo',
        'correo': 'j***@gmail.com',
        'vigenciaMin': 10,
      };

      final challenge = Login2FaChallenge.fromJson(challengeJson);
      final result = LoginAuthResult.twoFactor(challenge);

      expect(result.isSuccess, isFalse);
      expect(result.isTwoFactorRequired, isTrue);
      expect(result.challenge?.desafio, equals('desafio_token_789'));
      expect(result.challenge?.enviado, equals('correo'));
      expect(result.challenge?.correo, equals('j***@gmail.com'));
    });

    test('Manejo de LoginAuthResult para error de credenciales', () {
      final result = LoginAuthResult.error('Usuario o contraseña incorrectos.');

      expect(result.isSuccess, isFalse);
      expect(result.isTwoFactorRequired, isFalse);
      expect(result.errorMessage, equals('Usuario o contraseña incorrectos.'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';

void main() {
  group('Módulo de Rutas: Cola Offline y Acciones Pendientes', () {
    test('Creación de QueuedAction para llegada con distancia manual', () {
      final action = QueuedAction(
        uuid: 'uuid-12345',
        tipo: 'llegada',
        idRuta: 10,
        idParada: 3,
        payload: {
          'distanciaLlegada': '3.4 km',
        },
        createdAt: DateTime.now().toIso8601String(),
      );

      expect(action.tipo, equals('llegada'));
      expect(action.idRuta, equals(10));
      expect(action.idParada, equals(3));
      expect(action.payload['distanciaLlegada'], equals('3.4 km'));
      expect(action.status, equals('pending'));
      expect(action.requiredPhotoUuids, isEmpty);
    });

    test('Extracción de requiredPhotoUuids para acciones que requieren fotos o firma', () {
      final actionConFotos = QueuedAction(
        uuid: 'uuid-fotos-789',
        tipo: 'entrega',
        idRuta: 10,
        idParada: 3,
        payload: {
          'idGuia': 21114,
          'fotos': ['foto-uuid-1', 'foto-uuid-2'],
          'firma': 'firma-uuid-3',
        },
        createdAt: DateTime.now().toIso8601String(),
      );

      final photos = actionConFotos.requiredPhotoUuids;
      expect(photos.length, equals(3));
      expect(photos, contains('foto-uuid-1'));
      expect(photos, contains('foto-uuid-2'));
      expect(photos, contains('firma-uuid-3'));
    });

    test('Serialización y deserialización desde base de datos local SQLite (fromDbMap)', () {
      final dbRow = {
        'id': 1,
        'uuid': 'uuid-db-456',
        'tipo': 'recojo',
        'id_ruta': 10,
        'id_parada': 2,
        'payload_json': '{"idGuia":105,"bultos":3}',
        'status': 'pending',
        'avisos_json': '[]',
        'retry_count': 0,
        'created_at': '2026-10-27T10:00:00.000',
      };

      final action = QueuedAction.fromDbMap(dbRow);

      expect(action.uuid, equals('uuid-db-456'));
      expect(action.tipo, equals('recojo'));
      expect(action.idRuta, equals(10));
      expect(action.idParada, equals(2));
      expect(action.payload['idGuia'], equals(105));
      expect(action.payload['bultos'], equals(3));
      expect(action.status, equals('pending'));
    });

    test('Manejo de rechazo de acción: status rejected con avisos de servidor', () {
      final dbRowRechazada = {
        'id': 2,
        'uuid': 'uuid-rejected-999',
        'tipo': 'fin',
        'id_ruta': 10,
        'id_parada': null,
        'payload_json': '{"confirmarDiferencia":false}',
        'status': 'rejected',
        'avisos_json': '[{"nivel":"error","codigo":"VISITAS_PENDIENTES","texto":"Hay 2 paradas sin visitar."}]',
        'retry_count': 1,
        'created_at': '2026-10-27T11:00:00.000',
      };

      final action = QueuedAction.fromDbMap(dbRowRechazada);

      expect(action.status, equals('rejected'));
      expect(action.avisos.length, equals(1));
      expect(action.avisos.first.codigo, equals('VISITAS_PENDIENTES'));
      expect(action.avisos.first.texto, contains('paradas sin visitar'));
    });
  });
}

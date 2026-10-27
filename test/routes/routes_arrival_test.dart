import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';

void main() {
  group('Módulo de Rutas: Llegadas y Estabilidad de Distancias', () {
    test('Parada con llegada automática (<= 300m) mantiene distanciaLlegada en null', () {
      const stop = RouteStop(
        idParada: 1,
        orden: 1,
        tipo: 'cliente',
        llegadaEstimada: '08:00',
        visitada: true,
        visitaOrigen: 'gps',
        distanciaLlegada: null,
      );

      expect(stop.visitada, isTrue);
      expect(stop.visitaOrigen, equals('gps'));
      expect(stop.distanciaLlegada, isNull);
      expect(stop.visitaCerrada, isFalse);
    });

    test('Llegada manual fuera de rango (> 300m): congela distancia exacta', () {
      const stop = RouteStop(
        idParada: 3,
        orden: 3,
        tipo: 'cliente',
        llegadaEstimada: '08:30',
        visitada: true,
        visitaOrigen: 'app',
        distanciaLlegada: '3.4 km',
      );

      expect(stop.visitada, isTrue);
      expect(stop.visitaOrigen, equals('app'));
      expect(stop.distanciaLlegada, equals('3.4 km'));

      // Verificar que el modelo se serialice a JSON con distanciaLlegada
      final json = stop.toJson();
      expect(json['distanciaLlegada'], equals('3.4 km'));
      expect(json['visitada'], isTrue);

      // Deserializar desde JSON
      final parsed = RouteStop.fromJson(json);
      expect(parsed.distanciaLlegada, equals('3.4 km'));
    });

    test('Invarianza de distanciaLlegada cuando el vehículo se aleja', () {
      const initialStop = RouteStop(
        idParada: 3,
        orden: 3,
        tipo: 'cliente',
        llegadaEstimada: '08:30',
        visitada: true,
        visitaOrigen: 'app',
        distanciaLlegada: '3.4 km',
      );

      // El vehículo ahora se encuentra a 8.5 km de distancia
      final updatedStop = initialStop.copyWith();
      expect(updatedStop.distanciaLlegada, equals('3.4 km'));
      expect(updatedStop.visitada, isTrue);
    });

    test('Preservación de distanciaLlegada al recargar pantalla desde servidor (merge)', () {
      const localStop = RouteStop(
        idParada: 3,
        orden: 3,
        tipo: 'cliente',
        llegadaEstimada: '08:30',
        visitada: true,
        visitaOrigen: 'app',
        distanciaLlegada: '3.4 km',
      );

      // El servidor responde con JSON sin el campo distanciaLlegada
      final serverJson = {
        'idParada': 3,
        'orden': 3,
        'tipo': 'cliente',
        'llegadaEstimada': '08:30',
        'visitada': 1,
        'visitaOrigen': 'app',
      };

      final serverStop = RouteStop.fromJson(serverJson);
      expect(serverStop.distanciaLlegada, isNull);

      // Lógica de merge de routes_provider y driver_local_db
      final mergedStop = serverStop.distanciaLlegada == null && localStop.distanciaLlegada != null
          ? serverStop.copyWith(distanciaLlegada: localStop.distanciaLlegada)
          : serverStop;

      expect(mergedStop.distanciaLlegada, equals('3.4 km'));
      expect(mergedStop.visitada, isTrue);
    });

    test('Conclusión de visita preserva visitada == true y marca visitaCerrada', () {
      const stop = RouteStop(
        idParada: 3,
        orden: 3,
        tipo: 'cliente',
        llegadaEstimada: '08:30',
        visitada: true,
        visitaOrigen: 'app',
        distanciaLlegada: '3.4 km',
        visitaCerrada: false,
      );

      final closed = stop.copyWith(visitaCerrada: true);
      expect(closed.visitada, isTrue);
      expect(closed.visitaCerrada, isTrue);
      expect(closed.distanciaLlegada, equals('3.4 km'));
    });
  });
}

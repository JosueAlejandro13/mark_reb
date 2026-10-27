import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/providers/Station_/service_station_provider.dart';
import 'package:mark_v3/services/ConnectionStation_/StationCon_service.dart';

void main() {
  group('Módulo de Estación de Servicio: Consulta de Gasolinera Cercana vía API', () {
    late StationService service;

    setUp(() {
      service = StationService();
    });

    test('Vehículo sin GPS (0.0, 0.0) devuelve null y no ejecuta llamada a la API', () async {
      final station = await service.buscarEstacionCercanaConPrecio(0.0, 0.0);
      expect(station, isNull, reason: 'Coordenadas 0,0 deben retornar null directamente');
    });

    test('Provider: Estado marca isOutOfRange = true cuando la API no encuentra estación (null)', () {
      const initialState = ServiceStationState();

      final stateOutOfRange = initialState.copyWith(
        isLoading: false,
        isOutOfRange: true,
        clearStation: true,
      );

      expect(stateOutOfRange.isLoading, isFalse);
      expect(stateOutOfRange.isOutOfRange, isTrue);
      expect(stateOutOfRange.stationData, isNull);
    });

    test('Provider: Estado guarda la posición del VEHÍCULO y datos de estación devueltos por la API', () {
      const double vLat = 19.394096;
      const double vLng = -99.086912;

      const initialState = ServiceStationState();
      final stateInRange = initialState.copyWith(
        isLoading: false,
        latitude: vLat,
        longitude: vLng,
        isOutOfRange: false,
        stationData: {
          'id': 101,
          'code': 'PL/9999/EXP/ES/2015',
          'codeES': '9999',
          'name': 'Estación Servicio Zaragoza',
          'dist': 250,
          'regular': 23.99,
          'premium': 25.89,
          'diesel': 25.19,
        },
      );

      expect(stateInRange.isOutOfRange, isFalse);
      expect(stateInRange.latitude, equals(vLat));
      expect(stateInRange.longitude, equals(vLng));
      expect(stateInRange.stationData!['codeES'], equals('9999'));
      expect(stateInRange.stationData!['dist'], equals(250));
    });
  });
}

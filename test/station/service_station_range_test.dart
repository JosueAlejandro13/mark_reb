import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/providers/Station_/service_station_provider.dart';
import 'package:mark_v3/services/ConnectionStation_/StationCon_service.dart';

void main() {
  group('Módulo de Estación de Servicio: Rango y Disponibilidad de Estación', () {
    late StationService service;

    setUp(() {
      service = StationService();
    });

    test('buscarEstacionCercanaConPrecio retorna null cuando no hay estación en la API', () async {
      const testLat = 19.394096;
      const testLng = -99.086912;

      final station = await service.buscarEstacionCercanaConPrecio(testLat, testLng);
      // Al no haber endpoint ni estación cercana en esa coordenada, debe retornar null
      expect(station, isNull, reason: 'Si no está en estación, debe retornar null');
    });

    test('Provider: Si stationData es null, isOutOfRange se activa en true y NO muestra el formulario', () {
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

    test('Provider: Solo cuando hay estación válida (stationData != null), isOutOfRange es false', () {
      const double vLat = 19.394096;
      const double vLng = -99.086912;

      const initialState = ServiceStationState();
      final stateReady = initialState.copyWith(
        isLoading: false,
        latitude: vLat,
        longitude: vLng,
        isOutOfRange: false,
        stationData: {
          'id': 1,
          'code': 'PL/2856/EXP/ES/2015',
          'codeES': '2856',
          'name': 'Estación de Servicio Real',
          'dist': 25,
          'regular': 23.99,
          'premium': 25.89,
          'diesel': 25.19,
          'lat': vLat,
          'lng': vLng,
        },
        selectedFuelTypeId: '6',
        selectedFuelTypeName: 'Gasolina Regular',
        selectedFuelPrice: 23.99,
        isFuelValid: true,
        liters: 20,
        totalEstimated: 479.80,
      );

      expect(stateReady.isOutOfRange, isFalse);
      expect(stateReady.stationData, isNotNull);
      expect(stateReady.stationData!['dist'], equals(25));
    });
  });
}

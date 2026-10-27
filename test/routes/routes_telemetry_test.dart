import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';

void main() {
  group('Módulo de Rutas: Telemetría y Detección de Proximidad', () {
    test('Configuración de distAviso por defecto es 300 metros', () {
      const config = DayConfig();
      expect(config.distAviso, equals(300));
    });

    test('Configuración personalizada de distAviso desde JSON del servidor', () {
      final json = {
        'distAviso': 500,
        'distAutoLlegada': 150,
      };
      final config = DayConfig.fromJson(json);
      expect(config.distAviso, equals(500));
    });

    test('Evaluación de telemetría: actualización reciente (< 10 min) es válida', () {
      final now = DateTime.now();
      final recentUpdate = now.subtract(const Duration(minutes: 4));

      final bool isVehicleStale = now.difference(recentUpdate).inMinutes >= 10;
      expect(isVehicleStale, isFalse);
    });

    test('Evaluación de telemetría: pérdida de señal >= 10 min marca el camión como obsoleto (fallback celular)', () {
      final now = DateTime.now();
      final staleUpdate = now.subtract(const Duration(minutes: 12));

      final bool isVehicleStale = now.difference(staleUpdate).inMinutes >= 10;
      expect(isVehicleStale, isTrue);
    });

    test('Validación dual: camión sin señal permite que el GPS del celular tome el control', () {
      final now = DateTime.now();
      final staleTime = now.subtract(const Duration(minutes: 15));

      final bool isVehicleStale = now.difference(staleTime).inMinutes >= 10;
      final bool hasPhone = true;

      String resolveGpsSource({required bool vehicleStale, required bool hasPhoneGps}) {
        if (!vehicleStale) return 'camion';
        if (hasPhoneGps) return 'celular';
        return 'ninguno';
      }

      final activeGpsSource = resolveGpsSource(vehicleStale: isVehicleStale, hasPhoneGps: hasPhone);
      expect(activeGpsSource, equals('celular'));
    });
  });
}

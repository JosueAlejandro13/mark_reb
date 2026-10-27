import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';

void main() {
  group('Módulo de Rutas: Ciclo de Vida y Estados Operacionales', () {
    test('Estado inicial de ruta: Programada (operationalRoute == 0)', () {
      const route = DriverRoute(
        idRuta: 10,
        nombre: 'Ruta CDMX Centro',
        modalidad: 1,
        operacional: false,
        operationalRoute: 0,
      );

      expect(route.isProgramada, isTrue);
      expect(route.isActiva, isFalse);
      expect(route.isFinalizada, isFalse);
      expect(route.operationalStatusText, equals('POR SALIR'));
    });

    test('Acción salida: Pasa la ruta de programada (0) a activa (1)', () {
      const route = DriverRoute(
        idRuta: 10,
        nombre: 'Ruta CDMX Centro',
        operacional: false,
        operationalRoute: 0,
      );

      final activeRoute = route.copyWith(
        operacional: true,
        operationalRoute: 1,
      );

      expect(activeRoute.isProgramada, isFalse);
      expect(activeRoute.isActiva, isTrue);
      expect(activeRoute.isFinalizada, isFalse);
      expect(activeRoute.operationalStatusText, equals('OPERATIVA'));
    });

    test('Salida repetida no debe reabrir una ruta ya terminada (2 o 3)', () {
      const finishedRoute = DriverRoute(
        idRuta: 10,
        nombre: 'Ruta CDMX Centro',
        operacional: false,
        operationalRoute: 2,
      );

      expect(finishedRoute.isFinalizada, isTrue);

      // Si la ruta está finalizada, la acción de salida debe ignorarse y mantener su estado
      final resultingRoute = finishedRoute.isFinalizada
          ? finishedRoute
          : finishedRoute.copyWith(operacional: true, operationalRoute: 1);

      expect(resultingRoute.operationalRoute, equals(2));
      expect(resultingRoute.isFinalizada, isTrue);
    });

    test('Acción fin con confirmación de diferencia: Marca la ruta como terminada (2)', () {
      const activeRoute = DriverRoute(
        idRuta: 10,
        nombre: 'Ruta CDMX Centro',
        operacional: true,
        operationalRoute: 1,
      );

      final finishedRoute = activeRoute.copyWith(
        operacional: false,
        operationalRoute: 2,
      );

      expect(finishedRoute.isActiva, isFalse);
      expect(finishedRoute.isTerminada, isTrue);
      expect(finishedRoute.isFinalizada, isTrue);
      expect(finishedRoute.operationalStatusText, equals('TERMINADA'));
    });

    test('Ruta cerrada por motor con pendientes: operationalRoute == 3', () {
      const route = DriverRoute(
        idRuta: 10,
        nombre: 'Ruta CDMX Centro',
        operacional: false,
        operationalRoute: 3,
      );

      expect(route.isCerradaPorMotor, isTrue);
      expect(route.isFinalizada, isTrue);
      expect(route.operationalStatusText, equals('CERRADA'));
    });

    test('Rechazo de fin por VISITAS_PENDIENTES: Revierte ruta a estado activa (1)', () {
      // Estado antes del intento de terminar
      const activeRoute = DriverRoute(
        idRuta: 10,
        nombre: 'Ruta CDMX Centro',
        operacional: true,
        operationalRoute: 1,
      );

      // Simular que el servidor rechazó el fin por paradas sin visitar
      DriverRoute revertFin(DriverRoute route, bool wasRejected) {
        if (wasRejected) {
          return route.copyWith(operacional: true, operationalRoute: 1);
        }
        return route.copyWith(operacional: false, operationalRoute: 2);
      }

      final finalRoute = revertFin(activeRoute, true);

      expect(finalRoute.operacional, isTrue);
      expect(finalRoute.operationalRoute, equals(1));
      expect(finalRoute.isActiva, isTrue);
    });
  });
}

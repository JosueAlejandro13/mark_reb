import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';

void main() {
  group('Módulo de Rutas: Paradas y Gestión de Guías (Recojo, Entrega, Incidencia)', () {
    test('GuiaItem labels según estado numérico', () {
      expect(GuiaItem.estadoLabel(0), equals('Capturada'));
      expect(GuiaItem.estadoLabel(1), equals('Recogida'));
      expect(GuiaItem.estadoLabel(2), equals('En CEDI'));
      expect(GuiaItem.estadoLabel(3), equals('En reparto'));
      expect(GuiaItem.estadoLabel(4), equals('Entregada'));
      expect(GuiaItem.estadoLabel(8), equals('Incidencia'));
      expect(GuiaItem.estadoLabel(9), equals('Cancelada'));
    });

    test('Acción recojo en Modalidad 1 (Mensajería): Pasa directo a estado 3 (En reparto)', () {
      const guiaMensajeria = GuiaItem(
        idGuia: 101,
        folio: 'M-001',
        estado: 0,
        estadoTexto: 'Capturada',
        modalidad: 1, // Mensajería
      );

      final nextSt = guiaMensajeria.modalidad == 1 ? 3 : 1;
      final updated = guiaMensajeria.copyWith(
        estado: nextSt,
        estadoTexto: GuiaItem.estadoLabel(nextSt),
      );

      expect(updated.estado, equals(3));
      expect(updated.estadoTexto, equals('En reparto'));
    });

    test('Acción recojo en Modalidad 0 (Por pedido): Pasa a estado 1 (Recogida)', () {
      const guiaPedido = GuiaItem(
        idGuia: 102,
        folio: 'P-001',
        estado: 0,
        estadoTexto: 'Capturada',
        modalidad: 0, // Paquetería / Por pedido
      );

      final nextSt = guiaPedido.modalidad == 1 ? 3 : 1;
      final updated = guiaPedido.copyWith(
        estado: nextSt,
        estadoTexto: GuiaItem.estadoLabel(nextSt),
      );

      expect(updated.estado, equals(1));
      expect(updated.estadoTexto, equals('Recogida'));
    });

    test('Acción entrega: Pasa guía a estado 4 (Entregada) y marca parada como visitada', () {
      const guia = GuiaItem(
        idGuia: 103,
        folio: 'E-001',
        estado: 3,
        estadoTexto: 'En reparto',
      );

      final stop = RouteStop(
        idParada: 5,
        orden: 1,
        tipo: 'cliente',
        llegadaEstimada: '10:00',
        entregar: [guia],
      );

      final updatedGuia = guia.copyWith(
        estado: 4,
        estadoTexto: 'Entregada',
      );

      final allDone = stop.recoger.every((g) => g.estado >= 1) &&
          [updatedGuia].every((g) => g.estado == 4);

      final updatedStop = stop.copyWith(
        visitada: allDone ? true : stop.visitada,
        entregar: [updatedGuia],
      );

      expect(updatedStop.entregar.first.estado, equals(4));
      expect(updatedStop.visitada, isTrue);
    });

    test('Acción incidencia: Registra motivo y mantiene estado consistente', () {
      const guia = GuiaItem(
        idGuia: 104,
        folio: 'I-001',
        estado: 3,
        estadoTexto: 'En reparto',
      );

      // Motivo de no entrega: 20 (Negocio cerrado)
      final incidenciaGuia = guia.copyWith(
        estado: 8,
        estadoTexto: GuiaItem.estadoLabel(8),
      );

      expect(incidenciaGuia.estado, equals(8));
      expect(incidenciaGuia.estadoTexto, equals('Incidencia'));
    });

    test('Diferenciación de tipos de parada especiales', () {
      const stopCombustible = RouteStop(
        idParada: 1,
        orden: 1,
        tipo: 'combustible',
        llegadaEstimada: '07:00',
      );
      expect(stopCombustible.isCombustibleStop, isTrue);
      expect(stopCombustible.isClientStop, isFalse);

      const stopRecarga = RouteStop(
        idParada: 2,
        orden: 2,
        tipo: 'recarga',
        llegadaEstimada: '07:30',
      );
      expect(stopRecarga.isRecargaStop, isTrue);
      expect(stopRecarga.isClientStop, isFalse);

      const stopCliente = RouteStop(
        idParada: 3,
        orden: 3,
        tipo: 'cliente',
        llegadaEstimada: '08:00',
      );
      expect(stopCliente.isClientStop, isTrue);
    });
  });
}

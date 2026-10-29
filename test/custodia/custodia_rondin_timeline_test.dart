import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/models/Custodia_/custodia_models.dart';
import 'package:mark_v3/pages/Custodia_/custodia_page.dart';
import 'package:mark_v3/pages/Custodia_/custodia_route_map_widget.dart';
import 'package:mark_v3/providers/Custodia_/custodia_provider.dart';

void main() {
  group('Pruebas de Rondín en Custodia (Ruta en Mapa y Línea de Tiempo)', () {
    const testRondin = RondinDia(
      idRondinDia: 1,
      idRondin: 10,
      nombre: 'Rondín CEDI y bodegas',
      turno: '08:00–18:00',
      unidad: 'VIG-01 · DMO-404-D',
      cumplidos: 2,
      total: 3,
      puntos: [
        RondinPunto(
          id: 1,
          nombre: 'CEDI Vallejo',
          lat: 19.4978,
          lng: -99.1685,
          hora: '08:30',
          cumplidoDirecto: true,
        ),
        RondinPunto(
          id: 2,
          nombre: 'Bodega Tultitlán',
          lat: 19.6483,
          lng: -99.1764,
          hora: '10:00',
          cumplidoDirecto: true,
        ),
        RondinPunto(
          id: 3,
          nombre: 'Caseta Central',
          lat: 19.5211,
          lng: -99.1983,
          hora: '12:00',
        ),
      ],
    );

    testWidgets('CustodiaRondinMapCard renderiza mapa y puntos con tramos diferenciados',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustodiaRondinMapCard(rondin: testRondin),
          ),
        ),
      );

      expect(find.text('Puntos del Rondín en Mapa'), findsOneWidget);
      expect(find.text('2/3 cumplidos'), findsOneWidget);
    });

    testWidgets('CustodiaPage renderiza la Línea de Tiempo conectada del Rondín',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            custodiaProvider.overrideWith(() => _MockCustodiaNotifier(testRondin)),
          ],
          child: const MaterialApp(
            home: CustodiaPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar cabecera de la línea de tiempo
      expect(find.text('LÍNEA DE TIEMPO DEL RONDÍN'), findsOneWidget);
      expect(find.text('3 puntos totales'), findsOneWidget);

      // Verificar nombres de puntos en la línea de tiempo
      expect(find.text('CEDI Vallejo'), findsOneWidget);
      expect(find.text('Bodega Tultitlán'), findsOneWidget);
      expect(find.text('Caseta Central'), findsOneWidget);

      // Verificar estados de la línea de tiempo
      expect(find.text('Cumplido'), findsNWidgets(2));
      expect(find.text('Punto Cumplido'), findsNWidgets(2));
      expect(find.text('Siguiente'), findsOneWidget);
      expect(find.text('Marcar Llegada'), findsOneWidget);
    });

    testWidgets('CustodiaRondinMapCard con isFloatingHeader renderiza barra superior flotante',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustodiaRondinMapCard(
              rondin: testRondin,
              isFloatingHeader: true,
            ),
          ),
        ),
      );

      // Debe mostrar el título del rondín flotante
      expect(find.text('Rondín CEDI y bodegas'), findsOneWidget);
      expect(find.text('Turno: 08:00–18:00 · 2/3 cumplidos'), findsOneWidget);
      expect(find.text('Unidad: VIG-01 · DMO-404-D'), findsOneWidget);
    });

    testWidgets('CustodiaPage renderiza alerta de check-in de monitorista sin romperse',
        (tester) async {
      final rondinConAlerta = testRondin.copyWith(
        solicitudes: [
          const CustodiaSolicitud(
            id: 99,
            texto: '¿Cómo vas? Reporta estatus inmediato.',
            fecha: '2026-10-29 12:30:00',
            plazo: '10 min',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            custodiaProvider.overrideWith(
              () => _MockCustodiaNotifier(rondinConAlerta),
            ),
          ],
          child: const MaterialApp(
            home: CustodiaPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que la alerta de check aparece claramente sin romperse
      expect(find.text('ESPERANDO RESPUESTA'), findsOneWidget);
      expect(find.text('Solicitud de Estatus del Monitorista'), findsOneWidget);
      expect(find.text('«¿Cómo vas? Reporta estatus inmediato.»'), findsOneWidget);
      expect(find.text('Contestar con Check-in («Todo bien»)'), findsOneWidget);
    });

    testWidgets('CustodiaPage renderiza alerta de check-in vencido sin romperse',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            custodiaProvider.overrideWith(
              () => _MockCustodiaNotifier(testRondin, isVencido: true),
            ),
          ],
          child: const MaterialApp(
            home: CustodiaPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('¡CHECK-IN VENCIDO!'), findsOneWidget);
      expect(find.text('Reportar Check-in ahora'), findsOneWidget);
    });
  });
}

class _MockCustodiaNotifier extends CustodiaNotifier {
  final RondinDia initialRondin;
  final bool isVencido;

  _MockCustodiaNotifier(this.initialRondin, {this.isVencido = false});

  @override
  CustodiaState build() {
    return CustodiaState(
      isLoading: false,
      selectedTab: 1, // Pestaña de Rondines
      isVencido: isVencido,
      data: CustodiaDataResponse(
        ok: true,
        rondines: [initialRondin],
      ),
    );
  }

  @override
  Future<void> cargarCustodia({bool silent = false}) async {
    // No-op para test
  }
}

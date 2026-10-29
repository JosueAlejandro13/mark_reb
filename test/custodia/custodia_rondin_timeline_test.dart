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

      // Verificar que los nodos indicadores muestran el número del punto (1, 2, 3) en vez de un check
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
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

      // Debe mostrar el título del rondín flotante y el botón de contraseña/claves
      expect(find.text('Rondín CEDI y bodegas'), findsOneWidget);
      expect(find.text('Turno: 08:00–18:00 · 2/3 cumplidos'), findsOneWidget);
      expect(find.text('Unidad: VIG-01 · DMO-404-D'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      // Debe mostrar los 3 botones flotantes laterales: Carro, Hacer todo grande y Abrir mapa
      expect(find.byTooltip('Fijar carro en el mapa'), findsOneWidget);
      expect(find.byTooltip('Hacer todo grande (Encuadrar rondín)'), findsOneWidget);
      expect(find.byTooltip('Abrir todo el mapa'), findsOneWidget);

      // Al tocar el botón de carro, cambia a modo activo / fijado
      await tester.tap(find.byTooltip('Fijar carro en el mapa'));
      await tester.pump();
      expect(find.byTooltip('Fijando carro (Activo)'), findsOneWidget);

      // Al tocar el botón de pantalla completa, expande el mapa
      await tester.tap(find.byTooltip('Abrir todo el mapa'));
      await tester.pump();
      expect(find.byTooltip('Reducir mapa'), findsOneWidget);
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

    testWidgets('CustodiaPage renderiza cabecera de chat con botón Ampliar/Reducir sin desbordamiento',
        (tester) async {
      // Simular pantalla móvil pequeña (ancho 360)
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final rondinConMensajes = testRondin.copyWith(
        mensajes: [
          const CustodiaMensaje(
            id: 1,
            deApp: false,
            mio: false,
            quien: 'Monitorista',
            texto: '¿Cómo vas? Contesta con tu check-in.',
            fecha: '2026-10-29 13:11',
          ),
          const CustodiaMensaje(
            id: 2,
            deApp: false,
            mio: false,
            quien: 'Monitorista',
            texto: 'Aviso de control.',
            fecha: '2026-10-29 13:15',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            custodiaProvider.overrideWith(
              () => _MockCustodiaNotifier(rondinConMensajes),
            ),
          ],
          child: const MaterialApp(
            home: CustodiaPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que las pestañas segmentadas de Rondín están presentes
      expect(find.text('Puntos (3)'), findsOneWidget);
      expect(find.text('Chat y Bitácora'), findsOneWidget);

      // En la pestaña Puntos inicial vemos la línea de tiempo
      expect(find.text('LÍNEA DE TIEMPO DEL RONDÍN'), findsOneWidget);

      // Tocar la pestaña "Chat y Bitácora"
      await tester.tap(find.text('Chat y Bitácora'));
      await tester.pumpAndSettle();

      // Verificar que el título de chat, el conteo y la bitácora están presentes
      expect(find.text('Mensajes con Monitorista'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // contador de mensajes en tab y cabecera
      expect(find.text('Bitácora de Eventos'), findsOneWidget);
      expect(find.text('Ampliar'), findsNothing); // Botón Ampliar removido para máxima limpieza

      // Volver a la pestaña "Puntos"
      await tester.tap(find.text('Puntos (3)'));
      await tester.pumpAndSettle();

      expect(find.text('LÍNEA DE TIEMPO DEL RONDÍN'), findsOneWidget);
    });

    testWidgets('CustodiaPage renderiza la píldora flotante con SOS y Check-in',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            custodiaProvider.overrideWith(
              () => _MockCustodiaNotifier(testRondin),
            ),
          ],
          child: const MaterialApp(
            home: CustodiaPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que ambos botones están presentes dentro de la píldora flotante
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('Check-in («Todo bien»)'), findsOneWidget);
      expect(find.byIcon(Icons.emergency_rounded), findsOneWidget);
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

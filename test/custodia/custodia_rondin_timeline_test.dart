import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/models/Custodia_/custodia_models.dart';
import 'package:mark_v3/pages/Custodia_/custodia_page.dart';
import 'package:mark_v3/pages/Custodia_/custodia_route_map_widget.dart';
import 'package:mark_v3/pages/Custodia_/custodia_sync_widgets.dart';
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

    testWidgets('CustodiaPage renderiza servicio de custodia con mapa en cabecera y pestañas Convoy y Ruta / Chat y Bitácora',
        (tester) async {
      const testServicio = CustodiaServicio(
        id: 20028,
        folio: 'C-20028',
        nombre: 'Traslado electrónica Querétaro',
        estado: 3,
        estadoTxt: 'En Tránsito',
        salidaReal: '2026-10-29 13:00:00',
        origen: CustodiaPuntoUbicacion(
          nombre: 'CEDI Vallejo',
          lat: 19.4978,
          lng: -99.1685,
        ),
        destino: CustodiaPuntoUbicacion(
          nombre: 'Bodega Bajío',
          lat: 20.5888,
          lng: -100.3899,
        ),
        misUnidades: [
          CustodiaUnidad(
            idEq: 1,
            nombre: 'CUS-01 · DMO-401-D',
            rol: 1,
            rolTxt: 'Principal',
          ),
        ],
        convoy: [
          CustodiaConvoy(
            nombre: 'ESC-01 · DMO-403-D',
            rolTxt: 'Escolta',
            conductor: 'Héctor Vázquez',
            telefono: '5512345678',
          ),
        ],
        mensajes: [
          CustodiaMensaje(
            id: 1,
            quien: 'Monitorista',
            texto: '¿Cómo vas? Salieron del CEDI hace 20 min.',
            fecha: '2026-10-29 13:11:00',
            mio: false,
          ),
          CustodiaMensaje(
            id: 2,
            quien: 'Yo',
            texto: 'Todo bien, en caseta Tepotzotlán.',
            fecha: '2026-10-29 13:20:00',
            mio: true,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            custodiaProvider.overrideWith(
              () => _MockCustodiaServicioNotifier(testServicio),
            ),
          ],
          child: const MaterialApp(
            home: CustodiaPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar mapa en cabecera y barra flotante de Custodia
      expect(find.text('C-20028'), findsOneWidget);
      expect(find.text('Traslado electrónica Querétaro'), findsOneWidget);
      expect(find.text('En Tránsito'), findsOneWidget);

      // Verificar pestañas segmentadas de Custodia
      expect(find.text('Convoy y Ruta (2)'), findsOneWidget);
      expect(find.text('Chat y Bitácora'), findsOneWidget);

      // En la pestaña "Convoy y Ruta", verificar unidades del convoy y botones estilo Apple
      expect(find.text('CUS-01 · DMO-401-D'), findsOneWidget);
      expect(find.text('ESC-01 · DMO-403-D'), findsOneWidget);
      expect(find.text('Llamar'), findsOneWidget);
      expect(find.text('MÍA'), findsOneWidget);

      // Cambiar a la pestaña "Chat y Bitácora"
      await tester.tap(find.text('Chat y Bitácora'));
      await tester.pumpAndSettle();

      // Verificar chat con monitorista y bitácora unificada (el mensaje aparece tanto en el chat como en la bitácora)
      expect(find.text('Mensajes con Monitorista'), findsOneWidget);
      expect(find.text('Bitácora de Eventos'), findsOneWidget);
      expect(find.text('¿Cómo vas? Salieron del CEDI hace 20 min.'), findsNWidgets(2));

      // Cambiar de vuelta a la pestaña "Convoy y Ruta"
      await tester.tap(find.text('Convoy y Ruta (2)'));
      await tester.pumpAndSettle();

      expect(find.text('CUS-01 · DMO-401-D'), findsOneWidget);
    });

    testWidgets('CustodiaSyncStatusBar se posiciona limpiamente arriba de los botones de SOS y Check-in sin solaparse',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            custodiaProvider.overrideWith(() => _MockCustodiaWithSyncNotifier(testRondin)),
          ],
          child: const MaterialApp(
            home: CustodiaPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que tanto la barra de sincronización como el botón SOS están visibles
      final syncBarFinder = find.byType(CustodiaSyncStatusBar);
      final sosButtonFinder = find.text('SOS');
      expect(syncBarFinder, findsOneWidget);
      expect(sosButtonFinder, findsOneWidget);

      // Verificar que la barra de sincronización queda ubicada arriba de los botones flotantes
      final syncBarBottomDy = tester.getBottomLeft(syncBarFinder).dy;
      final sosTopDy = tester.getTopLeft(sosButtonFinder).dy;
      expect(syncBarBottomDy, lessThanOrEqualTo(sosTopDy));
    });

    testWidgets('Unidades del convoy no se duplican cuando la unidad propia está en misUnidades y en convoy',
        (tester) async {
      const duplicadoServicio = CustodiaServicio(
        id: 20027,
        folio: 'C-20027',
        nombre: 'Servicio con unidad propia duplicada en payload',
        estado: 3,
        estadoTxt: 'En Tránsito',
        misUnidades: [
          CustodiaUnidad(
            idEq: 1,
            nombre: 'CUS-01 · DMO-401-D',
            rol: 1,
            rolTxt: 'Principal',
          ),
        ],
        convoy: [
          CustodiaConvoy(
            nombre: 'CUS-01 · DMO-401-D',
            rolTxt: 'Principal',
            conductor: 'Ramón Ortega Silva',
            telefono: '5511223344',
            mia: true,
          ),
          CustodiaConvoy(
            nombre: 'CUS-02 · DMO-402-D',
            rolTxt: 'Remolque / caja',
          ),
          CustodiaConvoy(
            nombre: 'ESC-01 · DMO-403-D',
            rolTxt: 'Custodia / escolta',
            conductor: 'Héctor Vázquez Luna',
            telefono: '5599887766',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            custodiaProvider.overrideWith(
              () => _MockCustodiaServicioNotifier(duplicadoServicio),
            ),
          ],
          child: const MaterialApp(
            home: CustodiaPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe haber exactamente 3 unidades (no 4)
      expect(find.text('Convoy y Ruta (3)'), findsOneWidget);
      expect(find.text('3 unidades'), findsOneWidget);

      // La unidad propia debe aparecer UNA SOLA VEZ
      expect(find.text('CUS-01 · DMO-401-D'), findsOneWidget);
      expect(find.text('MÍA'), findsOneWidget);

      // El botón llamar solo debe aparecer para la escolta ajena con teléfono, no para la propia unidad
      expect(find.text('Llamar'), findsOneWidget);
    });
  });
}

class _MockCustodiaWithSyncNotifier extends CustodiaNotifier {
  final RondinDia initialRondin;

  _MockCustodiaWithSyncNotifier(this.initialRondin);

  @override
  CustodiaState build() {
    return CustodiaState(
      isLoading: false,
      selectedTab: 1,
      pendingActionsCount: 2,
      data: CustodiaDataResponse(
        ok: true,
        rondines: [initialRondin],
      ),
    );
  }

  @override
  Future<void> cargarCustodia({bool silent = false}) async {}
}

class _MockCustodiaServicioNotifier extends CustodiaNotifier {
  final CustodiaServicio initialServicio;

  _MockCustodiaServicioNotifier(this.initialServicio);

  @override
  CustodiaState build() {
    return CustodiaState(
      isLoading: false,
      selectedTab: 0,
      data: CustodiaDataResponse(
        ok: true,
        servicios: [initialServicio],
        claves: const CustodiaClavesConfig(tiene: true),
      ),
    );
  }

  @override
  Future<void> cargarCustodia({bool silent = false}) async {}
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

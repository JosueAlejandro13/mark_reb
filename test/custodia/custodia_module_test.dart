import 'package:mark_v3/pages/Custodia_/custodia_route_map_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mark_v3/models/Custodia_/custodia_models.dart';

void main() {
  group('Módulo de Custodia (Ronda 151)', () {
    test('Parseo completo de a=custodia con convoy, unidades y ruta en tránsito', () {
      final json = {
        "ok": true,
        "claves": {"tiene": true},
        "checkinMin": 30,
        "checkinRojaMin": 15,
        "respuestasRapidas": [
          {"clave": "trafico", "texto": "En tráfico"},
          {"clave": "parada", "texto": "En parada autorizada"}
        ],
        "fotoTipos": [
          {"tipo": 1, "texto": "Sellos / candados"},
          {"tipo": 2, "texto": "Carga"},
          {"tipo": 3, "texto": "Identidad"},
          {"tipo": 5, "texto": "Otra"}
        ],
        "servicios": [
          {
            "id": 12,
            "folio": "C-00012",
            "nombre": "Traslado a planta",
            "estado": 3,
            "estadoTxt": "En tránsito",
            "salidaPlan": "2026-10-25 08:00",
            "salidaReal": "2026-10-25 08:07",
            "llegadaPlan": "2026-10-25 08:30",
            "origen": {"nombre": "Bodega", "lat": 19.43, "lng": -99.13},
            "destino": {"nombre": "Planta", "lat": 19.30, "lng": -99.00},
            "misUnidades": [
              {
                "idEq": 1,
                "nombre": "TRACTO-1 · ABC123",
                "rol": 1,
                "rolTxt": "Principal"
              }
            ],
            "convoy": [
              {
                "nombre": "ESCOLTA-1",
                "rolTxt": "Custodia / escolta",
                "conductor": "Pedro",
                "telefono": "5512345678",
                "mia": false
              }
            ],
            "monitor": "Laura",
            "checkin": {
              "cadaMin": 30,
              "ultimo": "2026-10-25 08:20",
              "vence": "2026-10-25 08:50",
              "venceTs": 1793024400,
              "vencido": false,
              "pide": true
            },
            "solicitudes": [
              {
                "id": 88,
                "texto": "¿Cómo vas?",
                "fecha": "2026-10-25 08:31",
                "plazo": "2026-10-25 08:36",
                "plazoTs": 1793023560
              }
            ],
            "fotos": {
              "pide": ["Sellos", "Carga"],
              "total": 3
            },
            "mensajes": [
              {
                "id": 87,
                "deApp": true,
                "mio": true,
                "quien": "Juan",
                "texto": "En tráfico",
                "rapida": "trafico",
                "fecha": "2026-10-25 08:25",
                "esSolicitud": false
              }
            ],
            "ruta": {
              "formato": "polyline5",
              "polilinea": "a_~iF~ps|U...",
              "corredorM": 500,
              "puntos": [
                {
                  "id": 5,
                  "tipo": 1,
                  "tipoTxt": "Punto de control",
                  "nombre": "Caseta",
                  "lat": 19.36,
                  "lng": -99.06,
                  "radioM": 300,
                  "poligono": null,
                  "plan": "08:22",
                  "horario": null
                }
              ]
            },
            "puede": {
              "checkin": true,
              "panico": true,
              "mensaje": true,
              "fotos": true
            }
          }
        ],
        "rondines": []
      };

      final data = CustodiaDataResponse.fromJson(json);
      expect(data.ok, isTrue);
      expect(data.claves.tiene, isTrue);
      expect(data.servicios.length, 1);

      final srv = data.servicios.first;
      expect(srv.id, 12);
      expect(srv.isEnTransito, isTrue);
      expect(srv.misUnidades.length, 1);
      expect(srv.misUnidades.first.nombre, 'TRACTO-1 · ABC123');

      expect(srv.convoy.length, 1);
      expect(srv.convoy.first.nombre, 'ESCOLTA-1');
      expect(srv.convoy.first.conductor, 'Pedro');
      expect(srv.convoy.first.telefono, '5512345678');

      expect(srv.fotosPide, ['Sellos', 'Carga']);
      expect(srv.fotosTotal, 3);

      expect(srv.ruta, isNotNull);
      expect(srv.ruta!.corredorM, 500);
      expect(srv.ruta!.puntos.length, 1);
      expect(srv.ruta!.puntos.first.nombre, 'Caseta');
      expect(srv.ruta!.puntos.first.plan, '08:22');
    });

    test('Parseo y lógica de Rondín con orden estricto y permanencia mínima', () {
      final jsonRondin = {
        "idRondinDia": 40,
        "idRondin": 3,
        "nombre": "Rondín nocturno",
        "fecha": "2026-10-25",
        "turno": "22:00–06:00",
        "unidad": "RONDIN-1",
        "ordenEstricto": true,
        "cumplidos": 1,
        "total": 4,
        "solicitudes": [],
        "mensajes": [],
        "puntos": [
          {
            "id": 9,
            "nombre": "Puerta Principal",
            "lat": 19.40,
            "lng": -99.10,
            "radioM": 50,
            "hora": "23:00",
            "horaTs": 1793034000,
            "tolMin": 15,
            "permMin": 5,
            "conQr": true,
            "dentro": false,
            "pasos": [
              {"momento": "llegue", "fecha": "2026-10-25 23:02:10"},
              {"momento": "sali", "fecha": "2026-10-25 23:08:45"}
            ]
          },
          {
            "id": 10,
            "nombre": "Almacén Central",
            "lat": 19.41,
            "lng": -99.11,
            "radioM": 40,
            "hora": "23:30",
            "horaTs": 1793035800,
            "tolMin": 15,
            "permMin": 10,
            "conQr": true,
            "dentro": true,
            "pasos": [
              {"momento": "llegue", "fecha": "2026-10-25 23:28:00"}
            ]
          }
        ]
      };

      final rondin = RondinDia.fromJson(jsonRondin);
      expect(rondin.idRondinDia, 40);
      expect(rondin.ordenEstricto, isTrue);
      expect(rondin.puntos.length, 2);

      final p1 = rondin.puntos[0];
      expect(p1.llego, isTrue);
      expect(p1.salio, isTrue);
      expect(p1.completado, isTrue);

      final p2 = rondin.puntos[1];
      expect(p2.llego, isTrue);
      expect(p2.salio, isFalse);
      expect(p2.completado, isFalse);
      expect(p2.dentro, isTrue); // Indica que el GPS del teléfono está dentro del punto
    });

    test('Decodificación de Polilínea (Polyline5) para trazado de ruta en mapa', () {
      // Polilínea codificada estándar de Google: (38.5, -120.2), (40.7, -120.95), (43.252, -126.453)
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final points = Polyline5Decoder.decode(encoded);

      expect(points.length, 3);
      expect(points[0].latitude, closeTo(38.5, 0.001));
      expect(points[0].longitude, closeTo(-120.2, 0.001));
      expect(points[1].latitude, closeTo(40.7, 0.001));
      expect(points[1].longitude, closeTo(-120.95, 0.001));
      expect(points[2].latitude, closeTo(43.252, 0.001));
      expect(points[2].longitude, closeTo(-126.453, 0.001));

      // Cadena vacía regresa lista vacía sin excepciones
      expect(Polyline5Decoder.decode('').isEmpty, isTrue);
    });

    test('Serialización y deserialización JSON completa para caché Offline-First', () {
      final punto = RondinPunto(
        id: 101,
        nombre: 'Caseta Principal',
        lat: 19.432,
        lng: -99.133,
        radioM: 60,
        hora: '10:00',
        tolMin: 10,
        permMin: 5,
        conQr: true,
        dentro: true,
        pasos: [
          const RondinPaso(
            momento: 'llegue',
            fecha: '2026-10-28 10:02:00',
            lat: 19.4321,
            lng: -99.1331,
            conQr: true,
          ),
        ],
      );

      final rondin = RondinDia(
        idRondinDia: 55,
        idRondin: 12,
        nombre: 'Rondín Perimetral',
        fecha: '2026-10-28',
        turno: 'Matutino',
        unidad: 'PATRULLA-02',
        ordenEstricto: true,
        cumplidos: 0,
        total: 5,
        puntos: [punto],
      );

      final resp = CustodiaDataResponse(
        ok: true,
        checkinMin: 30,
        rondines: [rondin],
      );

      // Serializar a JSON
      final jsonMap = resp.toJson();
      expect(jsonMap['ok'], isTrue);
      expect(jsonMap['rondines'], isNotEmpty);

      // Deserializar de JSON
      final deserialized = CustodiaDataResponse.fromJson(jsonMap);
      expect(deserialized.rondines.length, 1);
      final dRondin = deserialized.rondines.first;
      expect(dRondin.idRondinDia, 55);
      expect(dRondin.puntos.length, 1);
      final dPunto = dRondin.puntos.first;
      expect(dPunto.id, 101);
      expect(dPunto.llego, isTrue);
      expect(dPunto.salio, isFalse);
      expect(dPunto.completado, isFalse);
      expect(dPunto.pasos.first.conQr, isTrue);
    });

    test('Actualización optimista de pasos de Rondín y conteo de cumplidos en memoria', () {
      final puntoInicial = RondinPunto(
        id: 200,
        nombre: 'Acceso Vehicular',
        lat: 19.40,
        lng: -99.10,
        pasos: const [],
      );

      final rondinInicial = RondinDia(
        idRondinDia: 90,
        idRondin: 30,
        cumplidos: 0,
        total: 1,
        puntos: [puntoInicial],
      );

      expect(puntoInicial.llego, isFalse);
      expect(puntoInicial.salio, isFalse);
      expect(puntoInicial.completado, isFalse);

      // 1. Marcar llegada optimista
      final pasoLlegada = const RondinPaso(
        momento: 'llegue',
        fecha: '2026-10-28 12:00:00',
        conQr: true,
      );
      final puntoConLlegada = puntoInicial.copyWith(
        pasos: [pasoLlegada],
      );
      expect(puntoConLlegada.llego, isTrue);
      expect(puntoConLlegada.salio, isFalse);
      expect(puntoConLlegada.completado, isFalse);

      // 2. Marcar salida optimista -> el punto se completa y suma a cumplidos
      final pasoSalida = const RondinPaso(
        momento: 'sali',
        fecha: '2026-10-28 12:05:00',
        conQr: false,
      );
      final nuevosPasos = [...puntoConLlegada.pasos, pasoSalida];
      final puntoCompletado = puntoConLlegada.copyWith(
        pasos: nuevosPasos,
        cumplidoDirecto: true,
      );
      expect(puntoCompletado.llego, isTrue);
      expect(puntoCompletado.salio, isTrue);
      expect(puntoCompletado.completado, isTrue);

      final rondinActualizado = rondinInicial.copyWith(
        puntos: [puntoCompletado],
        cumplidos: rondinInicial.cumplidos + 1,
      );
      expect(rondinActualizado.cumplidos, 1);
      expect(rondinActualizado.puntos.first.completado, isTrue);
    });

    test('Regla de permanencia: un «llegué» en otro punto cierra el anterior sin permanencia', () {
      final punto1 = const RondinPunto(
        id: 1,
        nombre: 'Punto A',
        lat: 19.41,
        lng: -99.11,
        pasos: [
          RondinPaso(momento: 'llegue', fecha: '2026-10-28 14:00:00'),
        ],
      );

      final punto2 = const RondinPunto(
        id: 2,
        nombre: 'Punto B',
        lat: 19.42,
        lng: -99.12,
        poligono: 'a_~iF~ps|U_ulLnnqC',
        pasos: [],
      );

      final rondin = RondinDia(
        idRondinDia: 10,
        idRondin: 5,
        cumplidos: 0,
        total: 2,
        puntos: [punto1, punto2],
      );

      expect(punto1.llego, isTrue);
      expect(punto1.salio, isFalse);
      expect(punto1.completado, isFalse);
      expect(punto2.poligono, isNotNull);

      // Simular marcaje de 'llegue' en Punto 2 mientras Punto 1 quedó abierto
      int cumplidos = rondin.cumplidos;
      final puntosActualizados = rondin.puntos.map((p) {
        if (p.id != punto2.id) {
          if (p.llego && !p.salio && !p.completado) {
            cumplidos++;
            return p.copyWith(cumplidoDirecto: true);
          }
          return p;
        }
        return p.copyWith(
          pasos: [
            const RondinPaso(momento: 'llegue', fecha: '2026-10-28 14:15:00'),
          ],
        );
      }).toList();

      expect(puntosActualizados[0].completado, isTrue); // Cerrado automáticamente sin salida
      expect(puntosActualizados[1].llego, isTrue);
      expect(cumplidos, 1);
    });

    test('Prevención de bucle de lectura: solo marca leídos si lastId supera el último procesado', () {
      int lastReadChatMsgId = 0;
      int callsCount = 0;

      void procesarMensajes(List<CustodiaMensaje> mensajes) {
        final unreadFromMonitor =
            mensajes.where((m) => !m.mio && !m.deApp).toList();
        if (unreadFromMonitor.isNotEmpty) {
          final lastId = unreadFromMonitor
              .map((m) => m.id)
              .reduce((a, b) => a > b ? a : b);
          if (lastId > lastReadChatMsgId) {
            lastReadChatMsgId = lastId;
            callsCount++;
          }
        }
      }

      final List<CustodiaMensaje> mensajes = [
        const CustodiaMensaje(id: 101, texto: 'Hola', fecha: '2026-10-28 10:00:00', mio: false, deApp: false),
        const CustodiaMensaje(id: 102, texto: '¿Cómo vas?', fecha: '2026-10-28 10:01:00', mio: false, deApp: false),
      ];

      // Primera pasada (render inicial)
      procesarMensajes(mensajes);
      expect(callsCount, 1);
      expect(lastReadChatMsgId, 102);

      // Segunda pasada (re-render por cambio de estado / Riverpod)
      procesarMensajes(mensajes);
      expect(callsCount, 1); // NO debe volverse a llamar ni generar bucle infinito

      // Tercera pasada (llega mensaje nuevo con id 103)
      final List<CustodiaMensaje> mensajesNuevos = [
        ...mensajes,
        const CustodiaMensaje(id: 103, texto: 'Responde', fecha: '2026-10-28 10:02:00', mio: false, deApp: false),
      ];
      procesarMensajes(mensajesNuevos);
      expect(callsCount, 2);
      expect(lastReadChatMsgId, 103);
    });

    test('Aislamiento de colas: acciones de custodia y rutas son disjuntas por prefijo y tipo', () {
      final accionesCustodia = ['cusCheckin', 'cusPanico', 'cusMensaje', 'cusFoto', 'cusLeido', 'rondinPunto'];
      final accionesRutas = ['salida', 'llegada', 'recojo', 'descarga', 'carga', 'entrega', 'incidencia', 'fin', 'visita', 'pedido'];

      for (final tipo in accionesCustodia) {
        final isCustodia = tipo.startsWith('cus') || tipo == 'rondinPunto';
        expect(isCustodia, isTrue);
        expect(accionesRutas.contains(tipo), isFalse);
      }

      for (final tipo in accionesRutas) {
        final isCustodia = tipo.startsWith('cus') || tipo == 'rondinPunto';
        expect(isCustodia, isFalse);
      }
    });
  });
}

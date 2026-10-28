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
  });
}

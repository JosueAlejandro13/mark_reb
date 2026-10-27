import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Modelos completos para la integración con deliveryPHP/operacion/api.php (MarkV3.1)

class DriverInfo {
  final int id;
  final String nombre;
  final String telefono;

  const DriverInfo({
    required this.id,
    required this.nombre,
    required this.telefono,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      id: _toInt(json['id']),
      nombre: (json['nombre'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'telefono': telefono,
      };
}

class DriverPermissions {
  final bool rutas;
  final bool pedidos;
  final bool clientesNuevos;

  const DriverPermissions({
    this.rutas = true,
    this.pedidos = true,
    this.clientesNuevos = true,
  });

  factory DriverPermissions.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return DriverPermissions(
        rutas: _toBool(json['rutas'], defaultValue: true),
        pedidos: _toBool(json['pedidos'], defaultValue: true),
        clientesNuevos: _toBool(json['clientesNuevos'], defaultValue: true),
      );
    }
    return const DriverPermissions();
  }

  Map<String, dynamic> toJson() => {
        'rutas': rutas,
        'pedidos': pedidos,
        'clientesNuevos': clientesNuevos,
      };
}

class UserInfo {
  final int id;
  final String usuario;
  final String nombre;
  final bool subcuenta;
  final int idCuenta;
  final int idColaborador;
  final bool tieneCodigoComandos;

  const UserInfo({
    this.id = 0,
    this.usuario = '',
    this.nombre = '',
    this.subcuenta = false,
    this.idCuenta = 0,
    this.idColaborador = 0,
    this.tieneCodigoComandos = false,
  });

  factory UserInfo.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return UserInfo(
        id: _toInt(json['id']),
        usuario: (json['usuario'] ?? '').toString(),
        nombre: (json['nombre'] ?? '').toString(),
        subcuenta: _toBool(json['subcuenta']),
        idCuenta: _toInt(json['idCuenta']),
        idColaborador: _toInt(json['idColaborador']),
        tieneCodigoComandos: _toBool(json['tieneCodigoComandos']),
      );
    }
    return const UserInfo();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'usuario': usuario,
        'nombre': nombre,
        'subcuenta': subcuenta,
        'idCuenta': idCuenta,
        'idColaborador': idColaborador,
        'tieneCodigoComandos': tieneCodigoComandos,
      };
}

class UnidadesConfig {
  final String distancia; // km | mi
  final String velocidad; // km/h
  final String combustible; // l | gal

  const UnidadesConfig({
    this.distancia = 'km',
    this.velocidad = 'km/h',
    this.combustible = 'l',
  });

  factory UnidadesConfig.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return UnidadesConfig(
        distancia: (json['distancia'] ?? 'km').toString(),
        velocidad: (json['velocidad'] ?? 'km/h').toString(),
        combustible: (json['combustible'] ?? 'l').toString(),
      );
    }
    return const UnidadesConfig();
  }

  Map<String, dynamic> toJson() => {
        'distancia': distancia,
        'velocidad': velocidad,
        'combustible': combustible,
      };
}

class FlotaPermissions {
  final Map<String, dynamic> raw;

  const FlotaPermissions({this.raw = const {}});

  bool can(String modulo, String accion) {
    final mod = raw[modulo];
    if (mod is Map) {
      return mod[accion] == true || mod[accion] == 1 || mod[accion] == 'true';
    }
    if (mod is bool) return mod;
    return false;
  }

  bool isModuleActive(String modulo) {
    final mod = raw[modulo];
    if (mod is bool) return mod;
    if (mod is Map) return mod.isNotEmpty;
    return false;
  }

  factory FlotaPermissions.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return FlotaPermissions(raw: json);
    }
    return const FlotaPermissions();
  }

  Map<String, dynamic> toJson() => raw;
}

class Login2FaChallenge {
  final String desafio;
  final String enviado; // 'correo' | 'sms' | ''
  final String correo;
  final String sms;
  final String error;
  // Ronda 149: Alta exigida de 2 pasos desde la app
  final bool configurar;
  final String codigo;
  final String correoSugerido;
  final bool correoFijo;

  bool get isConfiguracionExigida =>
      configurar || codigo == 'CONFIGURAR_2PASOS';

  const Login2FaChallenge({
    required this.desafio,
    this.enviado = '',
    this.correo = '',
    this.sms = '',
    this.error = '',
    this.configurar = false,
    this.codigo = '',
    this.correoSugerido = '',
    this.correoFijo = true,
  });

  factory Login2FaChallenge.fromJson(Map<String, dynamic> json) {
    final rawCorreo = (json['correo'] ?? json['correoSugerido'] ?? '').toString();
    return Login2FaChallenge(
      desafio: (json['desafio'] ?? '').toString(),
      enviado: (json['enviado'] ?? '').toString(),
      correo: rawCorreo,
      sms: (json['sms'] ?? '').toString(),
      error: (json['error'] ?? '').toString(),
      configurar: json['configurar'] == true,
      codigo: (json['codigo'] ?? '').toString(),
      correoSugerido: (json['correoSugerido'] ?? rawCorreo).toString(),
      correoFijo: json['correoFijo'] == null ? true : json['correoFijo'] == true,
    );
  }
}

class DriverSession {
  final String token;
  final DriverInfo chofer;
  final String rol; // 'chofer' | 'preventa' | 'usuario'
  final DriverPermissions permisos;
  final UserInfo usuario;
  final UnidadesConfig unidades;
  final FlotaPermissions flota;
  final String servidorHora;
  final bool demo;
  final bool push;

  const DriverSession({
    required this.token,
    required this.chofer,
    this.rol = 'chofer',
    this.permisos = const DriverPermissions(),
    this.usuario = const UserInfo(),
    this.unidades = const UnidadesConfig(),
    this.flota = const FlotaPermissions(),
    this.servidorHora = '',
    this.demo = false,
    this.push = true,
  });

  bool get isPreventa => rol.toLowerCase() == 'preventa';
  bool get isChofer => rol.toLowerCase() == 'chofer';
  bool get isSoloFlota => rol.toLowerCase() == 'usuario';

  factory DriverSession.fromJson(Map<String, dynamic> json) {
    final rolStr = (json['rol'] ?? 'chofer').toString();
    return DriverSession(
      token: (json['token'] ?? '').toString(),
      chofer: DriverInfo.fromJson(
        json['chofer'] is Map<String, dynamic>
            ? json['chofer'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
      rol: rolStr,
      permisos: json['permisos'] != null
          ? DriverPermissions.fromJson(json['permisos'])
          : DriverPermissions(
              rutas: rolStr.toLowerCase() == 'chofer',
              pedidos: rolStr.toLowerCase() != 'usuario',
              clientesNuevos: rolStr.toLowerCase() != 'usuario',
            ),
      usuario: UserInfo.fromJson(json['usuario']),
      unidades: UnidadesConfig.fromJson(json['unidades']),
      flota: FlotaPermissions.fromJson(json['flota']),
      servidorHora: (json['servidorHora'] ?? '').toString(),
      demo: _toBool(json['demo'], defaultValue: false),
      push: json['push'] == null ? true : _toBool(json['push'], defaultValue: true),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'push': push,
        'chofer': chofer.toJson(),
        'rol': rol,
        'permisos': permisos.toJson(),
        'usuario': usuario.toJson(),
        'unidades': unidades.toJson(),
        'flota': flota.toJson(),
        'servidorHora': servidorHora,
        'demo': demo,
      };
}

class IncidentReason {
  final int codigo;
  final String texto;
  final String para; // 'recojo' | 'entrega' | ''

  const IncidentReason({
    required this.codigo,
    required this.texto,
    required this.para,
  });

  bool get isForPickup => para == 'recojo' || (codigo >= 11 && codigo <= 19);
  bool get isForDelivery => para == 'entrega' || (codigo >= 21 && codigo <= 29);

  factory IncidentReason.fromJson(Map<String, dynamic> json) {
    return IncidentReason(
      codigo: _toInt(json['codigo']),
      texto: (json['texto'] ?? '').toString(),
      para: (json['para'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'texto': texto,
        'para': para,
      };
}

class VisitReason {
  final int codigo;
  final String texto;
  final bool visitado;

  const VisitReason({
    required this.codigo,
    required this.texto,
    required this.visitado,
  });

  factory VisitReason.fromJson(Map<String, dynamic> json) {
    final code = _toInt(json['codigo']);
    return VisitReason(
      codigo: code,
      texto: (json['texto'] ?? '').toString(),
      visitado:
          _toBool(json['visitado'], defaultValue: code >= 33 && code <= 35),
    );
  }

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'texto': texto,
        'visitado': visitado,
      };

  static List<VisitReason> defaultReasons() => const [
        VisitReason(codigo: 31, texto: 'Cerrado', visitado: false),
        VisitReason(
            codigo: 32, texto: 'No estaba el encargado', visitado: false),
        VisitReason(codigo: 33, texto: 'No quiso comprar', visitado: true),
        VisitReason(codigo: 34, texto: 'No tenía dinero', visitado: true),
        VisitReason(
            codigo: 35, texto: 'Todavía tenía producto', visitado: true),
        VisitReason(
            codigo: 36,
            texto: 'Cerró el negocio (definitivo)',
            visitado: false),
        VisitReason(
            codigo: 37, texto: 'No encontré el negocio', visitado: false),
      ];
}

class DayConfig {
  final int
      modoEtiqueta; // 0: sin escaneo, 1: guía impresa, 2: rollo chofer, 3: cualquiera
  final int
      pruebaEntrega; // 1: solo código, 2: código o foto+nombre, 3: foto+nombre
  final int firmaEntrega; // 0 o 1
  final int fotoIncidencia; // 0 o 1
  final int distAviso; // metros (300 por defecto)
  final List<IncidentReason> motivosIncidencia;
  final List<VisitReason> motivosVisita;

  const DayConfig({
    this.modoEtiqueta = 3,
    this.pruebaEntrega = 2,
    this.firmaEntrega = 0,
    this.fotoIncidencia = 0,
    this.distAviso = 300,
    this.motivosIncidencia = const [],
    this.motivosVisita = const [],
  });

  factory DayConfig.fromJson(Map<String, dynamic> json) {
    final incList = (json['motivosIncidencia'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(IncidentReason.fromJson)
        .toList();
    final visList = (json['motivosVisita'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(VisitReason.fromJson)
        .toList();

    return DayConfig(
      modoEtiqueta: _toInt(json['modoEtiqueta'], defaultValue: 3),
      pruebaEntrega: _toInt(json['pruebaEntrega'], defaultValue: 2),
      firmaEntrega: _toInt(json['firmaEntrega'], defaultValue: 0),
      fotoIncidencia: _toInt(json['fotoIncidencia'], defaultValue: 0),
      distAviso: _toInt(json['distAviso'], defaultValue: 300),
      motivosIncidencia: incList,
      motivosVisita:
          visList.isNotEmpty ? visList : VisitReason.defaultReasons(),
    );
  }

  Map<String, dynamic> toJson() => {
        'modoEtiqueta': modoEtiqueta,
        'pruebaEntrega': pruebaEntrega,
        'firmaEntrega': firmaEntrega,
        'fotoIncidencia': fotoIncidencia,
        'distAviso': distAviso,
        'motivosIncidencia': motivosIncidencia.map((e) => e.toJson()).toList(),
        'motivosVisita': motivosVisita.map((e) => e.toJson()).toList(),
      };
}

class CatalogProduct {
  final int idProducto;
  final String codigo;
  final String nombre;
  final String unidad;
  final double precio;
  final int idIndex;

  const CatalogProduct({
    required this.idProducto,
    required this.codigo,
    required this.nombre,
    required this.unidad,
    required this.precio,
    required this.idIndex,
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    return CatalogProduct(
      idProducto: _toInt(json['idProducto'] ?? json['id']),
      codigo: (json['codigo'] ?? json['sku'] ?? '').toString(),
      nombre: (json['nombre'] ?? json['descrip'] ?? '').toString(),
      unidad: (json['unidad'] ?? 'PZA').toString(),
      precio: _toDouble(json['precio']),
      idIndex: _toInt(json['idIndex']),
    );
  }

  Map<String, dynamic> toJson() => {
        'idProducto': idProducto,
        'codigo': codigo,
        'nombre': nombre,
        'unidad': unidad,
        'precio': precio,
        'idIndex': idIndex,
      };
}

class RouteVehicle {
  final int id;
  final String economico;
  final String placas;

  const RouteVehicle({
    required this.id,
    required this.economico,
    required this.placas,
  });

  factory RouteVehicle.fromJson(Map<String, dynamic> json) {
    return RouteVehicle(
      id: _toInt(json['id']),
      economico: (json['economico'] ?? '').toString(),
      placas: (json['placas'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'economico': economico,
        'placas': placas,
      };
}

class RouteCedi {
  final int id;
  final String nombre;
  final double lat;
  final double lng;

  const RouteCedi({
    required this.id,
    required this.nombre,
    required this.lat,
    required this.lng,
  });

  factory RouteCedi.fromJson(Map<String, dynamic> json) {
    return RouteCedi(
      id: _toInt(json['id']),
      nombre: (json['nombre'] ?? '').toString(),
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'lat': lat,
        'lng': lng,
      };
}

class RouteBounds {
  final double norte;
  final double sur;
  final double este;
  final double oeste;

  const RouteBounds({
    required this.norte,
    required this.sur,
    required this.este,
    required this.oeste,
  });

  factory RouteBounds.fromJson(Map<String, dynamic> json) {
    return RouteBounds(
      norte: _toDouble(json['norte']),
      sur: _toDouble(json['sur']),
      este: _toDouble(json['este']),
      oeste: _toDouble(json['oeste']),
    );
  }

  Map<String, dynamic> toJson() => {
        'norte': norte,
        'sur': sur,
        'este': este,
        'oeste': oeste,
      };

  LatLngBounds? toLatLngBounds() {
    if (norte == 0 && sur == 0 && este == 0 && oeste == 0) return null;
    final swLat = sur < norte ? sur : norte;
    final neLat = sur < norte ? norte : sur;
    final swLng = oeste < este ? oeste : este;
    final neLng = oeste < este ? este : oeste;
    return LatLngBounds(
      southwest: LatLng(swLat, swLng),
      northeast: LatLng(neLat, neLng),
    );
  }
}

class RouteGeometry {
  final String formato;
  final String huella;
  final bool igual;
  final int puntos;
  final RouteBounds? limites;
  final int distanciaM;
  final int duracionS;
  final String? polilinea;

  const RouteGeometry({
    this.formato = 'polyline5',
    required this.huella,
    this.igual = false,
    this.puntos = 0,
    this.limites,
    this.distanciaM = 0,
    this.duracionS = 0,
    this.polilinea,
  });

  factory RouteGeometry.fromJson(Map<String, dynamic> json) {
    return RouteGeometry(
      formato: (json['formato'] ?? 'polyline5').toString(),
      huella: (json['huella'] ?? '').toString(),
      igual: _toBool(json['igual']),
      puntos: _toInt(json['puntos']),
      limites: json['limites'] is Map<String, dynamic>
          ? RouteBounds.fromJson(json['limites'] as Map<String, dynamic>)
          : null,
      distanciaM: _toInt(json['distanciaM']),
      duracionS: _toInt(json['duracionS']),
      polilinea: json['polilinea']?.toString(),
    );
  }

  RouteGeometry copyWith({String? polilinea, bool? igual}) {
    return RouteGeometry(
      formato: formato,
      huella: huella,
      igual: igual ?? this.igual,
      puntos: puntos,
      limites: limites,
      distanciaM: distanciaM,
      duracionS: duracionS,
      polilinea: polilinea ?? this.polilinea,
    );
  }

  Map<String, dynamic> toJson() => {
        'formato': formato,
        'huella': huella,
        'igual': igual,
        'puntos': puntos,
        'limites': limites?.toJson(),
        'distanciaM': distanciaM,
        'duracionS': duracionS,
        'polilinea': polilinea,
      };

  /// Decodifica formato Google Encoded Polyline con precisión 5 (1e5)
  List<LatLng> decodePolyline() {
    final encoded = polilinea;
    if (encoded == null || encoded.isEmpty) return const [];
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}

class RouteClient {
  final int id;
  final String codigo;
  final String nombre;
  final String nombreCorto;
  final String contacto;
  final String telefono;
  final String direccion;
  final double lat;
  final double lng;
  final String obs;
  final String diasVisita;
  final bool porAprobar;
  final String? localUuid; // Si fue creado sin señal en la app

  const RouteClient({
    required this.id,
    this.codigo = '',
    required this.nombre,
    this.nombreCorto = '',
    this.contacto = '',
    this.telefono = '',
    this.direccion = '',
    this.lat = 0.0,
    this.lng = 0.0,
    this.obs = '',
    this.diasVisita = '',
    this.porAprobar = false,
    this.localUuid,
  });

  RouteClient copyWith({
    int? id,
    String? codigo,
    String? nombre,
    String? nombreCorto,
    String? contacto,
    String? telefono,
    String? direccion,
    double? lat,
    double? lng,
    String? obs,
    String? diasVisita,
    bool? porAprobar,
    String? localUuid,
  }) {
    return RouteClient(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      nombreCorto: nombreCorto ?? this.nombreCorto,
      contacto: contacto ?? this.contacto,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      obs: obs ?? this.obs,
      diasVisita: diasVisita ?? this.diasVisita,
      porAprobar: porAprobar ?? this.porAprobar,
      localUuid: localUuid ?? this.localUuid,
    );
  }

  factory RouteClient.fromJson(Map<String, dynamic> json) {
    String dirStr = '';
    final rawDir = json['direccion'] ??
        json['domicilio'] ??
        json['address'] ??
        json['ubicacion'] ??
        json['dir'];
    if (rawDir is String && rawDir.trim().isNotEmpty) {
      dirStr = rawDir.trim();
    } else if (rawDir is Map) {
      final d = rawDir;
      final street = [d['calle'], d['numero'] ?? d['numExt'] ?? d['numeroExt']]
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .join(' ');
      final parts = [
        street,
        d['colonia'],
        d['municipio'] ?? d['ciudad'],
        d['estado'],
        if (d['cp'] != null && d['cp'].toString().trim().isNotEmpty)
          'CP ${d['cp']}'
      ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();
      dirStr = parts.join(', ');
    } else if (json['calle'] != null && json['calle'].toString().trim().isNotEmpty) {
      final street = [json['calle'], json['numero'] ?? json['numExt'] ?? json['numeroExt']]
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .join(' ');
      final parts = [
        street,
        json['colonia'],
        json['municipio'] ?? json['ciudad'],
        json['estado'],
        if (json['cp'] != null && json['cp'].toString().trim().isNotEmpty)
          'CP ${json['cp']}'
      ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();
      dirStr = parts.join(', ');
    }
    return RouteClient(
      id: _toInt(json['id']),
      codigo: (json['codigo'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      nombreCorto: (json['nombreCorto'] ?? '').toString(),
      contacto: (json['contacto'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
      direccion: dirStr,
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      obs: (json['obs'] ?? json['notas'] ?? '').toString(),
      diasVisita: (json['diasVisita'] ?? '').toString(),
      porAprobar: _toBool(json['porAprobar']),
      localUuid: json['localUuid']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'codigo': codigo,
        'nombre': nombre,
        'nombreCorto': nombreCorto,
        'contacto': contacto,
        'telefono': telefono,
        'direccion': direccion,
        'lat': lat,
        'lng': lng,
        'obs': obs,
        'diasVisita': diasVisita,
        'porAprobar': porAprobar,
        if (localUuid != null) 'localUuid': localUuid,
      };
}

class LabelCode {
  final String codigo;
  final int bulto;

  const LabelCode({
    required this.codigo,
    required this.bulto,
  });

  factory LabelCode.fromJson(Map<String, dynamic> json) {
    return LabelCode(
      codigo: (json['codigo'] ?? '').toString(),
      bulto: _toInt(json['bulto'], defaultValue: 1),
    );
  }

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'bulto': bulto,
      };

  /// Extrae el código limpio de una lectura QR (ej. https://cgps.mx/?e=K7Q2M9XDR4 o K7Q2M-9XDR4)
  static String normalizeScannedCode(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.queryParameters.containsKey('e')) {
      return uri.queryParameters['e']!.replaceAll('-', '').trim().toUpperCase();
    }
    if (trimmed.contains('?e=')) {
      final after = trimmed.split('?e=').last.split('&').first;
      return after.replaceAll('-', '').trim().toUpperCase();
    }
    return trimmed.replaceAll('-', '').toUpperCase();
  }
}

class RecipientInfo {
  final String nombre;
  final String telefono;

  const RecipientInfo({
    required this.nombre,
    required this.telefono,
  });

  factory RecipientInfo.fromJson(Map<String, dynamic> json) {
    return RecipientInfo(
      nombre: (json['nombre'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'telefono': telefono,
      };
}

class VisitPlanItem {
  final int idProducto;
  final int idIndex;
  final String sku;
  final String descrip;
  final int cantidad;

  const VisitPlanItem({
    required this.idProducto,
    this.idIndex = 0,
    required this.sku,
    required this.descrip,
    required this.cantidad,
  });

  factory VisitPlanItem.fromJson(Map<String, dynamic> json) {
    return VisitPlanItem(
      idProducto: _toInt(json['idProducto']),
      idIndex: _toInt(json['idIndex']),
      sku: (json['sku'] ?? json['codigo'] ?? '').toString(),
      descrip: (json['descrip'] ?? json['nombre'] ?? '').toString(),
      cantidad: _toInt(json['cantidad'], defaultValue: 1),
    );
  }

  Map<String, dynamic> toJson() => {
        'idProducto': idProducto,
        'idIndex': idIndex,
        'sku': sku,
        'descrip': descrip,
        'cantidad': cantidad,
      };
}

class VisitSaleLine {
  final int tipo; // 1 venta (default), 2 devolución, 3 cambio
  final int idProducto;
  final int cantidad;
  final double importe;

  const VisitSaleLine({
    this.tipo = 1,
    required this.idProducto,
    required this.cantidad,
    this.importe = 0.0,
  });

  factory VisitSaleLine.fromJson(Map<String, dynamic> json) {
    return VisitSaleLine(
      tipo: _toInt(json['tipo'], defaultValue: 1),
      idProducto: _toInt(json['idProducto']),
      cantidad: _toInt(json['cantidad']),
      importe: _toDouble(json['importe']),
    );
  }

  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'idProducto': idProducto,
        'cantidad': cantidad,
        if (importe > 0) 'importe': importe,
      };
}

class GuiaItem {
  final int idGuia;
  final String folio;
  final int
      estado; // 0 Capturada, 1 Recogida, 2 En CEDI, 3 En reparto, 4 Entregada, 8 Incidencia, 9 Cancelada
  final String estadoTexto;
  final int modalidad; // 0 Por pedido, 1 Mensajería, 2 Diaria, 3 Fija
  final int tipo;
  final int bultos;
  final double pesoKg;
  final String obs;
  final List<LabelCode> etiquetas;
  final RecipientInfo? destinatario;
  final int? visita; // 1 = plan del cliente, 2 = pedido
  final List<VisitPlanItem> items;
  final List<VisitSaleLine> ventas;
  final bool unsyncedLocal;

  const GuiaItem({
    required this.idGuia,
    required this.folio,
    required this.estado,
    required this.estadoTexto,
    this.modalidad = 0,
    this.tipo = 0,
    this.bultos = 1,
    this.pesoKg = 0.0,
    this.obs = '',
    this.etiquetas = const [],
    this.destinatario,
    this.visita,
    this.items = const [],
    this.ventas = const [],
    this.unsyncedLocal = false,
  });

  bool get isVisitGuia =>
      visita != null ||
      modalidad == 2 ||
      modalidad == 3;

  bool get isCompleted => estado == 4 || (estado == 1 && tipo == 0);

  static String estadoLabel(int st) {
    switch (st) {
      case 0:
        return 'Capturada';
      case 1:
        return 'Recogida';
      case 2:
        return 'En CEDI';
      case 3:
        return 'En reparto';
      case 4:
        return 'Entregada';
      case 8:
        return 'Incidencia';
      case 9:
        return 'Cancelada';
      default:
        return 'Estado $st';
    }
  }

  GuiaItem copyWith({
    int? estado,
    String? estadoTexto,
    List<VisitSaleLine>? ventas,
    bool? unsyncedLocal,
  }) {
    return GuiaItem(
      idGuia: idGuia,
      folio: folio,
      estado: estado ?? this.estado,
      estadoTexto: estadoTexto ?? this.estadoTexto,
      modalidad: modalidad,
      tipo: tipo,
      bultos: bultos,
      pesoKg: pesoKg,
      obs: obs,
      etiquetas: etiquetas,
      destinatario: destinatario,
      visita: visita,
      items: items,
      ventas: ventas ?? this.ventas,
      unsyncedLocal: unsyncedLocal ?? this.unsyncedLocal,
    );
  }

  factory GuiaItem.fromJson(Map<String, dynamic> json) {
    final st = _toInt(json['estado']);
    return GuiaItem(
      idGuia: _toInt(json['idGuia'] ?? json['id']),
      folio: (json['folio'] ?? '').toString(),
      estado: st,
      estadoTexto: (json['estadoTexto'] ?? estadoLabel(st)).toString(),
      modalidad: _toInt(json['modalidad']),
      tipo: _toInt(json['tipo']),
      bultos: _toInt(json['bultos'], defaultValue: 1),
      pesoKg: _toDouble(json['pesoKg']),
      obs: (json['obs'] ?? '').toString(),
      etiquetas: (json['etiquetas'] as List<dynamic>? ?? []).map((e) {
        if (e is Map<String, dynamic>) {
          return LabelCode.fromJson(e);
        } else if (e is Map) {
          return LabelCode.fromJson(Map<String, dynamic>.from(e));
        } else {
          return LabelCode(codigo: e.toString(), bulto: 1);
        }
      }).toList(),
      destinatario: json['destinatario'] is Map<String, dynamic>
          ? RecipientInfo.fromJson(json['destinatario'] as Map<String, dynamic>)
          : null,
      visita: json['visita'] != null ? _toInt(json['visita']) : null,
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(VisitPlanItem.fromJson)
          .toList(),
      ventas: (json['ventas'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(VisitSaleLine.fromJson)
          .toList(),
      unsyncedLocal: _toBool(json['unsyncedLocal']),
    );
  }

  Map<String, dynamic> toJson() => {
        'idGuia': idGuia,
        'folio': folio,
        'estado': estado,
        'estadoTexto': estadoTexto,
        'modalidad': modalidad,
        'tipo': tipo,
        'bultos': bultos,
        'pesoKg': pesoKg,
        'obs': obs,
        'etiquetas': etiquetas.map((e) => e.toJson()).toList(),
        if (destinatario != null) 'destinatario': destinatario!.toJson(),
        if (visita != null) 'visita': visita,
        'items': items.map((e) => e.toJson()).toList(),
        'ventas': ventas.map((e) => e.toJson()).toList(),
        'unsyncedLocal': unsyncedLocal,
      };
}

class StopLocationPoint {
  final String nombre;
  final double lat;
  final double lng;

  const StopLocationPoint({
    this.nombre = '',
    this.lat = 0.0,
    this.lng = 0.0,
  });

  factory StopLocationPoint.fromJson(Map<String, dynamic> json) {
    return StopLocationPoint(
      nombre: (json['nombre'] ?? json['name'] ?? json['estacion'] ?? '').toString(),
      lat: _toDouble(json['lat'] ?? json['latitude']),
      lng: _toDouble(json['lng'] ?? json['longitude']),
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'lat': lat,
        'lng': lng,
      };
}

class RouteStop {
  final int idParada;
  final int orden;
  final String tipo; // inicio, cliente, descanso, fin, combustible, recarga, otro
  final String llegadaEstimada;
  final bool visitada;
  final String? visitaOrigen; // gps, app, ambos, null
  final RouteClient? cliente;
  final StopLocationPoint? recarga;
  final StopLocationPoint? combustible;
  final List<GuiaItem> recoger;
  final List<GuiaItem> entregar;
  final bool unsyncedLocal;
  final bool visitaCerrada; // Ronda 146: Parada cerrada con acción visita
  final int? visitaMotivo;  // Motivo 31-37 si no hubo venta
  final String? distanciaLlegada; // Distancia fija registrada si se forzó llegada manual fuera de rango (ej. '3.4 km')

  const RouteStop({
    required this.idParada,
    required this.orden,
    required this.tipo,
    required this.llegadaEstimada,
    this.visitada = false,
    this.visitaOrigen,
    this.cliente,
    this.recarga,
    this.combustible,
    this.recoger = const [],
    this.entregar = const [],
    this.unsyncedLocal = false,
    this.visitaCerrada = false,
    this.visitaMotivo,
    this.distanciaLlegada,
  });

  bool get isClientStop => tipo == 'cliente';
  bool get isRecargaStop => tipo == 'recarga';
  bool get isCombustibleStop => tipo == 'combustible';
  bool get isOtroStop => tipo == 'otro';

  double? get stopLat =>
      cliente != null && (cliente!.lat != 0)
          ? cliente!.lat
          : (recarga != null && recarga!.lat != 0
              ? recarga!.lat
              : (combustible != null && combustible!.lat != 0
                  ? combustible!.lat
                  : null));

  double? get stopLng =>
      cliente != null && (cliente!.lng != 0)
          ? cliente!.lng
          : (recarga != null && recarga!.lng != 0
              ? recarga!.lng
              : (combustible != null && combustible!.lng != 0
                  ? combustible!.lng
                  : null));

  String get stopName {
    if (cliente != null && cliente!.nombre.isNotEmpty) return cliente!.nombre;
    if (recarga != null && recarga!.nombre.isNotEmpty) return recarga!.nombre;
    if (combustible != null && combustible!.nombre.isNotEmpty) {
      return combustible!.nombre;
    }
    switch (tipo) {
      case 'inicio':
        return 'Inicio de Ruta';
      case 'descanso':
        return 'Parada de Descanso';
      case 'combustible':
        return 'Carga de Combustible';
      case 'recarga':
        return 'Recarga de Producto';
      case 'fin':
        return 'Fin de Ruta';
      case 'otro':
      default:
        return 'Parada #$orden';
    }
  }

  RouteStop copyWith({
    bool? visitada,
    String? visitaOrigen,
    StopLocationPoint? recarga,
    StopLocationPoint? combustible,
    List<GuiaItem>? recoger,
    List<GuiaItem>? entregar,
    bool? unsyncedLocal,
    bool? visitaCerrada,
    int? visitaMotivo,
    String? distanciaLlegada,
  }) {
    return RouteStop(
      idParada: idParada,
      orden: orden,
      tipo: tipo,
      llegadaEstimada: llegadaEstimada,
      visitada: visitada ?? this.visitada,
      visitaOrigen: visitaOrigen ?? this.visitaOrigen,
      cliente: cliente,
      recarga: recarga ?? this.recarga,
      combustible: combustible ?? this.combustible,
      recoger: recoger ?? this.recoger,
      entregar: entregar ?? this.entregar,
      unsyncedLocal: unsyncedLocal ?? this.unsyncedLocal,
      visitaCerrada: visitaCerrada ?? this.visitaCerrada,
      visitaMotivo: visitaMotivo ?? this.visitaMotivo,
      distanciaLlegada: distanciaLlegada ?? this.distanciaLlegada,
    );
  }

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      idParada: _toInt(json['idParada']),
      orden: _toInt(json['orden']),
      tipo: (json['tipo'] ?? 'cliente').toString(),
      llegadaEstimada: (json['llegadaEstimada'] ?? '').toString(),
      visitada: _toBool(json['visitada']),
      visitaOrigen: json['visitaOrigen']?.toString(),
      cliente: () {
        if (json['cliente'] is Map<String, dynamic>) {
          final cMap = Map<String, dynamic>.from(json['cliente'] as Map<String, dynamic>);
          if ((cMap['direccion'] == null || cMap['direccion'].toString().trim().isEmpty) &&
              json['direccion'] != null) {
            cMap['direccion'] = json['direccion'];
          }
          if ((cMap['domicilio'] == null || cMap['domicilio'].toString().trim().isEmpty) &&
              json['domicilio'] != null) {
            cMap['domicilio'] = json['domicilio'];
          }
          return RouteClient.fromJson(cMap);
        } else if (json['cliente'] is Map) {
          return RouteClient.fromJson(Map<String, dynamic>.from(json['cliente'] as Map));
        } else if (json['direccion'] != null || json['domicilio'] != null) {
          return RouteClient.fromJson(json);
        }
        return null;
      }(),
      recarga: json['recarga'] is Map<String, dynamic>
          ? StopLocationPoint.fromJson(json['recarga'] as Map<String, dynamic>)
          : null,
      combustible: json['combustible'] is Map<String, dynamic>
          ? StopLocationPoint.fromJson(
              json['combustible'] as Map<String, dynamic>)
          : null,
      recoger: (json['recoger'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(GuiaItem.fromJson)
          .toList(),
      entregar: (json['entregar'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(GuiaItem.fromJson)
          .toList(),
      unsyncedLocal: _toBool(json['unsyncedLocal']),
      visitaCerrada: _toBool(json['visitaCerrada']),
      visitaMotivo: json['visitaMotivo'] != null ? _toInt(json['visitaMotivo']) : null,
      distanciaLlegada: json['distanciaLlegada']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'idParada': idParada,
        'orden': orden,
        'tipo': tipo,
        'llegadaEstimada': llegadaEstimada,
        'visitada': visitada,
        'visitaOrigen': visitaOrigen,
        if (cliente != null) 'cliente': cliente!.toJson(),
        if (recarga != null) 'recarga': recarga!.toJson(),
        if (combustible != null) 'combustible': combustible!.toJson(),
        'recoger': recoger.map((e) => e.toJson()).toList(),
        'entregar': entregar.map((e) => e.toJson()).toList(),
        'unsyncedLocal': unsyncedLocal,
        'visitaCerrada': visitaCerrada,
        if (visitaMotivo != null) 'visitaMotivo': visitaMotivo,
        if (distanciaLlegada != null) 'distanciaLlegada': distanciaLlegada,
      };
}

class DriverRoute {
  final int idRuta;
  final String nombre;
  final int? modalidad; // 0 Por pedido, 1 Mensajería, 2 Diaria, 3 Fija
  final bool operacional;
  final int operationalRoute; // 0 programada, 1 activa, 2 terminada, 3 cerrada por el motor con pendientes
  final RouteVehicle? vehiculo;
  final RouteCedi? cedi;
  final List<RouteStop> paradas;
  final List<GuiaItem> cediDescargar;
  final List<GuiaItem> cediCargar;
  final RouteGeometry? geometria;

  const DriverRoute({
    required this.idRuta,
    required this.nombre,
    this.modalidad,
    this.operacional = false,
    this.operationalRoute = 0,
    this.vehiculo,
    this.cedi,
    this.paradas = const [],
    this.cediDescargar = const [],
    this.cediCargar = const [],
    this.geometria,
  });

  bool get isVisitRoute {
    if (modalidad == 2 || modalidad == 3) return true;
    for (final p in paradas) {
      for (final g in p.entregar) {
        if (g.isVisitGuia) return true;
      }
    }
    return false;
  }

  bool get isProgramada => operationalRoute == 0;
  bool get isActiva => operationalRoute == 1 || operacional;
  bool get isTerminada => operationalRoute == 2;
  bool get isCerradaPorMotor => operationalRoute == 3;
  bool get isFinalizada => operationalRoute == 2 || operationalRoute == 3;

  String get operationalStatusText {
    switch (operationalRoute) {
      case 0:
        return 'POR SALIR';
      case 1:
        return 'OPERATIVA';
      case 2:
        return 'TERMINADA';
      case 3:
        return 'CERRADA';
      default:
        return operacional ? 'OPERATIVA' : 'POR SALIR';
    }
  }

  String get modalidadNombre {
    if (modalidad == 2) return 'Diaria (Visitas)';
    if (modalidad == 3) return 'Fija (Visitas)';
    if (modalidad == 1) return 'Mensajería Directa';
    if (isVisitRoute) return 'Ruta de Visitas';
    return 'Por Pedido / Reparto';
  }

  int get totalClientStops => paradas.where((p) => p.isClientStop).length;

  int get visitedClientStops =>
      paradas.where((p) => p.isClientStop && p.visitada).length;

  DriverRoute copyWith({
    bool? operacional,
    int? operationalRoute,
    List<RouteStop>? paradas,
    List<GuiaItem>? cediDescargar,
    List<GuiaItem>? cediCargar,
    RouteGeometry? geometria,
  }) {
    return DriverRoute(
      idRuta: idRuta,
      nombre: nombre,
      modalidad: modalidad,
      operacional: operacional ?? this.operacional,
      operationalRoute: operationalRoute ?? this.operationalRoute,
      vehiculo: vehiculo,
      cedi: cedi,
      paradas: paradas ?? this.paradas,
      cediDescargar: cediDescargar ?? this.cediDescargar,
      cediCargar: cediCargar ?? this.cediCargar,
      geometria: geometria ?? this.geometria,
    );
  }

  factory DriverRoute.fromJson(Map<String, dynamic> json) {
    List<GuiaItem> parseGuiasList(dynamic raw) {
      if (raw is! List) return const [];
      return raw.map((item) {
        if (item is Map<String, dynamic>) {
          return GuiaItem.fromJson(item);
        } else {
          final id = _toInt(item);
          return GuiaItem(
            idGuia: id,
            folio: 'G-$id',
            estado: 0,
            estadoTexto: 'Pendiente',
          );
        }
      }).toList();
    }

    final bool op = _toBool(json['operacional']);
    final int opRoute = json['operationalRoute'] != null
        ? _toInt(json['operationalRoute'])
        : (op ? 1 : 0);

    return DriverRoute(
      idRuta: _toInt(json['idRuta']),
      nombre: (json['nombre'] ?? 'Ruta').toString(),
      modalidad: json['modalidad'] != null ? _toInt(json['modalidad']) : null,
      operacional: op,
      operationalRoute: opRoute,
      vehiculo: json['vehiculo'] is Map<String, dynamic>
          ? RouteVehicle.fromJson(json['vehiculo'] as Map<String, dynamic>)
          : null,
      cedi: json['cedi'] is Map<String, dynamic>
          ? RouteCedi.fromJson(json['cedi'] as Map<String, dynamic>)
          : null,
      paradas: (json['paradas'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(RouteStop.fromJson)
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden)),
      cediDescargar: parseGuiasList(json['cedi_descargar']),
      cediCargar: parseGuiasList(json['cedi_cargar']),
      geometria: json['geometria'] is Map<String, dynamic>
          ? RouteGeometry.fromJson(json['geometria'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'idRuta': idRuta,
        'nombre': nombre,
        'modalidad': modalidad,
        'operacional': operacional,
        'operationalRoute': operationalRoute,
        if (vehiculo != null) 'vehiculo': vehiculo!.toJson(),
        if (cedi != null) 'cedi': cedi!.toJson(),
        'paradas': paradas.map((e) => e.toJson()).toList(),
        'cedi_descargar': cediDescargar.map((e) => e.toJson()).toList(),
        'cedi_cargar': cediCargar.map((e) => e.toJson()).toList(),
        if (geometria != null) 'geometria': geometria!.toJson(),
      };
}

class DayPackage {
  final int version;
  final String fecha;
  final String servidorHora;
  final DriverInfo chofer;
  final DayConfig config;
  final List<DriverRoute> rutas;
  final List<CatalogProduct> catalogo;

  const DayPackage({
    this.version = 1,
    required this.fecha,
    required this.servidorHora,
    required this.chofer,
    required this.config,
    required this.rutas,
    this.catalogo = const [],
  });

  DayPackage copyWith({
    List<DriverRoute>? rutas,
    List<CatalogProduct>? catalogo,
    String? servidorHora,
  }) {
    return DayPackage(
      version: version,
      fecha: fecha,
      servidorHora: servidorHora ?? this.servidorHora,
      chofer: chofer,
      config: config,
      rutas: rutas ?? this.rutas,
      catalogo: catalogo ?? this.catalogo,
    );
  }

  factory DayPackage.fromJson(Map<String, dynamic> json) {
    return DayPackage(
      version: _toInt(json['version'], defaultValue: 1),
      fecha: (json['fecha'] ?? '').toString(),
      servidorHora: (json['servidorHora'] ?? '').toString(),
      chofer: DriverInfo.fromJson(
        json['chofer'] is Map<String, dynamic>
            ? json['chofer'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
      config: DayConfig.fromJson(
        json['config'] is Map<String, dynamic>
            ? json['config'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
      rutas: (json['rutas'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DriverRoute.fromJson)
          .toList(),
      catalogo: (json['catalogo'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CatalogProduct.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'ok': true,
        'version': version,
        'fecha': fecha,
        'servidorHora': servidorHora,
        'chofer': chofer.toJson(),
        'config': config.toJson(),
        'rutas': rutas.map((e) => e.toJson()).toList(),
        'catalogo': catalogo.map((e) => e.toJson()).toList(),
      };
}

/// Ronda 146: Estructura de paradas pendientes al registrar fin de ruta
class PendientesVisitas {
  final int sinResultado;
  final int sinVisitar;
  final List<String> foliosSinResultado;
  final List<String> foliosSinVisitar;

  const PendientesVisitas({
    this.sinResultado = 0,
    this.sinVisitar = 0,
    this.foliosSinResultado = const [],
    this.foliosSinVisitar = const [],
  });

  bool get isEmpty => sinResultado == 0 && sinVisitar == 0;
  bool get isNotEmpty => !isEmpty;
  int get total => sinResultado + sinVisitar;

  factory PendientesVisitas.fromJson(Map<String, dynamic> json) {
    return PendientesVisitas(
      sinResultado: int.tryParse(json['sinResultado']?.toString() ?? '0') ?? 0,
      sinVisitar: int.tryParse(json['sinVisitar']?.toString() ?? '0') ?? 0,
      foliosSinResultado: (json['foliosSinResultado'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      foliosSinVisitar: (json['foliosSinVisitar'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'sinResultado': sinResultado,
        'sinVisitar': sinVisitar,
        'foliosSinResultado': foliosSinResultado,
        'foliosSinVisitar': foliosSinVisitar,
      };
}

class ServerNotice {
  final String nivel; // 'info' | 'aviso' | 'error'
  final String codigo;
  final String texto;

  const ServerNotice({
    required this.nivel,
    required this.codigo,
    required this.texto,
  });

  bool get isCriticalRedAlert =>
      codigo == 'NO_ES_TU_RUTA' || codigo == 'ETQ_OTRA' || nivel == 'error';

  String get displayTexto => sanitizeText(texto);

  static String sanitizeText(String raw) {
    if (raw.isEmpty) return raw;
    var t = raw;
    // Reemplaza menciones a oficina por "No se dio de alta"
    t = t.replaceAll(RegExp(r'\b(la\s+)?oficina\s+descart[oó]\s+(al\s+)?cliente\b', caseSensitive: false), 'No se dio de alta el cliente');
    t = t.replaceAll(RegExp(r'\b(la\s+)?oficina\s+descart[oó]\s+a\s+', caseSensitive: false), 'No se dio de alta al cliente ');
    t = t.replaceAll(RegExp(r'\bno\s+se\s+dio\s+de\s+alta\s+a\s+', caseSensitive: false), 'No se dio de alta al cliente ');
    t = t.replaceAll(RegExp(r'\b(la\s+)?oficina\s+no\s+(dio|ha\s+dado)\s+de\s+alta\b', caseSensitive: false), 'No se dio de alta');
    t = t.replaceAll(RegExp(r'\bdescartado\s+en\s+(la\s+)?oficina\b', caseSensitive: false), 'No se dio de alta');
    t = t.replaceAll(RegExp(r'\brechazado\s+en\s+(la\s+)?oficina\b', caseSensitive: false), 'No se dio de alta');
    t = t.replaceAll(RegExp(r'\b(no\s+aprobado|descartado)\s+en\s+(la\s+)?oficina\b', caseSensitive: false), 'No se dio de alta');
    t = t.replaceAll(RegExp(r'\ben\s+(la\s+)?oficina\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\bpor\s+(la\s+)?oficina\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\bla\s+oficina\b', caseSensitive: false), 'el sistema');
    t = t.replaceAll(RegExp(r'\boficina\b', caseSensitive: false), 'sistema');
    return t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  factory ServerNotice.fromJson(Map<String, dynamic> json) {
    final rawText = (json['texto'] ?? '').toString();
    return ServerNotice(
      nivel: (json['nivel'] ?? 'info').toString(),
      codigo: (json['codigo'] ?? '').toString(),
      texto: sanitizeText(rawText),
    );
  }

  Map<String, dynamic> toJson() => {
        'nivel': nivel,
        'codigo': codigo,
        'texto': texto,
      };
}

class QueuedAction {
  final int? id;
  final String uuid;
  final String
      tipo; // salida, llegada, recojo, descarga, carga, entrega, incidencia, fin, visita, pedido, cliente
  final int? idRuta;
  final int? idParada;
  final Map<String, dynamic> payload;
  final String status; // 'pending' | 'retrying' | 'rejected'
  final List<ServerNotice> avisos;
  final int retryCount;
  final String createdAt;

  const QueuedAction({
    this.id,
    required this.uuid,
    required this.tipo,
    this.idRuta,
    this.idParada,
    required this.payload,
    this.status = 'pending',
    this.avisos = const [],
    this.retryCount = 0,
    required this.createdAt,
  });

  List<String> get requiredPhotoUuids {
    final List<String> uuids = [];
    if (payload['fotos'] is List) {
      for (final f in payload['fotos']) {
        if (f != null && f.toString().isNotEmpty) {
          uuids.add(f.toString());
        }
      }
    }
    if (payload['firma'] != null && payload['firma'].toString().isNotEmpty) {
      uuids.add(payload['firma'].toString());
    }
    return uuids;
  }

  factory QueuedAction.fromDbMap(Map<String, dynamic> row) {
    Map<String, dynamic> decodedPayload = {};
    try {
      decodedPayload = jsonDecode((row['payload_json'] ?? '{}').toString())
          as Map<String, dynamic>;
    } catch (_) {}

    List<ServerNotice> decodedAvisos = [];
    try {
      final list =
          jsonDecode((row['avisos_json'] ?? '[]').toString()) as List<dynamic>;
      decodedAvisos = list
          .whereType<Map<String, dynamic>>()
          .map(ServerNotice.fromJson)
          .toList();
    } catch (_) {}

    return QueuedAction(
      id: row['id'] as int?,
      uuid: (row['uuid'] ?? '').toString(),
      tipo: (row['tipo'] ?? '').toString(),
      idRuta: row['id_ruta'] as int?,
      idParada: row['id_parada'] as int?,
      payload: decodedPayload,
      status: (row['status'] ?? 'pending').toString(),
      avisos: decodedAvisos,
      retryCount: _toInt(row['retry_count']),
      createdAt: (row['created_at'] ?? '').toString(),
    );
  }
}

class QueuedPhoto {
  final String uuid;
  final int tipo; // 1 = foto, 2 = firma
  final String filePath;
  final bool uploaded;
  final String createdAt;

  const QueuedPhoto({
    required this.uuid,
    required this.tipo,
    required this.filePath,
    this.uploaded = false,
    required this.createdAt,
  });

  factory QueuedPhoto.fromDbMap(Map<String, dynamic> row) {
    return QueuedPhoto(
      uuid: (row['uuid'] ?? '').toString(),
      tipo: _toInt(row['tipo'], defaultValue: 1),
      filePath: (row['file_path'] ?? '').toString(),
      uploaded: _toInt(row['uploaded']) == 1,
      createdAt: (row['created_at'] ?? '').toString(),
    );
  }
}

int _toInt(dynamic v, {int defaultValue = 0}) {
  if (v == null) return defaultValue;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? defaultValue;
}

double _toDouble(dynamic v, {double defaultValue = 0.0}) {
  if (v == null) return defaultValue;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? defaultValue;
}

bool _toBool(dynamic v, {bool defaultValue = false}) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is int) return v != 0;
  final s = v.toString().toLowerCase().trim();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return defaultValue;
}

class SyncedOrder {
  final String referencia;
  final int? idCliente;
  final String cliente;
  final String fecha;
  final int totalLineas;
  final bool porAprobar;
  final String sincronizadoHora;
  final List<dynamic> rawLineas;

  const SyncedOrder({
    required this.referencia,
    this.idCliente,
    required this.cliente,
    required this.fecha,
    required this.totalLineas,
    this.porAprobar = false,
    required this.sincronizadoHora,
    this.rawLineas = const [],
  });

  factory SyncedOrder.fromJson(Map<String, dynamic> json,
      {String? defaultCliente}) {
    final lineas = (json['rawLineas'] as List<dynamic>?) ??
        (json['lineas'] is List<dynamic>
            ? json['lineas'] as List<dynamic>
            : null) ??
        [];
    final int count = json['totalLineas'] != null
        ? _toInt(json['totalLineas'])
        : (json['lineas'] is int ? json['lineas'] as int : lineas.length);

    return SyncedOrder(
      referencia: (json['referencia'] ?? '').toString(),
      idCliente: json['idCliente'] != null ? _toInt(json['idCliente']) : null,
      cliente: (json['cliente'] ?? defaultCliente ?? 'Cliente').toString(),
      fecha: (json['fecha'] ?? '').toString(),
      totalLineas: count > 0 ? count : lineas.length,
      porAprobar: _toBool(json['porAprobar'] ?? json['por_aprobar']),
      sincronizadoHora:
          (json['sincronizadoHora'] ?? json['hora'] ?? '').toString(),
      rawLineas: lineas,
    );
  }

  SyncedOrder copyWithTimestamp(String hora) {
    return SyncedOrder(
      referencia: referencia,
      idCliente: idCliente,
      cliente: cliente,
      fecha: fecha,
      totalLineas: totalLineas,
      porAprobar: porAprobar,
      sincronizadoHora: hora,
      rawLineas: rawLineas,
    );
  }

  Map<String, dynamic> toJson() => {
        'referencia': referencia,
        if (idCliente != null) 'idCliente': idCliente,
        'cliente': cliente,
        'fecha': fecha,
        'totalLineas': totalLineas,
        'porAprobar': porAprobar,
        'sincronizadoHora': sincronizadoHora,
        'rawLineas': rawLineas,
        'lineas': rawLineas,
      };
}

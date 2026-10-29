/// Ronda 151: Módulo de Custodia y Rondines
class CustodiaClavesConfig {
  final bool tiene;

  const CustodiaClavesConfig({this.tiene = false});

  factory CustodiaClavesConfig.fromJson(dynamic json) {
    if (json is bool) return CustodiaClavesConfig(tiene: json);
    if (json is num) return CustodiaClavesConfig(tiene: json != 0);
    if (json is Map<String, dynamic>) {
      final t = json['tiene'];
      final bool has = t == true || t == 1 || t == '1' || t.toString().toLowerCase() == 'true';
      return CustodiaClavesConfig(tiene: has);
    }
    return const CustodiaClavesConfig();
  }

  Map<String, dynamic> toJson() => {'tiene': tiene};
}

class CustodiaRespuestaRapida {
  final String clave;
  final String texto;

  const CustodiaRespuestaRapida({
    required this.clave,
    required this.texto,
  });

  factory CustodiaRespuestaRapida.fromJson(Map<String, dynamic> json) {
    return CustodiaRespuestaRapida(
      clave: (json['clave'] ?? '').toString(),
      texto: (json['texto'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'clave': clave, 'texto': texto};
}

class CustodiaFotoTipo {
  final int tipo;
  final String texto;

  const CustodiaFotoTipo({
    required this.tipo,
    required this.texto,
  });

  factory CustodiaFotoTipo.fromJson(Map<String, dynamic> json) {
    return CustodiaFotoTipo(
      tipo: int.tryParse(json['tipo']?.toString() ?? '1') ?? 1,
      texto: (json['texto'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'tipo': tipo, 'texto': texto};
}

class CustodiaPuntoUbicacion {
  final String nombre;
  final double lat;
  final double lng;

  const CustodiaPuntoUbicacion({
    this.nombre = '',
    this.lat = 0.0,
    this.lng = 0.0,
  });

  factory CustodiaPuntoUbicacion.fromJson(Map<String, dynamic> json) {
    return CustodiaPuntoUbicacion(
      nombre: (json['nombre'] ?? json['noncre'] ?? '').toString(),
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lng: double.tryParse(json['lng']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'lat': lat,
        'lng': lng,
      };
}

class CustodiaUnidad {
  final int idEq;
  final String nombre;
  final int rol;
  final String rolTxt;

  const CustodiaUnidad({
    required this.idEq,
    this.nombre = '',
    this.rol = 1,
    this.rolTxt = '',
  });

  factory CustodiaUnidad.fromJson(Map<String, dynamic> json) {
    return CustodiaUnidad(
      idEq: int.tryParse(json['idEq']?.toString() ?? '0') ?? 0,
      nombre: (json['nombre'] ?? json['noncre'] ?? '').toString(),
      rol: int.tryParse(json['rol']?.toString() ?? '1') ?? 1,
      rolTxt: (json['rolTxt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'idEq': idEq,
        'nombre': nombre,
        'rol': rol,
        'rolTxt': rolTxt,
      };
}

class CustodiaConvoy {
  final String nombre;
  final String rolTxt;
  final String conductor;
  final String telefono;
  final bool mia;

  const CustodiaConvoy({
    this.nombre = '',
    this.rolTxt = '',
    this.conductor = '',
    this.telefono = '',
    this.mia = false,
  });

  factory CustodiaConvoy.fromJson(Map<String, dynamic> json) {
    return CustodiaConvoy(
      nombre: (json['nombre'] ?? json['noncre'] ?? '').toString(),
      rolTxt: (json['rolTxt'] ?? '').toString(),
      conductor: (json['conductor'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
      mia: json['mia'] == true || json['nia'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'rolTxt': rolTxt,
        'conductor': conductor,
        'telefono': telefono,
        'mia': mia,
      };
}

class CustodiaCheckinInfo {
  final int cadaMin;
  final String ultimo;
  final String vence;
  final int? venceTs; // Unix epoch en segundos
  final bool vencido;
  final bool pide;

  const CustodiaCheckinInfo({
    this.cadaMin = 30,
    this.ultimo = '',
    this.vence = '',
    this.venceTs,
    this.vencido = false,
    this.pide = false,
  });

  factory CustodiaCheckinInfo.fromJson(Map<String, dynamic> json) {
    return CustodiaCheckinInfo(
      cadaMin: int.tryParse(json['cadaMin']?.toString() ?? json['cadatin']?.toString() ?? '30') ?? 30,
      ultimo: (json['ultimo'] ?? json['ultino'] ?? '').toString(),
      vence: (json['vence'] ?? '').toString(),
      venceTs: int.tryParse(json['venceTs']?.toString() ?? ''),
      vencido: json['vencido'] == true,
      pide: json['pide'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'cadaMin': cadaMin,
        'ultimo': ultimo,
        'vence': vence,
        'venceTs': venceTs,
        'vencido': vencido,
        'pide': pide,
      };

  CustodiaCheckinInfo copyWith({
    int? cadaMin,
    String? ultimo,
    String? vence,
    int? venceTs,
    bool? vencido,
    bool? pide,
  }) {
    return CustodiaCheckinInfo(
      cadaMin: cadaMin ?? this.cadaMin,
      ultimo: ultimo ?? this.ultimo,
      vence: vence ?? this.vence,
      venceTs: venceTs ?? this.venceTs,
      vencido: vencido ?? this.vencido,
      pide: pide ?? this.pide,
    );
  }
}

class CustodiaSolicitud {
  final int id;
  final String texto;
  final String fecha;
  final String plazo;
  final int? plazoTs;

  const CustodiaSolicitud({
    required this.id,
    this.texto = '',
    this.fecha = '',
    this.plazo = '',
    this.plazoTs,
  });

  factory CustodiaSolicitud.fromJson(Map<String, dynamic> json) {
    return CustodiaSolicitud(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      texto: (json['texto'] ?? '').toString(),
      fecha: (json['fecha'] ?? '').toString(),
      plazo: (json['plazo'] ?? '').toString(),
      plazoTs: int.tryParse(json['plazoTs']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'texto': texto,
        'fecha': fecha,
        'plazo': plazo,
        'plazoTs': plazoTs,
      };
}

class CustodiaMensaje {
  final int id;
  final bool deApp;
  final bool mio;
  final String quien;
  final String texto;
  final String? rapida;
  final String fecha;
  final bool esSolicitud;
  final dynamic respondida;

  const CustodiaMensaje({
    required this.id,
    this.deApp = false,
    this.mio = false,
    this.quien = '',
    this.texto = '',
    this.rapida,
    this.fecha = '',
    this.esSolicitud = false,
    this.respondida,
  });

  factory CustodiaMensaje.fromJson(Map<String, dynamic> json) {
    return CustodiaMensaje(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      deApp: json['deApp'] == true || json['de pp'] == true,
      mio: json['mio'] == true || json['nio'] == true,
      quien: (json['quien'] ?? '').toString(),
      texto: (json['texto'] ?? '').toString(),
      rapida: json['rapida']?.toString(),
      fecha: (json['fecha'] ?? '').toString(),
      esSolicitud: json['esSolicitud'] == true,
      respondida: json['respondida'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deApp': deApp,
        'mio': mio,
        'quien': quien,
        'texto': texto,
        'rapida': rapida,
        'fecha': fecha,
        'esSolicitud': esSolicitud,
        'respondida': respondida,
      };
}

class CustodiaPuntoRuta {
  final int id;
  final int tipo;
  final String tipoTxt;
  final String nombre;
  final double lat;
  final double lng;
  final int radioM;
  final String? poligono;
  final String? plan;
  final String? horario;

  const CustodiaPuntoRuta({
    required this.id,
    this.tipo = 1,
    this.tipoTxt = '',
    this.nombre = '',
    this.lat = 0.0,
    this.lng = 0.0,
    this.radioM = 300,
    this.poligono,
    this.plan,
    this.horario,
  });

  factory CustodiaPuntoRuta.fromJson(Map<String, dynamic> json) {
    return CustodiaPuntoRuta(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      tipo: int.tryParse(json['tipo']?.toString() ?? '1') ?? 1,
      tipoTxt: (json['tipoTxt'] ?? '').toString(),
      nombre: (json['nombre'] ?? json['noncre'] ?? '').toString(),
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lng: double.tryParse(json['lng']?.toString() ?? '0') ?? 0.0,
      radioM: int.tryParse(json['radioM']?.toString() ?? json['radiot']?.toString() ?? '300') ?? 300,
      poligono: json['poligono']?.toString(),
      plan: json['plan']?.toString(),
      horario: json['horario']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo,
        'tipoTxt': tipoTxt,
        'nombre': nombre,
        'lat': lat,
        'lng': lng,
        'radioM': radioM,
        'poligono': poligono,
        'plan': plan,
        'horario': horario,
      };
}

class CustodiaRuta {
  final String formato;
  final String polilinea;
  final int corredorM;
  final List<CustodiaPuntoRuta> puntos;

  const CustodiaRuta({
    this.formato = 'polyline5',
    this.polilinea = '',
    this.corredorM = 500,
    this.puntos = const [],
  });

  factory CustodiaRuta.fromJson(Map<String, dynamic> json) {
    final rawPuntos = json['puntos'];
    final puntosList = rawPuntos is List
        ? rawPuntos.whereType<Map<String, dynamic>>().map(CustodiaPuntoRuta.fromJson).toList()
        : <CustodiaPuntoRuta>[];

    return CustodiaRuta(
      formato: (json['formato'] ?? json['fornato'] ?? 'polyline5').toString(),
      polilinea: (json['polilinea'] ?? '').toString(),
      corredorM: int.tryParse(json['corredorM']?.toString() ?? json['corredort']?.toString() ?? '500') ?? 500,
      puntos: puntosList,
    );
  }

  Map<String, dynamic> toJson() => {
        'formato': formato,
        'polilinea': polilinea,
        'corredorM': corredorM,
        'puntos': puntos.map((e) => e.toJson()).toList(),
      };
}

class CustodiaPermisos {
  final bool checkin;
  final bool panico;
  final bool mensaje;
  final bool fotos;

  const CustodiaPermisos({
    this.checkin = true,
    this.panico = true,
    this.mensaje = true,
    this.fotos = true,
  });

  factory CustodiaPermisos.fromJson(Map<String, dynamic> json) {
    return CustodiaPermisos(
      checkin: json['checkin'] == true,
      panico: json['panico'] == true,
      mensaje: json['mensaje'] == true || json['nensaje'] == true,
      fotos: json['fotos'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'checkin': checkin,
        'panico': panico,
        'mensaje': mensaje,
        'fotos': fotos,
      };
}

class CustodiaServicio {
  final int id;
  final String folio;
  final String nombre;
  final int estado; // 1 programado, 2 listo, 3 en tránsito, 4 llegó, 9 siniestro
  final String estadoTxt;
  final String? salidaPlan;
  final String? salidaReal;
  final String? llegadaPlan;
  final CustodiaPuntoUbicacion? origen;
  final CustodiaPuntoUbicacion? destino;
  final List<CustodiaUnidad> misUnidades;
  final List<CustodiaConvoy> convoy;
  final String? monitor;
  final CustodiaCheckinInfo? checkin;
  final List<CustodiaSolicitud> solicitudes;
  final List<String> fotosPide;
  final int fotosTotal;
  final List<CustodiaMensaje> mensajes;
  final CustodiaRuta? ruta;
  final CustodiaPermisos puede;

  const CustodiaServicio({
    required this.id,
    this.folio = '',
    this.nombre = '',
    this.estado = 1,
    this.estadoTxt = '',
    this.salidaPlan,
    this.salidaReal,
    this.llegadaPlan,
    this.origen,
    this.destino,
    this.misUnidades = const [],
    this.convoy = const [],
    this.monitor,
    this.checkin,
    this.solicitudes = const [],
    this.fotosPide = const [],
    this.fotosTotal = 0,
    this.mensajes = const [],
    this.ruta,
    this.puede = const CustodiaPermisos(),
  });

  bool get isEnTransito => estado == 3;
  bool get isActivo => estado == 1 || estado == 2 || estado == 3 || estado == 9;

  factory CustodiaServicio.fromJson(Map<String, dynamic> json) {
    final rawMisUnidades = json['misUnidades'] ?? json['nisUnidades'];
    final misUnidadesList = rawMisUnidades is List
        ? rawMisUnidades.whereType<Map<String, dynamic>>().map(CustodiaUnidad.fromJson).toList()
        : <CustodiaUnidad>[];

    final rawConvoy = json['convoy'];
    final convoyList = rawConvoy is List
        ? rawConvoy.whereType<Map<String, dynamic>>().map(CustodiaConvoy.fromJson).toList()
        : <CustodiaConvoy>[];

    final rawSolicitudes = json['solicitudes'];
    final solicitudesList = rawSolicitudes is List
        ? rawSolicitudes.whereType<Map<String, dynamic>>().map(CustodiaSolicitud.fromJson).toList()
        : <CustodiaSolicitud>[];

    final rawMensajes = json['mensajes'] ?? json['nensajes'];
    final mensajesList = rawMensajes is List
        ? rawMensajes.whereType<Map<String, dynamic>>().map(CustodiaMensaje.fromJson).toList()
        : <CustodiaMensaje>[];

    final fotosMap = json['fotos'] is Map ? json['fotos'] as Map : null;
    final fotosPideList = fotosMap != null && fotosMap['pide'] is List
        ? (fotosMap['pide'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final int fotosTotalCount = fotosMap != null
        ? int.tryParse(fotosMap['total']?.toString() ?? '0') ?? 0
        : 0;

    return CustodiaServicio(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      folio: (json['folio'] ?? '').toString(),
      nombre: (json['nombre'] ?? json['noncre'] ?? '').toString(),
      estado: int.tryParse(json['estado']?.toString() ?? '1') ?? 1,
      estadoTxt: (json['estadoTxt'] ?? '').toString(),
      salidaPlan: json['salidaPlan']?.toString(),
      salidaReal: json['salidaReal']?.toString(),
      llegadaPlan: json['llegadaPlan']?.toString(),
      origen: json['origen'] is Map<String, dynamic>
          ? CustodiaPuntoUbicacion.fromJson(json['origen'] as Map<String, dynamic>)
          : null,
      destino: json['destino'] is Map<String, dynamic>
          ? CustodiaPuntoUbicacion.fromJson(json['destino'] as Map<String, dynamic>)
          : null,
      misUnidades: misUnidadesList,
      convoy: convoyList,
      monitor: json['monitor']?.toString() ?? json['nonitor']?.toString(),
      checkin: json['checkin'] is Map<String, dynamic>
          ? CustodiaCheckinInfo.fromJson(json['checkin'] as Map<String, dynamic>)
          : null,
      solicitudes: solicitudesList,
      fotosPide: fotosPideList,
      fotosTotal: fotosTotalCount,
      mensajes: mensajesList,
      ruta: json['ruta'] is Map<String, dynamic>
          ? CustodiaRuta.fromJson(json['ruta'] as Map<String, dynamic>)
          : null,
      puede: json['puede'] is Map<String, dynamic>
          ? CustodiaPermisos.fromJson(json['puede'] as Map<String, dynamic>)
          : const CustodiaPermisos(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'folio': folio,
        'nombre': nombre,
        'estado': estado,
        'estadoTxt': estadoTxt,
        'salidaPlan': salidaPlan,
        'salidaReal': salidaReal,
        'llegadaPlan': llegadaPlan,
        'origen': origen?.toJson(),
        'destino': destino?.toJson(),
        'misUnidades': misUnidades.map((e) => e.toJson()).toList(),
        'convoy': convoy.map((e) => e.toJson()).toList(),
        'monitor': monitor,
        'checkin': checkin?.toJson(),
        'solicitudes': solicitudes.map((e) => e.toJson()).toList(),
        'fotos': {
          'pide': fotosPide,
          'total': fotosTotal,
        },
        'mensajes': mensajes.map((e) => e.toJson()).toList(),
        'ruta': ruta?.toJson(),
        'puede': puede.toJson(),
      };

  CustodiaServicio copyWith({
    int? id,
    String? folio,
    String? nombre,
    int? estado,
    String? estadoTxt,
    String? salidaPlan,
    String? salidaReal,
    String? llegadaPlan,
    CustodiaPuntoUbicacion? origen,
    CustodiaPuntoUbicacion? destino,
    List<CustodiaUnidad>? misUnidades,
    List<CustodiaConvoy>? convoy,
    String? monitor,
    CustodiaCheckinInfo? checkin,
    List<CustodiaSolicitud>? solicitudes,
    List<String>? fotosPide,
    int? fotosTotal,
    List<CustodiaMensaje>? mensajes,
    CustodiaRuta? ruta,
    CustodiaPermisos? puede,
  }) {
    return CustodiaServicio(
      id: id ?? this.id,
      folio: folio ?? this.folio,
      nombre: nombre ?? this.nombre,
      estado: estado ?? this.estado,
      estadoTxt: estadoTxt ?? this.estadoTxt,
      salidaPlan: salidaPlan ?? this.salidaPlan,
      salidaReal: salidaReal ?? this.salidaReal,
      llegadaPlan: llegadaPlan ?? this.llegadaPlan,
      origen: origen ?? this.origen,
      destino: destino ?? this.destino,
      misUnidades: misUnidades ?? this.misUnidades,
      convoy: convoy ?? this.convoy,
      monitor: monitor ?? this.monitor,
      checkin: checkin ?? this.checkin,
      solicitudes: solicitudes ?? this.solicitudes,
      fotosPide: fotosPide ?? this.fotosPide,
      fotosTotal: fotosTotal ?? this.fotosTotal,
      mensajes: mensajes ?? this.mensajes,
      ruta: ruta ?? this.ruta,
      puede: puede ?? this.puede,
    );
  }
}

class RondinPaso {
  final String momento; // 'llegue' | 'sali'
  final String fecha;
  final double? lat;
  final double? lng;
  final bool conQr;

  const RondinPaso({
    required this.momento,
    this.fecha = '',
    this.lat,
    this.lng,
    this.conQr = false,
  });

  factory RondinPaso.fromJson(Map<String, dynamic> json) {
    final rawMomento =
        (json['momento'] ?? json['tipo'] ?? '').toString().toLowerCase();
    return RondinPaso(
      momento: rawMomento,
      fecha: (json['fecha'] ?? json['fecHor'] ?? '').toString(),
      lat: double.tryParse(json['lat']?.toString() ?? ''),
      lng: double.tryParse(json['lng']?.toString() ?? ''),
      conQr: json['conQr'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'momento': momento,
        'fecha': fecha,
        'lat': lat,
        'lng': lng,
        'conQr': conQr,
      };

  RondinPaso copyWith({
    String? momento,
    String? fecha,
    double? lat,
    double? lng,
    bool? conQr,
  }) {
    return RondinPaso(
      momento: momento ?? this.momento,
      fecha: fecha ?? this.fecha,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      conQr: conQr ?? this.conQr,
    );
  }
}

class RondinPunto {
  final int id;
  final String nombre;
  final double lat;
  final double lng;
  final int radioM;
  final String hora;
  final int? horaTs;
  final int tolMin;
  final int permMin;
  final bool conQr;
  final bool dentro;
  final String? poligono;
  final List<RondinPaso> pasos;
  final bool? cumplidoDirecto;

  const RondinPunto({
    required this.id,
    this.nombre = '',
    this.lat = 0.0,
    this.lng = 0.0,
    this.radioM = 50,
    this.hora = '',
    this.horaTs,
    this.tolMin = 15,
    this.permMin = 5,
    this.conQr = true,
    this.dentro = false,
    this.poligono,
    this.pasos = const [],
    this.cumplidoDirecto,
  });

  bool get llego =>
      cumplidoDirecto == true ||
      pasos.any((p) =>
          p.momento == 'llegue' ||
          p.momento == 'llegada' ||
          p.momento == 'llego');

  bool get salio =>
      cumplidoDirecto == true ||
      pasos.any((p) =>
          p.momento == 'sali' ||
          p.momento == 'salida' ||
          p.momento == 'salio');

  bool get completado => cumplidoDirecto == true || (llego && salio);

  factory RondinPunto.fromJson(Map<String, dynamic> json) {
    final rawPasos = json['pasos'];
    final pasosList = rawPasos is List
        ? rawPasos
            .whereType<Map<String, dynamic>>()
            .map(RondinPaso.fromJson)
            .toList()
        : <RondinPaso>[];

    final bool isCumplido = json['cumplido'] == true ||
        json['completado'] == true ||
        json['cunplido'] == true ||
        json['hecho'] == true ||
        json['finalizado'] == true ||
        json['estado'] == 2 ||
        json['estado'] == 3 ||
        json['estado']?.toString().toLowerCase() == 'cumplido' ||
        json['estado']?.toString().toLowerCase() == 'completado' ||
        json['estatus']?.toString().toLowerCase() == 'cumplido' ||
        json['estatus']?.toString().toLowerCase() == 'completado';

    return RondinPunto(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nombre: (json['nombre'] ?? json['noncre'] ?? '').toString(),
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lng: double.tryParse(json['lng']?.toString() ?? '0') ?? 0.0,
      radioM: int.tryParse(
              json['radioM']?.toString() ?? json['radiot']?.toString() ?? '50') ??
          50,
      hora: (json['hora'] ?? '').toString(),
      horaTs: int.tryParse(json['horaTs']?.toString() ?? ''),
      tolMin: int.tryParse(
              json['tolMin']?.toString() ?? json['toltin']?.toString() ?? '15') ??
          15,
      permMin: int.tryParse(
              json['permMin']?.toString() ?? json['perntin']?.toString() ?? '5') ??
          5,
      conQr: json['conQr'] == true,
      dentro: json['dentro'] == true,
      poligono: json['poligono']?.toString(),
      pasos: pasosList,
      cumplidoDirecto: isCumplido,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'lat': lat,
        'lng': lng,
        'radioM': radioM,
        'hora': hora,
        'horaTs': horaTs,
        'tolMin': tolMin,
        'permMin': permMin,
        'conQr': conQr,
        'dentro': dentro,
        if (poligono != null) 'poligono': poligono,
        'pasos': pasos.map((p) => p.toJson()).toList(),
        if (cumplidoDirecto != null) 'cumplido': cumplidoDirecto,
      };

  RondinPunto copyWith({
    int? id,
    String? nombre,
    double? lat,
    double? lng,
    int? radioM,
    String? hora,
    int? horaTs,
    int? tolMin,
    int? permMin,
    bool? conQr,
    bool? dentro,
    String? poligono,
    List<RondinPaso>? pasos,
    bool? cumplidoDirecto,
  }) {
    return RondinPunto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radioM: radioM ?? this.radioM,
      hora: hora ?? this.hora,
      horaTs: horaTs ?? this.horaTs,
      tolMin: tolMin ?? this.tolMin,
      permMin: permMin ?? this.permMin,
      conQr: conQr ?? this.conQr,
      dentro: dentro ?? this.dentro,
      poligono: poligono ?? this.poligono,
      pasos: pasos ?? this.pasos,
      cumplidoDirecto: cumplidoDirecto ?? this.cumplidoDirecto,
    );
  }
}

class RondinDia {
  final int idRondinDia;
  final int idRondin;
  final String nombre;
  final String fecha;
  final String turno;
  final String unidad;
  final bool ordenEstricto;
  final int cumplidos;
  final int total;
  final List<CustodiaSolicitud> solicitudes;
  final List<CustodiaMensaje> mensajes;
  final List<RondinPunto> puntos;

  const RondinDia({
    required this.idRondinDia,
    required this.idRondin,
    this.nombre = '',
    this.fecha = '',
    this.turno = '',
    this.unidad = '',
    this.ordenEstricto = false,
    this.cumplidos = 0,
    this.total = 0,
    this.solicitudes = const [],
    this.mensajes = const [],
    this.puntos = const [],
  });

  factory RondinDia.fromJson(Map<String, dynamic> json) {
    final rawPuntos = json['puntos'];
    final puntosList = rawPuntos is List
        ? rawPuntos.whereType<Map<String, dynamic>>().map(RondinPunto.fromJson).toList()
        : <RondinPunto>[];

    final rawSolicitudes = json['solicitudes'];
    final solicitudesList = rawSolicitudes is List
        ? rawSolicitudes.whereType<Map<String, dynamic>>().map(CustodiaSolicitud.fromJson).toList()
        : <CustodiaSolicitud>[];

    final rawMensajes = json['mensajes'] ?? json['nensajes'];
    final mensajesList = rawMensajes is List
        ? rawMensajes.whereType<Map<String, dynamic>>().map(CustodiaMensaje.fromJson).toList()
        : <CustodiaMensaje>[];

    return RondinDia(
      idRondinDia: int.tryParse(json['idRondinDia']?.toString() ?? json['idRondin7ia']?.toString() ?? '0') ?? 0,
      idRondin: int.tryParse(json['idRondin']?.toString() ?? '0') ?? 0,
      nombre: (json['nombre'] ?? json['noncre'] ?? '').toString(),
      fecha: (json['fecha'] ?? '').toString(),
      turno: (json['turno'] ?? '').toString(),
      unidad: (json['unidad'] ?? '').toString(),
      ordenEstricto: json['ordenEstricto'] == true,
      cumplidos: int.tryParse(json['cumplidos']?.toString() ?? json['cunplidos']?.toString() ?? '0') ?? 0,
      total: int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      solicitudes: solicitudesList,
      mensajes: mensajesList,
      puntos: puntosList,
    );
  }

  Map<String, dynamic> toJson() => {
        'idRondinDia': idRondinDia,
        'idRondin': idRondin,
        'nombre': nombre,
        'fecha': fecha,
        'turno': turno,
        'unidad': unidad,
        'ordenEstricto': ordenEstricto,
        'cumplidos': cumplidos,
        'total': total,
        'solicitudes': solicitudes.map((e) => e.toJson()).toList(),
        'mensajes': mensajes.map((e) => e.toJson()).toList(),
        'puntos': puntos.map((e) => e.toJson()).toList(),
      };

  RondinDia copyWith({
    int? idRondinDia,
    int? idRondin,
    String? nombre,
    String? fecha,
    String? turno,
    String? unidad,
    bool? ordenEstricto,
    int? cumplidos,
    int? total,
    List<CustodiaSolicitud>? solicitudes,
    List<CustodiaMensaje>? mensajes,
    List<RondinPunto>? puntos,
  }) {
    return RondinDia(
      idRondinDia: idRondinDia ?? this.idRondinDia,
      idRondin: idRondin ?? this.idRondin,
      nombre: nombre ?? this.nombre,
      fecha: fecha ?? this.fecha,
      turno: turno ?? this.turno,
      unidad: unidad ?? this.unidad,
      ordenEstricto: ordenEstricto ?? this.ordenEstricto,
      cumplidos: cumplidos ?? this.cumplidos,
      total: total ?? this.total,
      solicitudes: solicitudes ?? this.solicitudes,
      mensajes: mensajes ?? this.mensajes,
      puntos: puntos ?? this.puntos,
    );
  }
}

class CustodiaDataResponse {
  final bool ok;
  final CustodiaClavesConfig claves;
  final int checkinMin;
  final int checkinRojaMin;
  final List<CustodiaRespuestaRapida> respuestasRapidas;
  final List<CustodiaFotoTipo> fotoTipos;
  final List<CustodiaServicio> servicios;
  final List<RondinDia> rondines;

  const CustodiaDataResponse({
    this.ok = true,
    this.claves = const CustodiaClavesConfig(),
    this.checkinMin = 30,
    this.checkinRojaMin = 15,
    this.respuestasRapidas = const [],
    this.fotoTipos = const [],
    this.servicios = const [],
    this.rondines = const [],
  });

  bool get hasActiveModule => servicios.isNotEmpty || rondines.isNotEmpty;

  factory CustodiaDataResponse.fromJson(Map<String, dynamic> json) {
    final rawClaves = json['claves'];
    final clavesConfig = CustodiaClavesConfig.fromJson(rawClaves);

    final rawRapidas = json['respuestasRapidas'];
    final rapidasList = rawRapidas is List
        ? rawRapidas.whereType<Map<String, dynamic>>().map(CustodiaRespuestaRapida.fromJson).toList()
        : <CustodiaRespuestaRapida>[];

    final rawFotoTipos = json['fotoTipos'];
    final fotoTiposList = rawFotoTipos is List
        ? rawFotoTipos.whereType<Map<String, dynamic>>().map(CustodiaFotoTipo.fromJson).toList()
        : <CustodiaFotoTipo>[];

    final rawServicios = json['servicios'];
    final serviciosList = rawServicios is List
        ? rawServicios.whereType<Map<String, dynamic>>().map(CustodiaServicio.fromJson).toList()
        : <CustodiaServicio>[];

    final rawRondines = json['rondines'];
    final rondinesList = rawRondines is List
        ? rawRondines.whereType<Map<String, dynamic>>().map(RondinDia.fromJson).toList()
        : <RondinDia>[];

    return CustodiaDataResponse(
      ok: json['ok'] == true,
      claves: clavesConfig,
      checkinMin: int.tryParse(json['checkinMin']?.toString() ?? json['checkintin']?.toString() ?? '30') ?? 30,
      checkinRojaMin: int.tryParse(json['checkinRojaMin']?.toString() ?? json['checkinRojatin']?.toString() ?? '15') ?? 15,
      respuestasRapidas: rapidasList,
      fotoTipos: fotoTiposList,
      servicios: serviciosList,
      rondines: rondinesList,
    );
  }

  Map<String, dynamic> toJson() => {
        'ok': ok,
        'claves': claves.toJson(),
        'checkinMin': checkinMin,
        'checkinRojaMin': checkinRojaMin,
        'respuestasRapidas': respuestasRapidas.map((e) => e.toJson()).toList(),
        'fotoTipos': fotoTipos.map((e) => e.toJson()).toList(),
        'servicios': servicios.map((e) => e.toJson()).toList(),
        'rondines': rondines.map((e) => e.toJson()).toList(),
      };

  CustodiaDataResponse copyWith({
    bool? ok,
    CustodiaClavesConfig? claves,
    int? checkinMin,
    int? checkinRojaMin,
    List<CustodiaRespuestaRapida>? respuestasRapidas,
    List<CustodiaFotoTipo>? fotoTipos,
    List<CustodiaServicio>? servicios,
    List<RondinDia>? rondines,
  }) {
    return CustodiaDataResponse(
      ok: ok ?? this.ok,
      claves: claves ?? this.claves,
      checkinMin: checkinMin ?? this.checkinMin,
      checkinRojaMin: checkinRojaMin ?? this.checkinRojaMin,
      respuestasRapidas: respuestasRapidas ?? this.respuestasRapidas,
      fotoTipos: fotoTipos ?? this.fotoTipos,
      servicios: servicios ?? this.servicios,
      rondines: rondines ?? this.rondines,
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:mark_v3/services/mark_api_client.dart';

/// Servicio de Gestión de Flota y Vehículos migrado a Mark V3.1
/// (api.php?a=vehiculos, a=vehiculo, a=catalogos y a=acciones)
class VehiclesconService {
  final MarkApiClient _client = MarkApiClient.instance;

  // ===========================================================================
  // 1. VEHÍCULOS GENERAL (a=vehiculos y a=vehiculo)
  // ===========================================================================

  Future<List<Map<String, dynamic>>> obtenerVehiculosPorUsuario(
    String idUsuario,
    String idUs,
  ) async {
    try {
      final list = await _client.getVehiculos();
      return list.map((v) {
        final gps = v['gps'] is Map ? v['gps'] as Map : {};
        final odom = (gps['odometro'] ?? v['odometro'] ?? '0').toString();
        final estatus = (v['estatus'] ?? v['Status'] ?? 'Activo').toString();
        final marca = (v['marca'] ?? v['make'] ?? '').toString();
        final modelo = (v['modelo'] ?? v['model'] ?? '').toString();
        final placas = (v['placas'] ?? v['plates'] ?? '').toString();
        final anio = (v['anio'] ?? v['year'] ?? '').toString();
        final id = (v['idVehic'] ?? v['id'] ?? '').toString();
        final vin = (v['vin'] ?? '').toString();
        final color = (v['color'] ?? '').toString();

        return {
          'id': id,
          'idVehic': id,
          'idvehic': id,
          'economic': v['economico'] ?? '',
          'eco': v['economico'] ?? '',
          'plates': placas,
          'placas': placas,
          'brand': marca,
          'marca': marca,
          'make': marca,
          'model': modelo,
          'modelo': modelo,
          'year': anio,
          'anio': anio,
          'color': color,
          'ColorEngo': color,
          'status': estatus,
          'Status': estatus,
          'Estado': estatus,
          'idStatus': (v['idEstatus'] ?? v['idStatus'] ?? 1).toString(),
          'photo': v['foto'] ?? '',
          'foto': v['foto'] ?? '',
          'vin': vin,
          'engineNumber': vin,
          'lat': gps['lat']?.toString() ?? '0',
          'lng': gps['lng']?.toString() ?? '0',
          'speed': gps['velocidad']?.toString() ?? '0',
          'odom': odom,
          'odometro': odom,
          'odometer': odom,
          'gps': gps,
          'fuelTankCapacity': v['capacidadTanque']?.toString() ?? '0',
          'capacidadTanque': v['capacidadTanque']?.toString() ?? '0',
          'tipoVehiculoNombre': v['tipoVehiculoNombre'] ?? 'Vehículo',
          'tipoCombustibleNombre': v['tipoCombustibleNombre'] ?? 'Gasolina',
          'cilindrada': v['cilindrada']?.toString() ?? 'N/A',
          'nCilindros': v['nCilindros']?.toString() ?? 'N/A',
          'promConsumo': v['promConsumo']?.toString() ?? 'N/A',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error en VehiclesconService.obtenerVehiculosPorUsuario: $e');
      return [];
    }
  }

  // ===========================================================================
  // 2. CATÁLOGOS DE FLOTA (a=catalogos)
  // ===========================================================================

  Future<List<Map<String, dynamic>>> obtenerCompanias() async {
    try {
      final cats = await _client.getCatalogos();
      final list = cats['aseguradoras'] ?? cats['companias'] ?? [];
      if (list is List) {
        return list.map((item) {
          if (item is Map<String, dynamic>) return item;
          return {'id': item.toString(), 'name': item.toString()};
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error al obtener compañías: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerTipoCobertura() async {
    try {
      final cats = await _client.getCatalogos();
      final list = cats['coberturas'] ?? [];
      if (list is List) {
        return list.map((item) {
          if (item is Map<String, dynamic>) return item;
          return {'id': item.toString(), 'type': item.toString()};
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error al obtener coberturas: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerHolograma() async {
    try {
      final cats = await _client.getCatalogos();
      final list = cats['hologramas'] ?? [];
      if (list is List) {
        return list.map((item) {
          if (item is Map<String, dynamic>) return item;
          return {'id': item.toString(), 'hologram': item.toString()};
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error al obtener hologramas: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerStatus() async {
    try {
      final cats = await _client.getCatalogos();
      final list = cats['estatus'] ?? [];
      if (list is List) {
        return list.map((item) {
          if (item is Map<String, dynamic>) return item;
          return {'id': item.toString(), 'status': item.toString()};
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error al obtener status: $e');
      return [];
    }
  }

  // ===========================================================================
  // 3. DOCUMENTOS VEHICULARES (a=vehiculo y a=acciones tipo: documento)
  // ===========================================================================

  // ── Tarjeta de Circulación ──
  Future<Map<String, dynamic>?> obtenerTarjetaCirculacion(
    String idVehic,
    String idUs,
  ) async {
    try {
      final intId = int.tryParse(idVehic) ?? 0;
      final ficha = await _client.getVehiculo(intId);
      final doc = ficha['tarjeta'] ?? ficha['documentos']?['tarjeta'];
      if (doc is Map<String, dynamic>) {
        return {
          'id': doc['id'] ?? idVehic,
          'numTarjeta': doc['numero'] ?? '',
          'fecExpedicion': doc['expedicion'] ?? '',
          'fecVencimiento': doc['vence'] ?? '',
          'monto': doc['monto']?.toString() ?? '0',
          'semaforo': doc['semaforo'] ?? 'vigente',
          'fotos': doc['fotos'] ?? [],
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error en obtenerTarjetaCirculacion: $e');
      return null;
    }
  }

  Future<int> crearTarjetaCirculacion(
    String idVehic,
    String idUs,
    String numTarjeta,
    DateTime fecExpedicion,
    DateTime fecVencimiento,
    double monto,
  ) async {
    try {
      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'documento',
          'clase': 'tarjeta',
          'idVehic': int.tryParse(idVehic) ?? 0,
          'numero': numTarjeta.trim(),
          'expedicion': fecExpedicion.toIso8601String().substring(0, 10),
          'vence': fecVencimiento.toIso8601String().substring(0, 10),
          'monto': monto,
          'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
        }
      ];
      final res = await _client.sendActions(acciones);
      if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
        final avisos = res.first['avisos'] as List? ?? [];
        final errorTexto = avisos.isNotEmpty
            ? avisos.first['texto']?.toString()
            : 'Acción rechazada por el servidor.';
        throw Exception(errorTexto);
      }
      return 1;
    } catch (e) {
      debugPrint('Error en crearTarjetaCirculacion: $e');
      rethrow;
    }
  }

  Future<void> actualizarTarjetaCirculacion(
    int idVehic,
    int idUs,
    String numTarjeta,
    String fecExpedicion,
    String fecVencimiento,
    double monto,
  ) async {
    await crearTarjetaCirculacion(
      idVehic.toString(),
      idUs.toString(),
      numTarjeta,
      DateTime.tryParse(fecExpedicion) ?? DateTime.now(),
      DateTime.tryParse(fecVencimiento) ?? DateTime.now(),
      monto,
    );
  }

  Future<void> eliminarTarjetaCirculacion(String idVehic, String idUs) async {
    debugPrint('eliminarTarjetaCirculacion solicitado para $idVehic');
  }

  // ── Impuestos y Tenencias ──
  Future<List<Map<String, dynamic>>> obtenerImpuestosPorVehiculo(
    String idVehic,
    String idUs,
  ) async {
    try {
      final intId = int.tryParse(idVehic) ?? 0;
      final ficha = await _client.getVehiculo(intId);
      final doc = ficha['tenencia'] ?? ficha['documentos']?['tenencia'];
      if (doc is Map<String, dynamic>) {
        return [
          {
            'id': doc['id'] ?? idVehic,
            'year': doc['anio'] ?? DateTime.now().year,
            'fechaPago': doc['pago'] ?? '',
            'fechaExpiracion': doc['vence'] ?? '',
            'montoTenencia': doc['tenencia']?.toString() ?? '0',
            'montoRefrendo': doc['refrendo']?.toString() ?? '0',
            'semaforo': doc['semaforo'] ?? 'vigente',
          }
        ];
      }
      return [];
    } catch (e) {
      debugPrint('Error en obtenerImpuestosPorVehiculo: $e');
      return [];
    }
  }

  Future<int> crearImpuesto(
    String idVehic,
    String idUs,
    int year,
    String fechaPago,
    String fechaExpiracion,
    double montoTenencia,
    double montoRefrendo,
  ) async {
    try {
      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'documento',
          'clase': 'tenencia',
          'idVehic': int.tryParse(idVehic) ?? 0,
          'anio': year,
          'pago': fechaPago,
          'vence': fechaExpiracion,
          'tenencia': montoTenencia,
          'refrendo': montoRefrendo,
          'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
        }
      ];
      final res = await _client.sendActions(acciones);
      if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
        final avisos = res.first['avisos'] as List? ?? [];
        final errorTexto = avisos.isNotEmpty
            ? avisos.first['texto']?.toString()
            : 'Acción rechazada por el servidor.';
        throw Exception(errorTexto);
      }
      return 1;
    } catch (e) {
      debugPrint('Error en crearImpuesto: $e');
      rethrow;
    }
  }

  Future<void> actualizarImpuesto(
    String idVehic,
    String idUs,
    int year,
    String fechaPago,
    String fechaExpiracion,
    double montoTenencia,
    double montoRefrendo,
  ) async {
    await crearImpuesto(
      idVehic,
      idUs,
      year,
      fechaPago,
      fechaExpiracion,
      montoTenencia,
      montoRefrendo,
    );
  }

  Future<void> eliminarImpuestosPorVehiculo(String idVehic, String idUs) async {
    debugPrint('eliminarImpuestosPorVehiculo solicitado para $idVehic');
  }

  // ── Verificaciones Ambientales ──
  Future<List<Map<String, dynamic>>> obtenerVerificacionesPorVehiculo(
    String idVehic,
    String idUs,
  ) async {
    try {
      final intId = int.tryParse(idVehic) ?? 0;
      final ficha = await _client.getVehiculo(intId);
      final doc = ficha['verificacion'] ?? ficha['documentos']?['verificacion'];
      if (doc is Map<String, dynamic>) {
        return [
          {
            'id': doc['id'] ?? idVehic,
            'idHolograma': doc['holograma'] ?? '',
            'fecVerificacion': doc['fecha'] ?? '',
            'proximaVerific': doc['proxima'] ?? '',
            'monto': doc['monto']?.toString() ?? '0',
            'semaforo': doc['semaforo'] ?? 'vigente',
          }
        ];
      }
      return [];
    } catch (e) {
      debugPrint('Error en obtenerVerificacionesPorVehiculo: $e');
      return [];
    }
  }

  Future<int> crearVerificacion(
    String idVehic,
    String idHolograma,
    String idUs,
    String fecVerificacion,
    String proximaVerific,
    double monto,
    String status,
  ) async {
    try {
      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'documento',
          'clase': 'verificacion',
          'idVehic': int.tryParse(idVehic) ?? 0,
          'holograma': idHolograma,
          'fecha': fecVerificacion,
          'proxima': proximaVerific,
          'monto': monto,
          'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
        }
      ];
      final res = await _client.sendActions(acciones);
      if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
        final avisos = res.first['avisos'] as List? ?? [];
        final errorTexto = avisos.isNotEmpty
            ? avisos.first['texto']?.toString()
            : 'Acción rechazada por el servidor.';
        throw Exception(errorTexto);
      }
      return 1;
    } catch (e) {
      debugPrint('Error en crearVerificacion: $e');
      rethrow;
    }
  }

  Future<void> actualizarVerificacionPorVehiculo(
    String idVehic,
    String idUs,
    String idHolograma,
    String fecVerificacion,
    String proximaVerific,
    double monto,
  ) async {
    await crearVerificacion(
      idVehic,
      idHolograma,
      idUs,
      fecVerificacion,
      proximaVerific,
      monto,
      'Activo',
    );
  }

  Future<void> eliminarVerificacionesPorVehiculo(String idVehic, String idUs) async {
    debugPrint('eliminarVerificacionesPorVehiculo solicitado para $idVehic');
  }

  // ── Seguros y Pólizas ──
  Future<List<Map<String, dynamic>>> obtenerSegurosPorVehiculo(
    String idVehic,
    String idUs,
  ) async {
    try {
      final intId = int.tryParse(idVehic) ?? 0;
      final ficha = await _client.getVehiculo(intId);
      final doc = ficha['seguro'] ?? ficha['documentos']?['seguro'];
      if (doc is Map<String, dynamic>) {
        return [
          {
            'id': doc['id'] ?? idVehic,
            'polizaNum': doc['poliza'] ?? '',
            'idCompania': doc['aseguradora'] ?? '',
            'idTipoCobertura': doc['cobertura'] ?? '',
            'fechaInicio': doc['inicio'] ?? '',
            'fechaVencimiento': doc['vence'] ?? '',
            'deducible': doc['deducible']?.toString() ?? '0',
            'monto': doc['monto']?.toString() ?? '0',
            'observaciones': doc['obs'] ?? '',
            'semaforo': doc['semaforo'] ?? 'vigente',
          }
        ];
      }
      return [];
    } catch (e) {
      debugPrint('Error en obtenerSegurosPorVehiculo: $e');
      return [];
    }
  }

  Future<int> crearSeguro(
    String idVehic,
    String idCompania,
    String idUs,
    String polizaNum,
    String idTipoCobertura,
    String fechaInicio,
    String fechaVencimiento,
    String deducible,
    String monto,
    String observaciones,
  ) async {
    try {
      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'documento',
          'clase': 'seguro',
          'idVehic': int.tryParse(idVehic) ?? 0,
          'poliza': polizaNum.trim(),
          'aseguradora': idCompania,
          'cobertura': idTipoCobertura,
          'inicio': fechaInicio,
          'vence': fechaVencimiento,
          'deducible': double.tryParse(deducible) ?? 0,
          'monto': double.tryParse(monto) ?? 0,
          'obs': observaciones,
          'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
        }
      ];
      final res = await _client.sendActions(acciones);
      if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
        final avisos = res.first['avisos'] as List? ?? [];
        final errorTexto = avisos.isNotEmpty
            ? avisos.first['texto']?.toString()
            : 'Acción rechazada por el servidor.';
        throw Exception(errorTexto);
      }
      return 1;
    } catch (e) {
      debugPrint('Error en crearSeguro: $e');
      rethrow;
    }
  }

  Future<void> actualizarSeguroPorVehiculo(
    String idVehic,
    String idUs,
    String idCompania,
    String polizaNum,
    String idTipoCobertura,
    String fecInicio,
    String fecVencimiento,
    double deducible,
    double monto,
    String observaciones,
  ) async {
    await crearSeguro(
      idVehic,
      idCompania,
      idUs,
      polizaNum,
      idTipoCobertura,
      fecInicio,
      fecVencimiento,
      deducible.toString(),
      monto.toString(),
      observaciones,
    );
  }

  Future<void> eliminarSeguro(String idVehic, String idUs) async {
    debugPrint('eliminarSeguro solicitado para $idVehic');
  }

  // ── Crédito y Arrendamiento ──
  Future<List<Map<String, dynamic>>> getCreditos(
    String idUs,
    String idVehic,
  ) async {
    try {
      final intId = int.tryParse(idVehic) ?? 0;
      final ficha = await _client.getVehiculo(intId);
      final credito = ficha['credito'];
      if (credito is Map<String, dynamic>) {
        return [credito];
      }
      return [];
    } catch (e) {
      debugPrint('Error en getCreditos: $e');
      return [];
    }
  }

  Future<void> pagarCuotaCredito({
    required int idPago,
    required double monto,
    required String fecha,
  }) async {
    try {
      final acciones = [
        {
          'uuid': const Uuid().v4(),
          'tipo': 'pagoCredito',
          'idPago': idPago,
          'monto': monto,
          'fecha': fecha,
          'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
        }
      ];
      final res = await _client.sendActions(acciones);
      if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
        final avisos = res.first['avisos'] as List? ?? [];
        final errorTexto = avisos.isNotEmpty
            ? avisos.first['texto']?.toString()
            : 'Acción rechazada por el servidor.';
        throw Exception(errorTexto);
      }
    } catch (e) {
      debugPrint('Error en pagarCuotaCredito: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> obtenerCreditos(String idUs) async {
    return [];
  }

  Future<int> crearCredito(
    String idUs,
    String idVehic,
    String idCompania,
    DateTime fechaInicio,
    String monto,
    String enganche,
    String interes,
    String plazo,
    String comision,
    String comisionApertura,
    DateTime dateFirstPayment,
  ) async {
    return 1;
  }

  Future<void> actualizarCredito(
    String idUs,
    String idVehic,
    String idCompania,
    String fechaInicio,
    String monto,
    String enganche,
    String interes,
    String plazo,
    String comision,
    String comisionApertura,
    String dateFirstPayment,
  ) async {}

  Future<void> eliminarCredito(String idUs, String idVehic) async {}

  Future<List<Map<String, dynamic>>> getPaymentHistory(String idCredit) async {
    return [];
  }

  Future<Map<String, dynamic>> getNextPaymentDate(String idCredit) async {
    return {};
  }

  Future<void> insertarPagosCredito(
    String idUs,
    int idCredit,
    int nPayment,
    DateTime fechaBase,
  ) async {}

  Future<int?> insertRegistrarPagos(int idCredit, String monto) async {
    return 1;
  }

  Future<void> eliminarPayCredit(String idUs, String idCredit) async {}

  Future<void> UpdatePagosCredito(
    String idUs,
    String idCredit,
    int plazo,
    DateTime nuevaFechaInicial,
  ) async {}

  // Métodos de Acciones de Flota (Ronda 133 / Págs. 7-9)
  Future<void> corregirOdometro({
    required int idVehic,
    required double valor,
  }) async {
    final action = {
      'uuid': const Uuid().v4(),
      'tipo': 'odometro',
      'idVehic': idVehic,
      'valor': valor,
      'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
    };
    final res = await _client.sendActions([action]);
    if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
      final avisos = res.first['avisos'] as List? ?? [];
      throw Exception(avisos.isNotEmpty ? avisos.first['texto'] : 'Error al corregir odómetro.');
    }
  }

  Future<void> cambiarEstatusVehiculo({
    required int idVehic,
    required String estatus,
    String? obs,
    String? proximaRevision,
  }) async {
    final action = {
      'uuid': const Uuid().v4(),
      'tipo': 'estatus',
      'idVehic': idVehic,
      'estatus': estatus,
      if (obs != null && obs.isNotEmpty) 'obs': obs,
      if (proximaRevision != null && proximaRevision.isNotEmpty)
        'proximaRevision': proximaRevision,
      'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
    };
    final res = await _client.sendActions([action]);
    if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
      final avisos = res.first['avisos'] as List? ?? [];
      throw Exception(avisos.isNotEmpty ? avisos.first['texto'] : 'Error al cambiar estatus.');
    }
  }

  Future<void> reportarProblemaVehiculo({
    required int idVehic,
    required String titulo,
    String? descripcion,
    String? prioridad,
    String? vence,
    int? idResponsable,
  }) async {
    final action = {
      'uuid': const Uuid().v4(),
      'tipo': 'problema',
      'idVehic': idVehic,
      'titulo': titulo,
      if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
      if (prioridad != null && prioridad.isNotEmpty) 'prioridad': prioridad,
      if (vence != null && vence.isNotEmpty) 'vence': vence,
      if (idResponsable != null) 'idResponsable': idResponsable,
      'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
    };
    final res = await _client.sendActions([action]);
    if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
      final avisos = res.first['avisos'] as List? ?? [];
      throw Exception(avisos.isNotEmpty ? avisos.first['texto'] : 'Error al reportar problema.');
    }
  }

  Future<void> registrarIncidenciaVehiculo({
    required int idVehic,
    required String tipoIncidencia,
    required int severidad, // 1-3
    required String nombre,
    String? obs,
  }) async {
    final action = {
      'uuid': const Uuid().v4(),
      'tipo': 'incidenciaVehiculo',
      'idVehic': idVehic,
      'tipoIncidencia': tipoIncidencia,
      'severidad': severidad,
      'nombre': nombre,
      if (obs != null && obs.isNotEmpty) 'obs': obs,
      'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
    };
    final res = await _client.sendActions([action]);
    if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
      final avisos = res.first['avisos'] as List? ?? [];
      throw Exception(avisos.isNotEmpty ? avisos.first['texto'] : 'Error al registrar incidencia.');
    }
  }

  Future<void> registrarCargaCombustible({
    required int idVehic,
    required int idCombustible,
    required double cantidad,
    int? estacion,
    double? costo,
  }) async {
    final action = {
      'uuid': const Uuid().v4(),
      'tipo': 'combustible',
      'idVehic': idVehic,
      'idCombustible': idCombustible,
      'cantidad': cantidad,
      if (estacion != null) 'estacion': estacion,
      if (costo != null) 'costo': costo,
      'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
    };
    final res = await _client.sendActions([action]);
    if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
      final avisos = res.first['avisos'] as List? ?? [];
      throw Exception(avisos.isNotEmpty ? avisos.first['texto'] : 'Error al registrar combustible.');
    }
  }

  Future<void> registrarPagoCredito({
    required int idPago,
    required double monto,
    required String fecha,
  }) async {
    final action = {
      'uuid': const Uuid().v4(),
      'tipo': 'pagoCredito',
      'idPago': idPago,
      'monto': monto,
      'fecha': fecha,
      'fecHor': DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
    };
    final res = await _client.sendActions([action]);
    if (res.isNotEmpty && (res.first['ok'] == false || res.first['estado'] == 'rechazada')) {
      final avisos = res.first['avisos'] as List? ?? [];
      throw Exception(avisos.isNotEmpty ? avisos.first['texto'] : 'Error al registrar pago de crédito.');
    }
  }

  // Métodos legacy de Management Control para compatibilidad con vistas de documentos existentes
  Future<void> insertManagementControlTJ(String idUs, String idVehic, DateTime fec) async {}
  Future<void> updateManagementControlTJ(int idUs, int idVehic, String fec) async {}
  Future<void> deleteManagementControlTJ(String idUs, String idVehic) async {}
  Future<void> insertManagementControlTax(String idUs, String idVehic, DateTime fec) async {}
  Future<void> updateManagementControlTax(String idUs, String idVehic, String fec) async {}
  Future<void> deleteManagementControlTax(String idUs, String idVehic) async {}
  Future<void> insertManagementControlVf(String idUs, String idVehic, DateTime fec) async {}
  Future<void> updateManagementControlVf(String idUs, String idVehic, String fec) async {}
  Future<void> deleteManagementControlVf(String idUs, String idVehic) async {}
  Future<void> insertManagementControlINS(String idUs, String idVehic, DateTime fec) async {}
  Future<void> updateManagementControlINS(String idUs, String idVehic, String fec) async {}
  Future<void> deleteManagementControlINS(String idUs, String idVehic) async {}
  Future<void> insertManagementControlCd(String idUs, String idVehic, DateTime fec) async {}
  Future<void> updateManagementControlCd(String idUs, String idVehic, DateTime fec) async {}
  Future<void> deleteManagementControlCd(String idUs, String idVehic) async {}
}

import 'dart:async';
import 'package:mark_v3/services/database_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

//Autor: Josue Hernandez
class VehiclesconService {
  final String _baseUrl = '${DatabaseService.apiUrl}/vehicles';

  Future<dynamic> _post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? data['insertedId'] ?? data['affectedRows'] ?? true;
        } else {
          debugPrint('Error en $endpoint: ${data['message']}');
          return null;
        }
      } else {
        debugPrint('Error de servidor en $endpoint: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Excepción en $endpoint: $e');
      return null;
    }
  }

  // GENERAL
  Future<List<Map<String, dynamic>>> obtenerVehiculosPorUsuario(
      String idUsuario, String idUs) async {
    final result = await _post('general/get_vehicles_by_user.php', {
      'idUsuario': idUsuario,
      'idUs': idUs,
    });
    return result != null ? List<Map<String, dynamic>>.from(result) : [];
  }

  Future<List<Map<String, dynamic>>> obtenerCompanias() async {
    final result = await _post('general/get_companies.php', {});
    return result != null ? List<Map<String, dynamic>>.from(result) : [];
  }

  Future<List<Map<String, dynamic>>> obtenerTipoCobertura() async {
    final result = await _post('general/get_coverage_types.php', {});
    return result != null ? List<Map<String, dynamic>>.from(result) : [];
  }

  Future<List<Map<String, dynamic>>> obtenerHolograma() async {
    final result = await _post('general/get_holograms.php', {});
    return result != null ? List<Map<String, dynamic>>.from(result) : [];
  }

  Future<List<Map<String, dynamic>>> obtenerStatus() async {
    final result = await _post('general/get_status.php', {});
    return result != null ? List<Map<String, dynamic>>.from(result) : [];
  }

  // TARJETAS DE CIRCULACIÓN
  Future<Map<String, dynamic>?> obtenerTarjetaCirculacion(
      String idVehic, String idUs) async {
    final result = await _post('circulation_cards/get_circulation_card.php', {
      'idVehic': idVehic,
      'idUs': idUs,
    });
    if (result != null && (result as List).isNotEmpty) {
      return result.first as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> crearNuevaTarjetaCirculacion(
      int idUs,
      int idVehic,
      String numTarjeta,
      DateTime fecExpedicion,
      DateTime fecVencimiento,
      double monto) async {
    await _post('circulation_cards/create_circulation_card.php', {
      'idUs': idUs,
      'idVehic': idVehic,
      'numTarjeta': numTarjeta,
      'fecExpedicion': fecExpedicion.toIso8601String(),
      'fecVencimiento': fecVencimiento.toIso8601String(),
      'monto': monto,
    });
  }

  Future<int> crearTarjetaCirculacion(
    String idVehic,
    String idUs,
    String numTarjeta,
    DateTime fecExpedicion,
    DateTime fecVencimiento,
    double monto,
  ) async {
    final result = await _post('circulation_cards/create_circulation_card.php', {
      'idUs': idUs,
      'idVehic': idVehic,
      'numTarjeta': numTarjeta,
      'fecExpedicion': fecExpedicion.toIso8601String(),
      'fecVencimiento': fecVencimiento.toIso8601String(),
      'monto': monto,
    });
    return (result is int) ? result : int.tryParse(result.toString()) ?? 0;
  }

  Future<void> actualizarTarjetaCirculacion(
    int idVehic,
    int idUs,
    String numTarjeta,
    String fecExpedicion,
    String fecVencimiento,
    double monto,
  ) async {
    await _post('circulation_cards/update_circulation_card.php', {
      'idUs': idUs,
      'idVehic': idVehic,
      'numTarjeta': numTarjeta,
      'fecExpedicion': fecExpedicion,
      'fecVencimiento': fecVencimiento,
      'monto': monto,
    });
  }

  Future<void> eliminarTarjetaCirculacion(String idVehic, String idUs) async {
    await _post('circulation_cards/delete_circulation_card.php', {
      'idVehic': idVehic,
      'idUs': idUs,
    });
  }

  // IMPUESTOS
  Future<List<Map<String, dynamic>>> obtenerImpuestosPorVehiculo(
      String idVehic, String idUs) async {
    final result = await _post('taxes/get_taxes.php', {
      'idVehic': idVehic,
      'idUs': idUs,
    });
    return result != null ? List<Map<String, dynamic>>.from(result) : [];
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
    await _post('taxes/update_tax.php', {
      'idVehic': idVehic,
      'idUs': idUs,
      'year': year,
      'fechaPago': fechaPago,
      'fechaExpiracion': fechaExpiracion,
      'montoTenencia': montoTenencia,
      'montoRefrendo': montoRefrendo,
    });
  }

  Future<int> crearImpuesto(
      String idVehic,
      String idUs,
      int year,
      String fechaPago,
      String fechaExpiracion,
      double montoTenencia,
      double montoRefrendo) async {
    final result = await _post('taxes/create_tax.php', {
      'idVehic': idVehic,
      'idUs': idUs,
      'year': year,
      'fechaPago': fechaPago,
      'fechaExpiracion': fechaExpiracion,
      'montoTenencia': montoTenencia,
      'montoRefrendo': montoRefrendo,
    });
    return (result is int) ? result : int.tryParse(result.toString()) ?? 0;
  }

  Future<void> eliminarImpuestosPorVehiculo(String idVehic, String idUs) async {
    await _post('taxes/delete_tax.php', {
      'idVehic': idVehic,
      'idUs': idUs,
    });
  }

  // VERIFICACIONES
  Future<List<Map<String, dynamic>>> obtenerVerificacionesPorVehiculo(
      String idVehic, String idUs) async {
    final result = await _post('verifications/get_verifications.php', {
      'idVehic': idVehic,
      'idUs': idUs,
    });
    return result != null ? List<Map<String, dynamic>>.from(result) : [];
  }

  Future<void> actualizarVerificacionPorVehiculo(
      String idVehic,
      String idUs,
      String idHolograma,
      String fecVerificacion,
      String proximaVerific,
      double monto) async {
    await _post('verifications/update_verification.php', {
      'idVehic': idVehic,
      'idUs': idUs,
      'idHolograma': idHolograma,
      'fecVerificacion': fecVerificacion,
      'proximaVerific': proximaVerific,
      'monto': monto,
    });
  }

  Future<void> eliminarVerificacionesPorVehiculo(
      String idVehic, String idUs) async {
    await _post('verifications/delete_verification.php', {
      'idVehic': idVehic,
      'idUs': idUs,
    });
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
    final result = await _post('verifications/create_verification.php', {
      'idVehic': idVehic,
      'idUs': idUs,
      'idHolograma': idHolograma,
      'fecVerificacion': fecVerificacion,
      'proximaVerific': proximaVerific,
      'monto': monto,
      'status': status,
    });
    return (result is int) ? result : int.tryParse(result.toString()) ?? 0;
  }

  // SEGUROS
  Future<List<Map<String, dynamic>>> obtenerSegurosPorVehiculo(
      String idVehic, String idUs) async {
    final result = await _post('insurance/get_insurance.php', {
      'idVehic': idVehic,
      'idUs': idUs,
    });
    return result != null ? List<Map<String, dynamic>>.from(result) : [];
  }

  Future<void> eliminarSeguro(String idVehic, String idUs) async {
    await _post('insurance/delete_insurance.php', {
      'idVehic': idVehic,
      'idUs': idUs,
    });
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
      String observaciones) async {
    await _post('insurance/update_insurance.php', {
      'idVehic': idVehic,
      'idUs': idUs,
      'idCompania': idCompania,
      'polizaNum': polizaNum,
      'idTipoCobertura': idTipoCobertura,
      'fechaInicio': fecInicio,
      'fechaVencimiento': fecVencimiento,
      'deducible': deducible,
      'monto': monto,
      'observaciones': observaciones,
    });
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
    final result = await _post('insurance/create_insurance.php', {
      'idVehic': idVehic,
      'idCompania': idCompania,
      'idUs': idUs,
      'polizaNum': polizaNum,
      'idTipoCobertura': idTipoCobertura,
      'fechaInicio': fechaInicio,
      'fechaVencimiento': fechaVencimiento,
      'deducible': deducible,
      'monto': monto,
      'observaciones': observaciones,
    });
    return (result is int) ? result : int.tryParse(result.toString()) ?? 0;
  }

  // MANAGEMENT CONTROLS
  Future<void> _upsertManagementControl(String idUs, String idVehic, String field, String value) async {
    await _post('management_controls/upsert_management_control.php', {
      'idUs': idUs,
      'idVehic': idVehic,
      'field': field,
      'value': value,
    });
  }

  Future<void> _deleteManagementControl(String idUs, String idVehic, String field) async {
    await _post('management_controls/delete_management_control.php', {
      'idUs': idUs,
      'idVehic': idVehic,
      'field': field,
    });
  }

  // TJ (Tarjeta)
  Future<void> insertManagementControlTJ(
      String idUs, String idVehic, DateTime fecExpiTarjeta) async {
    await _upsertManagementControl(idUs, idVehic, 'fecExpiTarjeta', fecExpiTarjeta.toIso8601String());
  }

  Future<void> updateManagementControlTJ(
      int idUs, int idVehic, String fecExpiTarjeta) async {
    await _upsertManagementControl(idUs.toString(), idVehic.toString(), 'fecExpiTarjeta', fecExpiTarjeta);
  }

  Future<void> deleteManagementControlTJ(String idUs, String idVehic) async {
    await _deleteManagementControl(idUs, idVehic, 'fecExpiTarjeta');
  }

  // Tax (Impuestos)
  Future<void> insertManagementControlTax(
      String idUs, String idVehic, DateTime fecExpiTax) async {
    await _upsertManagementControl(idUs, idVehic, 'FecExpiTax', fecExpiTax.toIso8601String());
  }

  Future<void> updateManagementControlTax(
      String idUs, String idVehic, String fecExpiTax) async {
    await _upsertManagementControl(idUs, idVehic, 'FecExpiTax', fecExpiTax);
  }

  Future<void> deleteManagementControlTax(String idUs, String idVehic) async {
    await _deleteManagementControl(idUs, idVehic, 'FecExpiTax');
  }

  // Vf (Verificaciones)
  Future<void> insertManagementControlVf(
      String idUs, String idVehic, DateTime fecExpiVerificacion) async {
    await _upsertManagementControl(idUs, idVehic, 'fecExpiVerificacion', fecExpiVerificacion.toIso8601String());
  }

  Future<void> updateManagementControlVf(
      String idUs, String idVehic, String fecExpiVerificacion) async {
    await _upsertManagementControl(idUs, idVehic, 'fecExpiVerificacion', fecExpiVerificacion);
  }

  Future<void> deleteManagementControlVf(String idUs, String idVehic) async {
    await _deleteManagementControl(idUs, idVehic, 'fecExpiVerificacion');
  }

  // INS (Seguros)
  Future<void> insertManagementControlINS(
      String idUs, String idVehic, DateTime fecExpiSeguro) async {
    await _upsertManagementControl(idUs, idVehic, 'fecExpiSeguro', fecExpiSeguro.toIso8601String());
  }

  Future<void> updateManagementControlINS(
      String idUs, String idVehic, String fecExpiSeguro) async {
    await _upsertManagementControl(idUs, idVehic, 'fecExpiSeguro', fecExpiSeguro);
  }

  Future<void> deleteManagementControlINS(String idUs, String idVehic) async {
    await _deleteManagementControl(idUs, idVehic, 'fecExpiSeguro');
  }

  // Cd (Créditos)
  Future<void> insertManagementControlCd(
      String idUs, String idVehic, DateTime nextPayCredit) async {
    await _upsertManagementControl(idUs, idVehic, 'nextPayCredit', nextPayCredit.toIso8601String());
  }

  Future<void> updateManagementControlCd(
      String idUs, String idVehic, DateTime nextPayCredit) async {
    await _upsertManagementControl(idUs, idVehic, 'nextPayCredit', nextPayCredit.toIso8601String());
  }

  Future<void> deleteManagementControlCd(String idUs, String idVehic) async {
    await _deleteManagementControl(idUs, idVehic, 'nextPayCredit');
  }

  // CREDITOS
  Future<List<Map<String, dynamic>>> getCreditos(
      String idUs, String idVehic) async {
    final result = await _post('credits/get_credits.php', {
      'idVehic': idVehic,
      'idUs': idUs,
    });
    return result != null ? List<Map<String, dynamic>>.from(result) : [];
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
    final result = await _post('credits/create_credit.php', {
      'idUs': idUs,
      'idVehic': idVehic,
      'idCompania': idCompania,
      'fechaInicio': fechaInicio.toIso8601String(),
      'monto': monto,
      'enganche': enganche,
      'interes': interes,
      'plazo': plazo,
      'comision': comision,
      'comisionApertura': comisionApertura,
      'dateFirstPayment': dateFirstPayment.toIso8601String(),
    });
    return (result is int) ? result : int.tryParse(result.toString()) ?? 0;
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
      String dateFirstPayment) async {
    await _post('credits/update_credit.php', {
      'idUs': idUs,
      'idVehic': idVehic,
      'idCompania': idCompania,
      'fechaInicio': fechaInicio,
      'monto': monto,
      'enganche': enganche,
      'interes': interes,
      'plazo': plazo,
      'comision': comision,
      'comisionApertura': comisionApertura,
      'dateFirstPayment': dateFirstPayment,
    });
  }

  Future<void> eliminarCredito(String idUs, String idVehic) async {
    await _post('credits/delete_credit.php', {
      'idVehic': idVehic,
      'idUs': idUs,
    });
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory(String idCredit) async {
    final result = await _post('credits/get_payment_history.php', {
      'idCredit': idCredit,
    });
    return result != null ? List<Map<String, dynamic>>.from(result) : [];
  }

  Future<Map<String, dynamic>> getNextPaymentDate(String idCredit) async {
    final result = await _post('credits/get_next_payment_date.php', {
      'idCredit': idCredit,
    });
    if (result != null && (result as List).isNotEmpty) {
      return result.first as Map<String, dynamic>;
    }
    return {};
  }

  Future<void> insertarPagosCredito(
      String idUs, int idCredit, int nPayment, DateTime fechaBase) async {
    await _post('credits/create_credit_payments.php', {
      'idUs': idUs,
      'idCredit': idCredit,
      'nPayment': nPayment,
      'fechaBase': fechaBase.toIso8601String(),
    });
  }

  Future<int?> insertRegistrarPagos(int idCredit, String monto) async {
    final result = await _post('credits/register_payment.php', {
      'idCredit': idCredit,
      'monto': monto,
    });
    return (result is int) ? result : int.tryParse(result?.toString() ?? '');
  }

  Future<List<Map<String, dynamic>>> obtenerCreditos(String idUs) async {
    final result = await _post('credits/get_finance_companies.php', {
      'idUs': idUs,
    });
    return result != null ? List<Map<String, dynamic>>.from(result) : [];
  }

  Future<void> eliminarPayCredit(String idUs, String idCredit) async {
    await _post('credits/delete_credit_payments.php', {
      'idCredit': idCredit,
      'idUs': idUs,
    });
  }

  Future<void> UpdatePagosCredito(String idUs, String idCredit, int plazo,
      DateTime nuevaFechaInicial) async {
    await _post('credits/update_credit_payments.php', {
      'idUs': idUs,
      'idCredit': idCredit,
      'plazo': plazo,
      'nuevaFechaInicial': nuevaFechaInicial.toIso8601String(),
    });
  }
}

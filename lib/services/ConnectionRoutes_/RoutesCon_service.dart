import 'dart:async';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/services/mark_api_client.dart';

typedef DriverApiException = MarkApiException;

/// Servicio de comunicación con MarkV3.1 (Rutas y Flota):
/// Conecta directamente con MarkApiClient.instance
class RoutesconService {
  final MarkApiClient _client = MarkApiClient.instance;

  static String get apiEndpoint => MarkApiClient.instance.endpoint;

  String? get token => _client.token;
  void setToken(String? value) {
    _client.setToken(value);
  }

  Future<DriverSession> login({
    required String usuario,
    required String password,
    required String dispositivo,
    String appVersion = '1.0.1',
    String fcm = '',
  }) async {
    final result = await _client.login(
      usuario: usuario,
      password: password,
      dispositivo: dispositivo,
      appVersion: appVersion,
      fcm: fcm,
    );

    if (result.isSuccess && result.session != null) {
      return result.session!;
    }

    throw MarkApiException(
      statusCode: 200,
      message: result.errorMessage ?? 'No se pudo iniciar sesión.',
    );
  }

  Future<DriverSession> pingYo({String? tokenOverride}) async {
    return await _client.pingYo(tokenOverride: tokenOverride);
  }

  Future<bool> updateFcm(String fcmToken, {String? tokenOverride}) async {
    return await _client.updateFcm(fcmToken, tokenOverride: tokenOverride);
  }

  Future<DayPackage> fetchDayPackage({
    String? fecha,
    Map<String, String>? huellas,
    String? tokenOverride,
  }) async {
    return await _client.fetchDayPackage(
      fecha: fecha,
      huellas: huellas,
      tokenOverride: tokenOverride,
    );
  }

  Future<bool> uploadPhoto({
    required String uuid,
    required int tipo,
    required String filePath,
    String? tokenOverride,
  }) async {
    return await _client.uploadPhoto(
      uuid: uuid,
      tipo: tipo,
      filePath: filePath,
      tokenOverride: tokenOverride,
    );
  }

  Future<List<Map<String, dynamic>>> sendActions(
    List<Map<String, dynamic>> acciones, {
    String? tokenOverride,
  }) async {
    return await _client.sendActions(acciones, tokenOverride: tokenOverride);
  }

  Future<Map<String, dynamic>> fetchClients({
    String q = '',
    int desde = 0,
    int limite = 500,
    String? tokenOverride,
  }) async {
    return await _client.fetchClients(
      q: q,
      desde: desde,
      limite: limite,
      tokenOverride: tokenOverride,
    );
  }

  Future<List<CatalogProduct>> fetchCatalog({String? tokenOverride}) async {
    return await _client.fetchCatalog(tokenOverride: tokenOverride);
  }
}

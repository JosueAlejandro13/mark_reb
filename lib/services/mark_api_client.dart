import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/services/ConnectionRoutes_/driver_local_db.dart';

class MarkApiException implements Exception {
  final int statusCode;
  final String message;
  final bool isUnauthorized;
  final bool isRateLimited;
  final bool isPayloadTooLarge;
  final dynamic rawData;

  const MarkApiException({
    required this.statusCode,
    required this.message,
    this.isUnauthorized = false,
    this.isRateLimited = false,
    this.isPayloadTooLarge = false,
    this.rawData,
  });

  @override
  String toString() => message;
}

class LoginAuthResult {
  final bool isSuccess;
  final bool isTwoFactorRequired;
  final DriverSession? session;
  final Login2FaChallenge? challenge;
  final String? errorMessage;
  final String? errorCode;

  const LoginAuthResult.success(this.session)
      : isSuccess = true,
        isTwoFactorRequired = false,
        challenge = null,
        errorMessage = null,
        errorCode = null;

  const LoginAuthResult.twoFactor(this.challenge)
      : isSuccess = false,
        isTwoFactorRequired = true,
        session = null,
        errorMessage = null,
        errorCode = null;

  const LoginAuthResult.error(this.errorMessage, {this.errorCode})
      : isSuccess = false,
        isTwoFactorRequired = false,
        session = null,
        challenge = null;
}

/// Puerta: https://calenigps.com/markv3.1/deliveryPHP/operacion/api.php?a=<acción>
class MarkApiClient {
  static final MarkApiClient _instance = MarkApiClient._internal();
  static MarkApiClient get instance => _instance;

  MarkApiClient._internal();

  static const String defaultEndpoint =
      'http://62.151.176.50/markv3.1/deliveryPHP/operacion/api.php';

  String? _customEndpoint;
  String get endpoint => _customEndpoint ?? defaultEndpoint;

  void setCustomEndpoint(String url) {
    if (url.trim().isNotEmpty) {
      _customEndpoint = url.trim();
    }
  }

  void resetToDefaultEndpoint() {
    _customEndpoint = null;
  }

  String get serverBaseUrl {
    final uri = Uri.parse(endpoint);
    final segments = uri.pathSegments;
    final markIndex = segments.indexOf('markv3.1');
    if (markIndex >= 0) {
      final baseSegments = segments.sublist(0, markIndex + 1);
      return '${uri.origin}/${baseSegments.join('/')}/';
    }
    return '${uri.origin}/';
  }

  String resolveAssetUrl(String relativePath) {
    final clean = relativePath.trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    final stripped = clean.startsWith('/') ? clean.substring(1) : clean;
    return '$serverBaseUrl$stripped';
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _token;
  String? get token => _token;

  void setToken(String? value) {
    _token = value;
  }

  Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: 'auth_token_64', value: token);
  }

  DriverSession? _currentSession;
  DriverSession? get currentSession => _currentSession;
  FlotaPermissions get flota =>
      _currentSession?.flota ?? _cachedFlota ?? const FlotaPermissions();
  FlotaPermissions? _cachedFlota;

  void clearSession() {
    _token = null;
    _currentSession = null;
    _cachedFlota = null;
    _storage.delete(key: 'auth_token_64').catchError((_) {});
    _storage.delete(key: 'flota_permissions_cache').catchError((_) {});
  }

  void updateSession(DriverSession session) {
    _currentSession = session;
    _cachedFlota = session.flota;
    _saveFlotaToStorage(session.flota.raw);
  }

  Future<void> _saveFlotaToStorage(Map<String, dynamic> raw) async {
    try {
      await _storage.write(
          key: 'flota_permissions_cache', value: jsonEncode(raw));
    } catch (_) {}
  }

  Future<void> loadFlotaFromStorage() async {
    try {
      final jsonStr = await _storage.read(key: 'flota_permissions_cache');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          _cachedFlota = FlotaPermissions.fromJson(decoded);
        }
      }
    } catch (_) {}
  }

  Future<String?> loadSavedToken() async {
    _token = await _storage.read(key: 'auth_token_64');
    await loadFlotaFromStorage();
    return _token;
  }

  Future<void> clearToken() async {
    _token = null;
    _currentSession = null;
    _cachedFlota = null;
    await _storage.delete(key: 'auth_token_64');
    await _storage.delete(key: 'flota_permissions_cache');
  }

  Future<void> saveTrustToken(String confianza) async {
    await _storage.write(key: 'two_factor_trust_token', value: confianza);
  }

  Future<String?> loadTrustToken() async {
    return await _storage.read(key: 'two_factor_trust_token');
  }

  Future<void> clearTrustToken() async {
    await _storage.delete(key: 'two_factor_trust_token');
  }

  Map<String, String> _headers({String? customToken, bool isJson = true}) {
    final activeToken = customToken ?? _token;
    return {
      if (isJson) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (activeToken != null && activeToken.isNotEmpty) ...{
        'Authorization': 'Bearer $activeToken',
        'X-Token': activeToken,
      },
    };
  }

  Uri _buildUri(String action) {
    return Uri.parse('$endpoint?a=$action');
  }

  void _printLong(String prefix, String content) {
    if (content.length <= 800) {
      debugPrint('$prefix$content');
      return;
    }
    debugPrint(prefix);
    const int chunkSize = 800;
    for (int i = 0; i < content.length; i += chunkSize) {
      final end =
          (i + chunkSize < content.length) ? i + chunkSize : content.length;
      debugPrint(content.substring(i, end));
    }
  }

  Future<Map<String, dynamic>> _postAction(
    String action,
    Map<String, dynamic> body, {
    String? customToken,
    Duration timeout = const Duration(seconds: 25),
    bool silent = false,
  }) async {
    final uri = _buildUri(action);
    final response = await http
        .post(
          uri,
          headers: _headers(customToken: customToken),
          body: jsonEncode(body),
        )
        .timeout(timeout);

    final shouldLog = !silent &&
        action != 'notificaciones' &&
        action != 'notificacionesLeer';

    if (shouldLog || response.statusCode != 200) {
      debugPrint(
          '========= [api.php?a=$action] HTTP ${response.statusCode} =========');
      if (response.statusCode != 200 ||
          action == 'acciones' ||
          action == 'login' ||
          action == 'login2pasos') {
        final safeBody = Map<String, dynamic>.from(body);
        if (safeBody.containsKey('password')) {
          safeBody['password'] = '******';
        }
        _printLong('Payload enviado ($action): ', jsonEncode(safeBody));
      }
      _printLong('Body: ', response.body);
    }

    return _handleResponse(action, response);
  }

  Map<String, dynamic> _handleResponse(String action, http.Response response) {
    final status = response.statusCode;

    Map<String, dynamic> decoded = {};
    if (response.body.isNotEmpty) {
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else if (raw is List) {
          decoded = {
            'reportes': raw,
            'vehiculos': raw,
            'data': raw,
            'items': raw,
          };
        }
      } catch (_) {}
    }

    final serverError =
        (decoded['error'] ?? decoded['mensaje'] ?? '').toString();

    if (status == 200) {
      // Caso 2FA o respuesta normal
      return decoded;
    }

    switch (status) {
      case 400:
        throw MarkApiException(
          statusCode: 400,
          message: serverError.isNotEmpty
              ? serverError
              : 'Petición mal armada (HTTP 400 en $action).',
          rawData: decoded,
        );
      case 401:
        throw MarkApiException(
          statusCode: 401,
          isUnauthorized: true,
          message: serverError.isNotEmpty
              ? serverError
              : 'Sesión cerrada o token inválido.',
          rawData: decoded,
        );
      case 404:
        throw MarkApiException(
          statusCode: 404,
          message: serverError.isNotEmpty
              ? serverError
              : 'Acción desconocida ($action - HTTP 404).',
          rawData: decoded,
        );
      case 413:
        throw MarkApiException(
          statusCode: 413,
          isPayloadTooLarge: true,
          message: serverError.isNotEmpty
              ? serverError
              : 'Lote mayor a 200 acciones o foto demasiado grande (HTTP 413).',
          rawData: decoded,
        );
      case 429:
        throw MarkApiException(
          statusCode: 429,
          isRateLimited: true,
          message: serverError.isNotEmpty
              ? serverError
              : 'Demasiadas peticiones (HTTP 429). Se reintentará en 60 segundos.',
          rawData: decoded,
        );
      case 503:
        throw MarkApiException(
          statusCode: 503,
          message: serverError.isNotEmpty
              ? serverError
              : 'Servicio no disponible (HTTP 503). Avise a soporte.',
          rawData: decoded,
        );
      default:
        throw MarkApiException(
          statusCode: status,
          message: serverError.isNotEmpty
              ? serverError
              : 'Error del servidor (HTTP $status).',
          rawData: decoded,
        );
    }
  }

  // ===========================================================================
  // 1. AUTENTICACIÓN Y SESIÓN (a=login, a=login2pasos, a=reenviarCodigo, a=yo, a=fcm)
  // ===========================================================================

  /// Iniciar sesión oficial contra POST api.php?a=login
  Future<LoginAuthResult> login({
    required String usuario,
    required String password,
    required String dispositivo,
    String appVersion = '1.0.1',
    String fcm = '',
    String? uuid,
    String? manufacturer,
    String? model,
    String? os,
    double? lat,
    double? lng,
    int? acur,
  }) async {
    final confianzaGuardada = await loadTrustToken();

    final body = <String, dynamic>{
      'usuario': usuario.trim(),
      'password': password,
      'dispositivo': dispositivo,
      'appVersion': appVersion,
      'fcm': fcm,
      'dosPasos': true, // Soporte 2FA Ronda 134
      'configurar2Pasos': true, // Ronda 149
      if (confianzaGuardada != null && confianzaGuardada.isNotEmpty)
        'confianza': confianzaGuardada,
      // Ronda 146: Datos del teléfono para registro de accesos en el servidor
      if (uuid != null && uuid.isNotEmpty) 'uuid': uuid,
      if (manufacturer != null && manufacturer.isNotEmpty)
        'manufacturer': manufacturer,
      if (model != null && model.isNotEmpty) 'model': model,
      if (os != null && os.isNotEmpty) 'os': os,
      if (lat != null && lat != 0) 'lat': lat,
      if (lng != null && lng != 0) 'lng': lng,
      if (acur != null && acur > 0) 'acur': acur,
    };

    final data = await _postAction('login', body);

    // Caso 1: Requiere 2FA (dosPasos: true)
    if (data['dosPasos'] == true && data['ok'] == false) {
      final challenge = Login2FaChallenge.fromJson(data);
      return LoginAuthResult.twoFactor(challenge);
    }

    // Caso 2: Error directo del login
    if (data['ok'] == false) {
      final errorMsg =
          (data['error'] ?? 'Usuario o contraseña incorrectos').toString();
      return LoginAuthResult.error(errorMsg);
    }

    // Caso 3: Éxito total
    final session = DriverSession.fromJson(data);
    updateSession(session);
    if (session.token.isNotEmpty) {
      await saveToken(session.token);
    }

    return LoginAuthResult.success(session);
  }

  /// Ronda 149: Mandar código al correo para configurar 2 pasos en login (sin token)
  Future<Map<String, dynamic>> dosPasosCorreo({
    required String desafio,
    required String correo,
  }) async {
    final body = <String, dynamic>{
      'desafio': desafio,
      'correo': correo.trim(),
    };
    return await _postAction('dosPasosCorreo', body);
  }

  /// Ronda 149: Consultar estado de 2 pasos del usuario actual (con token)
  Future<Map<String, dynamic>> getDosPasosEstado({String? tokenOverride}) async {
    return await _postAction('dosPasos', const {}, customToken: tokenOverride);
  }

  /// Ronda 149: Iniciar activación de 2 pasos desde la app (con token)
  Future<Map<String, dynamic>> dosPasosActivar({
    required String password,
    required String correo,
    String? tokenOverride,
  }) async {
    final body = <String, dynamic>{
      'password': password,
      'correo': correo.trim(),
    };
    return await _postAction('dosPasosActivar', body, customToken: tokenOverride);
  }

  /// Ronda 149: Iniciar desactivación de 2 pasos desde la app (con token)
  Future<Map<String, dynamic>> dosPasosApagar({
    required String password,
    String? tokenOverride,
  }) async {
    final body = <String, dynamic>{
      'password': password,
    };
    return await _postAction('dosPasosApagar', body, customToken: tokenOverride);
  }

  /// Ronda 149: Confirmar activación o apagado de 2 pasos con el código (con token)
  Future<Map<String, dynamic>> dosPasosConfirmar({
    required String desafio,
    required String codigo,
    String? tokenOverride,
  }) async {
    final body = <String, dynamic>{
      'desafio': desafio,
      'codigo': codigo.trim(),
    };
    final res = await _postAction('dosPasosConfirmar', body, customToken: tokenOverride);
    if (res['confianza'] != null) {
      await saveTrustToken(res['confianza'].toString());
    }
    return res;
  }

  /// Confirmar código de 2 pasos contra POST api.php?a=login2pasos
  Future<LoginAuthResult> login2pasos({
    required String desafio,
    required String codigo,
    bool recordar = true,
    String? uuid,
    String? manufacturer,
    String? model,
    String? os,
    double? lat,
    double? lng,
    int? acur,
  }) async {
    final body = <String, dynamic>{
      'desafio': desafio,
      'codigo': codigo.trim(),
      'recordar': recordar,
      if (uuid != null && uuid.isNotEmpty) 'uuid': uuid,
      if (manufacturer != null && manufacturer.isNotEmpty)
        'manufacturer': manufacturer,
      if (model != null && model.isNotEmpty) 'model': model,
      if (os != null && os.isNotEmpty) 'os': os,
      if (lat != null && lat != 0) 'lat': lat,
      if (lng != null && lng != 0) 'lng': lng,
      if (acur != null && acur > 0) 'acur': acur,
    };

    final data = await _postAction('login2pasos', body);

    if (data['ok'] == false) {
      final errorMsg = data['codigoMal'] == true
          ? 'El código de verificación es incorrecto.'
          : (data['error'] ?? 'No se pudo verificar el código').toString();
      return LoginAuthResult.error(errorMsg,
          errorCode: data['codigoMal'] == true ? 'CODIGO_MAL' : null);
    }

    // Si viene token de confianza para recordar dispositivo por 90 días
    if (data['confianza'] != null) {
      await saveTrustToken(data['confianza'].toString());
    }

    final session = DriverSession.fromJson(data);
    updateSession(session);
    if (session.token.isNotEmpty) {
      await saveToken(session.token);
    }

    return LoginAuthResult.success(session);
  }

  /// Reenviar código de 2 pasos contra POST api.php?a=reenviarCodigo
  Future<Map<String, dynamic>> reenviarCodigo({
    required String desafio,
    String medio = 'correo', // 'correo' | 'sms'
  }) async {
    return await _postAction('reenviarCodigo', {
      'desafio': desafio,
      'medio': medio,
    });
  }

  /// Refrescar sesión y permisos (a=yo)
  Future<DriverSession> pingYo({String? tokenOverride}) async {
    final data = await _postAction('yo', const {}, customToken: tokenOverride);
    final merged = <String, dynamic>{
      ...data,
      'token': tokenOverride ?? _token ?? '',
    };
    final session = DriverSession.fromJson(merged);
    updateSession(session);
    return session;
  }

  /// Actualizar token FCM en el servidor (a=fcm)
  Future<bool> updateFcm(String fcmToken, {String? tokenOverride}) async {
    if (fcmToken.isEmpty) return false;
    try {
      final res = await _postAction('fcm', {'fcm': fcmToken}, customToken: tokenOverride);
      final isSaved = res['guardado'] == true ||
          (res['ok'] == true && res['guardado'] != false);
      if (!isSaved) {
        debugPrint(' [MarkApiClient] a=fcm: guardado=false: ${res['error']}');
      }
      return isSaved;
    } catch (e) {
      debugPrint(' [MarkApiClient] Error actualizando FCM token: $e');
      return false;
    }
  }

  // ===========================================================================
  // 1.1. GESTIÓN Y RECUPERACIÓN DE CONTRASEÑA (Ronda 144)
  // ===========================================================================

  /// Solicitar código de recuperación al correo (a=recuperarPassword, sin token)
  Future<Map<String, dynamic>> recuperarPassword(String usuarioOCorreo) async {
    final body = usuarioOCorreo.contains('@')
        ? {'correo': usuarioOCorreo.trim()}
        : {'usuario': usuarioOCorreo.trim()};
    return await _postAction('recuperarPassword', body);
  }

  /// Verificar código OTP de recuperación recibido por correo (a=verificarCodigoRecuperacion, sin token)
  Future<Map<String, dynamic>> verificarCodigoRecuperacion({
    required String usuarioOCorreo,
    required String codigo,
  }) async {
    final body = <String, dynamic>{
      if (usuarioOCorreo.contains('@')) 'correo': usuarioOCorreo.trim() else 'usuario': usuarioOCorreo.trim(),
      'codigo': codigo.trim(),
    };
    return await _postAction('verificarCodigoRecuperacion', body);
  }

  /// Restablecer la contraseña con el resetToken obtenido (a=restablecerPassword, sin token)
  Future<Map<String, dynamic>> restablecerPassword({
    required String resetToken,
    required String passwordNuevo,
  }) async {
    return await _postAction('restablecerPassword', {
      'resetToken': resetToken.trim(),
      'passwordNuevo': passwordNuevo,
    });
  }

  /// Cambiar contraseña de la cuenta activa (a=cambiarPassword, con token)
  Future<Map<String, dynamic>> cambiarPassword({
    required String passwordActual,
    required String passwordNuevo,
    bool cerrarOtras = true,
    String? tokenOverride,
  }) async {
    return await _postAction('cambiarPassword', {
      'passwordActual': passwordActual,
      'passwordNuevo': passwordNuevo,
      'cerrarOtras': cerrarOtras,
    }, customToken: tokenOverride);
  }

  // ===========================================================================
  // 2. LECTURAS DE FLOTA (Ronda 133)
  // ===========================================================================

  Future<Map<String, dynamic>> getPerfil({String? tokenOverride}) async {
    return await _postAction('perfil', const {}, customToken: tokenOverride);
  }

  Future<List<Map<String, dynamic>>> getVehiculos({
    int? idVehic,
    String? tokenOverride,
    bool silent = false,
  }) async {
    final body = <String, dynamic>{
      if (idVehic != null && idVehic > 0) 'idVehic': idVehic,
    };
    final data = await _postAction('vehiculos', body,
        customToken: tokenOverride, silent: silent);
    final list = data['vehiculos'] ?? data['data'] ?? [];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  /// Ronda 156: Seguir un vehículo en el mapa (a=posicion)
  /// idVehic: int, lista de ints o String separado por comas (máx 50).
  /// desde: opcional gps.fecha (Y-m-d H:i:s). Si no hay posición más nueva, posiciones viene vacía.
  Future<Map<String, dynamic>> getPosicion({
    required dynamic idVehic,
    String? desde,
    String? tokenOverride,
    bool silent = true,
  }) async {
    final body = <String, dynamic>{
      'idVehic': idVehic,
      if (desde != null && desde.trim().isNotEmpty) 'desde': desde.trim(),
    };
    return await _postAction(
      'posicion',
      body,
      customToken: tokenOverride,
      silent: silent,
    );
  }

  Future<Map<String, dynamic>> getVehiculo(int idVehic,
      {String? tokenOverride}) async {
    return await _postAction('vehiculo', {'idVehic': idVehic},
        customToken: tokenOverride);
  }

  Future<Map<String, dynamic>> getHistorico(int idVehic,
      {String? fecha, String? tokenOverride}) async {
    final body = <String, dynamic>{
      'idVehic': idVehic,
      if (fecha != null && fecha.isNotEmpty) 'fecha': fecha,
    };
    return await _postAction('historico', body, customToken: tokenOverride);
  }

  Future<Map<String, dynamic>> getNotificaciones({
    int? antes,
    int? limite,
    bool? soloNoLeidas,
    String? tokenOverride,
  }) async {
    final body = <String, dynamic>{
      if (antes != null) 'antes': antes,
      if (limite != null) 'limite': limite,
      if (soloNoLeidas != null) 'soloNoLeidas': soloNoLeidas,
    };
    return await _postAction('notificaciones', body,
        customToken: tokenOverride);
  }

  Future<Map<String, dynamic>> leerNotificaciones({
    List<int>? ids,
    bool todas = false,
    String? tokenOverride,
  }) async {
    final body = <String, dynamic>{
      if (todas) 'todas': true,
      if (ids != null && ids.isNotEmpty) 'ids': ids,
    };
    return await _postAction('notificacionesLeer', body,
        customToken: tokenOverride);
  }

  Future<List<Map<String, dynamic>>> getAlertas({
    int? idVehic,
    int? limite,
    String? tokenOverride,
  }) async {
    final body = <String, dynamic>{
      if (idVehic != null) 'idVehic': idVehic,
      if (limite != null) 'limite': limite,
    };
    final data = await _postAction('alertas', body, customToken: tokenOverride);
    final list = data['alertas'] ?? [];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Map<String, dynamic>? _cachedMasterCatalogs;

  /// Obtiene los catálogos maestros de la plataforma (a=catalogos) con estrategia Cache-First / Stale-While-Revalidate
  /// Cumpliendo la regla de la guía (Pág. 15): "listas de los formularios (combustibles, aseguradoras, prioridades...) -> a=catalogos (pedirla al entrar y guardarla)."
  Future<Map<String, dynamic>> getCatalogos({
    String? tokenOverride,
    bool forceRefresh = false,
  }) async {
    // 1. Si está en memoria y no es forzado, retorno inmediato
    if (!forceRefresh &&
        _cachedMasterCatalogs != null &&
        _cachedMasterCatalogs!.isNotEmpty) {
      return _cachedMasterCatalogs!;
    }

    // 2. Intentar obtener de SQLite/Prefs si no hay memoria y no es forzado
    if (!forceRefresh) {
      final localCats = await DriverLocalDb.instance.getMasterCatalogs();
      if (localCats.isNotEmpty) {
        _cachedMasterCatalogs = localCats;
        // Refresco en segundo plano no bloqueante si hay red
        _backgroundRefreshCatalogos(tokenOverride);
        return localCats;
      }
    }

    // 3. Consultar al servidor
    try {
      final data =
          await _postAction('catalogos', const {}, customToken: tokenOverride);
      if (data.isNotEmpty) {
        _cachedMasterCatalogs = data;
        await DriverLocalDb.instance.saveMasterCatalogs(data);
      }
      return data;
    } catch (e) {
      // 4. Fallback offline: recuperar del almacenamiento local
      final localCats = await DriverLocalDb.instance.getMasterCatalogs();
      if (localCats.isNotEmpty) {
        _cachedMasterCatalogs = localCats;
        return localCats;
      }
      debugPrint('Aviso: sin catálogos maestros en red ni en caché: $e');
      return const {};
    }
  }

  void _backgroundRefreshCatalogos(String? tokenOverride) {
    _postAction('catalogos', const {}, customToken: tokenOverride).then((data) {
      if (data.isNotEmpty) {
        _cachedMasterCatalogs = data;
        DriverLocalDb.instance.saveMasterCatalogs(data);
      }
    }).catchError((_) {});
  }

  /// Precarga y guarda localmente los catálogos maestros (a=catalogos) al iniciar sesión o auto-login
  Future<Map<String, dynamic>> preloadAndCacheCatalogos({
    String? tokenOverride,
  }) async {
    return await getCatalogos(tokenOverride: tokenOverride, forceRefresh: true);
  }

  Future<Map<String, dynamic>> getInspecciones(int idVehic,
      {String? tokenOverride}) async {
    return await _postAction('inspecciones', {'idVehic': idVehic},
        customToken: tokenOverride);
  }

  Future<List<Map<String, dynamic>>> getComandos(int idVehic,
      {String? tokenOverride}) async {
    final data = await _postAction('comandos', {'idVehic': idVehic},
        customToken: tokenOverride);
    final list = data['comandos'] ?? [];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  /// Envío de comando en vivo (ej. paro de motor)
  Future<Map<String, dynamic>> enviarComando({
    required int idVehic,
    required int cod,
    required String codigo,
    String? tokenOverride,
  }) async {
    return await _postAction(
      'comando',
      {'idVehic': idVehic, 'cod': cod, 'codigo': codigo},
      customToken: tokenOverride,
    );
  }

  /// Listar tareas creadas o asignadas al usuario (a=tareas)
  Future<List<Map<String, dynamic>>> getTareas({
    String? estado,
    String? mias,
    int? idVehic,
    String? tokenOverride,
  }) async {
    final body = <String, dynamic>{
      if (estado != null) 'estado': estado,
      if (mias != null) 'mias': mias,
      if (idVehic != null) 'idVehic': idVehic,
    };
    final data = await _postAction('tareas', body, customToken: tokenOverride);
    final list = data['tareas'] ?? data['data'] ?? [];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  /// Detalle de una tarea con comentarios y estados (a=tarea)
  Future<Map<String, dynamic>> getTarea(int idTarea,
      {String? tokenOverride}) async {
    return await _postAction('tarea', {'idTarea': idTarea},
        customToken: tokenOverride);
  }

  /// Reportes de rendimiento y operación (a=reportes)
  Future<Map<String, dynamic>> getReportes({
    required String desde,
    required String hasta,
    int? idVehic,
    String? tokenOverride,
  }) async {
    final body = <String, dynamic>{
      'desde': desde,
      'hasta': hasta,
      if (idVehic != null) 'idVehic': idVehic,
    };
    return await _postAction('reportes', body, customToken: tokenOverride);
  }

  /// Descargar foto binaria de documento o licencia por ID (a=docFoto)
  Future<Uint8List> getDocFoto(int idFoto, {String? tokenOverride}) async {
    final uri = _buildUri('docFoto');
    final response = await http
        .post(
          uri,
          headers: _headers(customToken: tokenOverride),
          body: jsonEncode({'id': idFoto}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw MarkApiException(
      statusCode: response.statusCode,
      message:
          'No se pudo cargar la imagen del documento (HTTP ${response.statusCode}).',
    );
  }

  // ===========================================================================
  // 3. REPARTO Y ACCIONES OFFLINE (a=dia, a=acciones, a=foto, a=clientes, a=catalogo)
  // ===========================================================================

  Future<DayPackage> fetchDayPackage({
    String? fecha,
    Map<String, String>? huellas,
    String? tokenOverride,
  }) async {
    final body = <String, dynamic>{};
    if (fecha != null && fecha.isNotEmpty) {
      body['fecha'] = fecha;
    }
    if (huellas != null && huellas.isNotEmpty) {
      body['huellas'] = huellas;
    }

    final data = await _postAction(
      'dia',
      body,
      customToken: tokenOverride,
      timeout: const Duration(seconds: 25),
    );
    return DayPackage.fromJson(data);
  }

  Future<bool> uploadPhoto({
    required String uuid,
    required int tipo, // 1 = foto, 2 = firma
    required String filePath,
    String? tokenOverride,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return true;
    }

    final uri = _buildUri('foto');
    final request = http.MultipartRequest('POST', uri);
    final activeToken = tokenOverride ?? _token;
    if (activeToken != null && activeToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $activeToken';
      request.headers['X-Token'] = activeToken;
    }
    request.fields['uuid'] = uuid;
    request.fields['tipo'] = tipo.toString();
    request.files.add(await http.MultipartFile.fromPath('archivo', filePath));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    debugPrint(
        '========= [api.php?a=foto] HTTP ${response.statusCode} =========');
    _printLong('Body: ', response.body);

    final data = _handleResponse('foto', response);
    return data['ok'] == true || data['repetido'] == true;
  }

  Future<List<Map<String, dynamic>>> sendActions(
    List<Map<String, dynamic>> acciones, {
    String? tokenOverride,
  }) async {
    if (acciones.isEmpty) return const [];

    final sanitized = acciones.map((act) {
      final map = Map<String, dynamic>.from(act);
      final rawUuid = (map['uuid'] ?? '').toString().trim();
      final isValidUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(rawUuid);
      if (!isValidUuid) {
        map['uuid'] = const Uuid().v4();
      }
      return map;
    }).toList();

    final batch =
        sanitized.length > 200 ? sanitized.sublist(0, 200) : sanitized;

    final data = await _postAction(
      'acciones',
      {'acciones': batch},
      customToken: tokenOverride,
      timeout: const Duration(seconds: 30),
    );

    final resultados = data['resultados'];
    if (resultados is List) {
      return resultados.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> fetchClients({
    String q = '',
    int desde = 0,
    int limite = 500,
    String? tokenOverride,
  }) async {
    final body = <String, dynamic>{
      'desde': desde,
      'limite': limite,
    };
    if (q.trim().isNotEmpty) {
      body['q'] = q.trim();
    }
    return _postAction('clientes', body, customToken: tokenOverride);
  }

  Future<List<CatalogProduct>> fetchCatalog({String? tokenOverride}) async {
    final data =
        await _postAction('catalogo', const {}, customToken: tokenOverride);
    final rawList = data['catalogo'] ?? data['productos'] ?? [];
    if (rawList is List) {
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(CatalogProduct.fromJson)
          .toList();
    }
    return const [];
  }

  /// Ronda 151: CUSTODIA Y RONDINES
  Future<Map<String, dynamic>> getCustodia({String? tokenOverride}) async {
    return _postAction('custodia', const {}, customToken: tokenOverride);
  }

  Future<Map<String, dynamic>> configurarCustodiaClaves({
    required String password,
    required String clave,
    required String coaccion,
    String? tokenOverride,
  }) async {
    return _postAction(
      'custodiaClaves',
      {
        'password': password,
        'clave': clave,
        'coaccion': coaccion,
      },
      customToken: tokenOverride,
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mark_v3/models/Routes_/driver_day_models.dart';
import 'package:mark_v3/services/mark_api_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:mark_v3/widgets/loading_action_button.dart';
import 'package:mark_v3/widgets/snackbar_top.dart';
import 'package:mark_v3/pages/home_page.dart';
import 'package:mark_v3/pages/Auth_/two_factor_auth_page.dart';
import 'package:mark_v3/providers/Routes_/routes_provider.dart';
import 'package:mark_v3/services/ConnectionRoutes_/driver_local_db.dart';
import 'package:mark_v3/providers/Notification_/notifications_provider.dart';
import 'package:mark_v3/providers/Custodia_/custodia_provider.dart';
import 'package:mark_v3/providers/Home_/home_provider.dart';
import 'package:mark_v3/providers/Profile_/profile_provider.dart';
import 'package:mark_v3/providers/Profile_/edit_profile_provider.dart';
import 'package:mark_v3/services/local_notification_service.dart';
import 'package:mark_v3/widgets/location_disclosure_sheet.dart';

// Estado inmutable de la vista de Login
class LoginState {
  final bool isLoading;
  final String? deviceUUID;

  LoginState({
    this.isLoading = false,
    this.deviceUUID,
  });

  LoginState copyWith({
    bool? isLoading,
    String? deviceUUID,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      deviceUUID: deviceUUID ?? this.deviceUUID,
    );
  }
}

// Proveedor global que la UI consumirá
final loginProvider =
    NotifierProvider<LoginNotifier, LoginState>(LoginNotifier.new);

class LoginNotifier extends Notifier<LoginState> {
  @override
  LoginState build() {
    Future.microtask(() => _init());
    return LoginState();
  }

  final MarkApiClient apiClient = MarkApiClient.instance;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  Future<void> _init() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? uuid = prefs.getString('device_uuid');
    if (uuid == null) {
      uuid = const Uuid().v4();
      await prefs.setString('device_uuid', uuid);
    }

    state = state.copyWith(deviceUUID: uuid);
  }

  Future<Position?> getDeviceLocation(BuildContext context) async {
    try {
      final hasPermission =
          await LocationDisclosureSheet.checkAndRequestLocationPermission(context);
      if (!hasPermission) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('No se pudo obtener la ubicación');
      });
    } catch (e) {
      debugPrint('Error al obtener la ubicación: $e');
      return null;
    }
  }

  /// Solicita permisos de notificación de forma no invasiva
  Future<void> requestNotificationPermissions(BuildContext context) async {
    try {
      await LocalNotificationService.requestPermission();
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('Permiso de notificaciones no concedido o error: $e');
    }
  }

  /// Proceso principal de autenticación contra Mark V3.1 (api.php?a=login)
  Future<void> login(
    BuildContext context,
    String email,
    String password,
    bool rememberMe,
  ) async {
    if (email.isEmpty || password.isEmpty) {
      SnackbarTop.showError(
        context,
        "Por favor completa todos los campos para continuar.",
        title: "Campos Incompletos",
      );
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      // 1. Permiso de ubicación (obligatorio para la operativa de ruta)
      Position? position = await getDeviceLocation(context);
      if (position == null) {
        state = state.copyWith(isLoading: false);
        SnackbarTop.showError(
          context,
          "Los permisos de ubicación son necesarios para continuar.",
          title: "Ubicación Requerida",
        );
        return;
      }

      // 2. Permiso de notificaciones
      await requestNotificationPermissions(context);

      // 3. Información del dispositivo para la bitácora del servidor
      String dispositivoStr = 'Dispositivo Móvil';
      try {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          dispositivoStr =
              '${androidInfo.manufacturer} ${androidInfo.model} / Android ${androidInfo.version.release}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          dispositivoStr =
              '${iosInfo.name} ${iosInfo.model} / iOS ${iosInfo.systemVersion}';
        }
      } catch (e) {
        debugPrint('Error leyendo deviceInfo: $e');
      }

      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint('No se pudo obtener token FCM: $e');
      }

      // 3.1 Ronda 146: Datos del teléfono para la bitácora
      String manufacturer = 'Desconocido';
      String model = 'Desconocido';
      String os = 'Android';
      try {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          manufacturer = androidInfo.manufacturer;
          model = androidInfo.model;
          os = 'Android ${androidInfo.version.release}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          manufacturer = 'Apple';
          model = iosInfo.model;
          os = 'iOS ${iosInfo.systemVersion}';
        }
      } catch (e) {
        debugPrint('Error extrayendo marca/modelo: $e');
      }

      // 4. Iniciar sesión en la API unificada (Ronda 146)
      final authResult = await apiClient.login(
        usuario: email,
        password: password,
        dispositivo: dispositivoStr,
        appVersion: '1.0.1',
        fcm: fcmToken ?? '',
        uuid: state.deviceUUID,
        manufacturer: manufacturer,
        model: model,
        os: os,
        lat: position.latitude,
        lng: position.longitude,
        acur: position.accuracy.round(),
      );

      // CASO A: Requiere Verificación en 2 Pasos (Ronda 134)
      if (authResult.isTwoFactorRequired && authResult.challenge != null) {
        state = state.copyWith(isLoading: false);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TwoFactorAuthPage(
                challenge: authResult.challenge!,
                email: email,
                password: password,
                initialRememberMe: rememberMe,
              ),
            ),
          );
        }
        return;
      }

      // CASO B: Error de credenciales o de cuenta
      if (!authResult.isSuccess || authResult.session == null) {
        state = state.copyWith(isLoading: false);
        if (context.mounted) {
          SnackbarTop.showError(
            context,
            authResult.errorMessage ?? 'Usuario o contraseña incorrectos.',
            title: "Error de Acceso",
          );
        }
        return;
      }

      // CASO C: Inicio de sesión exitoso
      await _completeSuccessfulLogin(
        context: context,
        session: authResult.session!,
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      String msg = "Ocurrió un error inesperado al iniciar sesión.";
      if (e is MarkApiException) {
        msg = e.message;
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        msg = "Error de conexión. Verifique su red e intente nuevamente.";
      }
      if (context.mounted) {
        SnackbarTop.showError(
          context,
          msg,
          title: "Error de Conexión",
        );
      }
    }
  }

  /// Finaliza el proceso de login tras verificar el código 2FA
  Future<void> completeLoginFrom2Fa({
    required BuildContext context,
    required DriverSession session,
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    await _completeSuccessfulLogin(
      context: context,
      session: session,
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
  }

  /// Finaliza el proceso de login guardando sesión, SQLite y navegando a HomePage
  Future<void> _completeSuccessfulLogin({
    required BuildContext context,
    required DriverSession session,
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final userId = session.usuario.id > 0
        ? session.usuario.id.toString()
        : session.chofer.id.toString();

    final userName = session.usuario.nombre.isNotEmpty
        ? session.usuario.nombre
        : session.chofer.nombre;

    final idCollaborator = session.usuario.idColaborador > 0
        ? session.usuario.idColaborador.toString()
        : session.chofer.id.toString();

    final idMainAccount = session.usuario.idCuenta > 0
        ? session.usuario.idCuenta.toString()
        : '0';

    final isDemo = session.demo;

    // 1. Guardar en SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('token', session.token);
    await prefs.setBool('isDemoUser', isDemo);

    // Sincronizar tokens para todos los servicios
    await secureStorage.write(key: 'auth_token_64', value: session.token);
    await secureStorage.write(key: 'driver_api_token', value: session.token);
    await secureStorage.write(key: 'driver_api_session', value: jsonEncode(session.toJson()));

    // 2. Cambiar base de datos local SQLite al usuario autenticado
    await DriverLocalDb.instance.switchUser(userId, isDemo: isDemo);

    // Precargar y guardar localmente Catálogos Maestros (a=catalogos) según la guía de Nelson (Pág. 15)
    unawaited(apiClient.preloadAndCacheCatalogos().catchError((e) {
      debugPrint('Aviso: no se pudo precargar catálogos maestros en login: $e');
      return <String, dynamic>{};
    }));

    // 3. Reiniciar estado de Riverpod para evitar fuga de datos entre cuentas
    ref.invalidate(profileProvider);
    ref.invalidate(editProfileProvider);
    ref.invalidate(routesProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(homeProvider);
    ref.invalidate(custodiaProvider);

    // 4. Actualizar token FCM en el servidor si está disponible
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await apiClient.updateFcm(fcmToken);
      }
    } catch (e) {
      debugPrint('Aviso: no se pudo actualizar token FCM: $e');
    }

    // 5. Guardar credenciales para renovación o auto-login
    await secureStorage.write(key: 'driver_email', value: email);
    await secureStorage.write(key: 'driver_password', value: password);

    // Permisos mapeados de la estructura "flota" del nuevo backend (Nelson doc)
    final flota = session.flota;
    int encodeBitmask(String modulo) {
      int mask = 0;
      if (flota.can(modulo, 'ver')) mask |= 2;
      if (flota.can(modulo, 'crear')) mask |= 4;
      if (flota.can(modulo, 'editar')) mask |= 8;
      return mask;
    }

    final circulationCardPerm = encodeBitmask('tarjeta').toString();
    final taxesPerm = encodeBitmask('tenencia').toString();
    final verificationsPerm = encodeBitmask('verificacion').toString();
    final insurancePerm = encodeBitmask('seguro').toString();
    final inspectionsPerm = ((flota.can('inspeccion', 'ver') ? 2 : 0) |
            (flota.can('inspeccion', 'crear') ? 4 : 0))
        .toString();
    final creditPerm = ((flota.can('credito', 'ver') ? 2 : 0) |
            (flota.can('credito', 'pagar') ? 4 : 0))
        .toString();
    final vehicleManagement = flota.can('vehiculo', 'editar');

    if (rememberMe) {
      final sessionToken = jsonEncode({
        'userId': userId,
        'userName': userName,
        'idCollaborator': idCollaborator,
        'circulationCardPermission': circulationCardPerm,
        'idMainAccount': idMainAccount,
        'taxesPermission': taxesPerm,
        'uuid': state.deviceUUID.toString(),
        'verificationsPermission': verificationsPerm,
        'insurancePermission': insurancePerm,
        'inspectionsPermission': inspectionsPerm,
        'creditPermission': creditPerm,
        'additionalPermissions':
            jsonEncode({'vehicleManagement': vehicleManagement}),
        'creationId': '0',
        'email': email,
        'password': password,
      });
      await secureStorage.write(key: 'session_token', value: sessionToken);
    } else {
      await secureStorage.delete(key: 'session_token');
    }

    state = state.copyWith(isLoading: false);

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => HomePage(
          userId: userId,
          userName: userName,
          idCollaborator: idCollaborator,
          circulationCardPermission: circulationCardPerm,
          idMainAccount: idMainAccount,
          taxesPermission: taxesPerm,
          uuid: state.deviceUUID.toString(),
          verificationsPermission: verificationsPerm,
          insurancePermission: insurancePerm,
          inspectionsPermission: inspectionsPerm,
          creditPermission: creditPerm,
          additionalPermissions:
              jsonEncode({'vehicleManagement': vehicleManagement}),
          creationId: '0',
          email: email,
          password: password,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var offsetAnimation = animation.drive(
            Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOut)),
          );
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  /// Diálogo modal estilo Apple para Verificación en 2 Pasos (Ronda 134)
  void _show2FaDialog({
    required BuildContext context,
    required Login2FaChallenge challenge,
    required String email,
    required String password,
    required bool rememberMe,
  }) {
    final codeController = TextEditingController();
    bool isVerifying = false;
    bool isResending = false;
    bool rememberDevice = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final mediaQuery = MediaQuery.of(ctx);
            return Padding(
              padding: EdgeInsets.only(
                bottom: mediaQuery.viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: Color(0xFF0284C7),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Verificación en 2 pasos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      challenge.error.isNotEmpty
                          ? challenge.error
                          : 'Ingresa el código de 6 dígitos que enviamos para verificar tu identidad.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF0284C7),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: rememberDevice,
                          activeColor: const Color(0xFF0284C7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) {
                            setSheetState(() => rememberDevice = val ?? true);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Recordar este dispositivo por 90 días',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LoadingActionButton(
                      text: 'Verificar y Entrar',
                      isLoading: isVerifying,
                      icon: Icons.check_circle_rounded,
                      borderRadius: 14,
                      height: 50,
                      fontSize: 15,
                      onPressed: () async {
                        final code = codeController.text.trim();
                        if (code.length != 6) {
                          SnackbarTop.showError(
                            context,
                            "El código debe tener 6 dígitos.",
                            title: "Código Incompleto",
                          );
                          return;
                        }

                        setSheetState(() => isVerifying = true);
                        String? fcmToken;
                        try {
                          fcmToken = await FirebaseMessaging.instance.getToken();
                        } catch (_) {}

                        final res = await apiClient.login2pasos(
                          desafio: challenge.desafio,
                          codigo: code,
                          recordar: rememberDevice,
                          fcm: fcmToken,
                        );
                        setSheetState(() => isVerifying = false);

                        if (!res.isSuccess || res.session == null) {
                          if (context.mounted) {
                            SnackbarTop.showError(
                              context,
                              res.errorMessage ??
                                  'Código incorrecto. Intenta nuevamente.',
                              title: "Código Inválido",
                            );
                          }
                          return;
                        }

                        Navigator.of(sheetContext).pop();
                        await _completeSuccessfulLogin(
                          context: context,
                          session: res.session!,
                          email: email,
                          password: password,
                          rememberMe: rememberMe,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: isResending
                              ? null
                              : () async {
                                  setSheetState(() => isResending = true);
                                  try {
                                    await apiClient.reenviarCodigo(
                                      desafio: challenge.desafio,
                                      medio: challenge.enviado.isNotEmpty
                                          ? challenge.enviado
                                          : 'correo',
                                    );
                                    if (context.mounted) {
                                      SnackbarTop.showSuccess(
                                        context,
                                        "Se reenvió un nuevo código a tu correo/teléfono.",
                                        title: "Código Enviado",
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      SnackbarTop.showError(
                                        context,
                                        "No se pudo reenviar el código. Espera unos momentos.",
                                        title: "Error al Reenviar",
                                      );
                                    }
                                  } finally {
                                    setSheetState(() => isResending = false);
                                  }
                                },
                          child: Text(
                            isResending ? 'Enviando...' : 'Reenviar código',
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

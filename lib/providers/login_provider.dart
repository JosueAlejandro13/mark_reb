import 'dart:async';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mark_v3/services/database_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:uuid/uuid.dart';
import 'package:mark_v3/pages/home_page.dart';

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
    // La inicialización no se puede hacer con constructores asíncronos directamente,
    // pero podemos disparar una función _init()
    Future.microtask(() => _init());
    return LoginState();
  }

  final DatabaseService authService = DatabaseService();
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

  Widget _buildErrorSnackBar(BuildContext context, String message,
      {Color color = Colors.redAccent, IconData icon = Icons.error}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: screenWidth * 0.034,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Position?> getDeviceLocation(BuildContext context) async {
    try {
      bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        showTopSnackBar(
          Overlay.of(context),
          _buildErrorSnackBar(context,
              "Los servicios de ubicación están deshabilitados. Habilítelos para continuar."),
        );
        Future.delayed(const Duration(seconds: 2), () {
          Geolocator.openLocationSettings();
        });
        return null;
      }

      LocationPermission permisos = await Geolocator.checkPermission();
      if (permisos == LocationPermission.denied) {
        permisos = await Geolocator.requestPermission();
        if (permisos == LocationPermission.denied) return null;
      }

      if (permisos == LocationPermission.deniedForever) {
        showTopSnackBar(
          Overlay.of(context),
          _buildErrorSnackBar(context,
              "Permisos bloqueados. Debe habilitarlos para continuar."),
        );
        Future.delayed(const Duration(seconds: 2), () {
          Geolocator.openAppSettings();
        });
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

  Future<void> login(BuildContext context, String email, String password,
      bool rememberMe) async {
    if (email.isEmpty || password.isEmpty) {
      showTopSnackBar(
        Overlay.of(context),
        _buildErrorSnackBar(context, "Por favor complete todos los campos."),
      );
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      Position? position = await getDeviceLocation(context);
      if (position == null) {
        state = state.copyWith(isLoading: false);
        showTopSnackBar(
          Overlay.of(context),
          _buildErrorSnackBar(context,
              "Los permisos de ubicación son necesarios para continuar."),
        );
        return;
      }

      PermissionStatus notifStatus = await Permission.notification.request();
      if (!notifStatus.isGranted) {
        showTopSnackBar(
          Overlay.of(context),
          _buildErrorSnackBar(context,
              "Notificaciones deshabilitadas. Actívelas para recibir alertas.",
              color: Colors.orangeAccent, icon: Icons.notifications_off),
        );
      }

      final userData = await authService.authenticateUser(email, password);
      if (userData == null || userData['id'] == null) {
        state = state.copyWith(isLoading: false);
        showTopSnackBar(
          Overlay.of(context),
          _buildErrorSnackBar(context, "Usuario o contraseña incorrectos."),
        );
        return;
      }

      final userId = userData['id'].toString();

      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await authService.insertTokenFire(
            int.parse(userId), fcmToken, DateTime.now());
      }

      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      String manufacturer = androidInfo.manufacturer;
      String model = androidInfo.model;
      String os = 'Android';
      String ver = androidInfo.version.release;

      if (state.deviceUUID == null) throw Exception('No UUID');

      final permissions = userData['permissions'];
      final int creationId = await authService.insertAccessRecord(
            int.parse(userId),
            state.deviceUUID!,
            1,
            DateTime.now(),
            manufacturer,
            model,
            os,
            ver,
            position.latitude.toString(),
            position.longitude.toString(),
            position.accuracy.toString(),
          ) ??
          0;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('creationId', creationId);

      // Guardar el "token" (datos de sesión) en Secure Storage para auto-login SOLO si activó "Recordarme"
      if (rememberMe) {
        final sessionToken = jsonEncode({
          'userId': userId,
          'userName': userData['usuario'],
          'idCollaborator': userData['idCollaborator'],
          'circulationCardPermission':
              permissions['circulationCard'].toString(),
          'idMainAccount': userData['idMainAccount'],
          'taxesPermission': permissions['taxes'].toString(),
          'uuid': state.deviceUUID.toString(),
          'verificationsPermission': permissions['verifications'].toString(),
          'insurancePermission': permissions['insurance'].toString(),
          'inspectionsPermission': permissions['inspections'].toString(),
          'creditPermission': permissions['credit'].toString(),
          'additionalPermissions': jsonEncode(
              {'vehicleManagement': permissions['vehicleManagement'] == 1}),
          'creationId': creationId.toString(),
          'email': email,
          'password': password,
        });
        await secureStorage.write(key: 'session_token', value: sessionToken);
      } else {
        await secureStorage.delete(key: 'session_token');
      }

      state = state.copyWith(isLoading: false);

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => HomePage(
            userId: userId,
            userName: userData['usuario']!,
            idCollaborator: userData['idCollaborator']!,
            circulationCardPermission:
                permissions['circulationCard'].toString(),
            idMainAccount: userData['idMainAccount']!,
            taxesPermission: permissions['taxes'].toString(),
            uuid: state.deviceUUID.toString(),
            verificationsPermission: permissions['verifications'].toString(),
            insurancePermission: permissions['insurance'].toString(),
            inspectionsPermission: permissions['inspections'].toString(),
            creditPermission: permissions['credit'].toString(),
            additionalPermissions: jsonEncode(
                {'vehicleManagement': permissions['vehicleManagement'] == 1}),
            creationId: creationId.toString(),
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
    } catch (e) {
      state = state.copyWith(isLoading: false);
      String msg = "Ocurrió un error inesperado. Intente nuevamente.";
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        msg = "Error de conexión. Verifique su red e intente nuevamente";
      }
      showTopSnackBar(
        Overlay.of(context),
        _buildErrorSnackBar(context, msg),
      );
    }
  }
}

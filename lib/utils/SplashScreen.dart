import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/Auth_/login_page.dart';
import 'package:mark_v3/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mark_v3/services/ConnectionCustodia_/custodia_local_db.dart';
import 'package:mark_v3/services/ConnectionRoutes_/driver_local_db.dart';
import 'package:mark_v3/services/mark_api_client.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hasNavigated = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _sessionToken;
  Future<void>? _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = _checkToken();

    // Precargar la animación Lottie del login para una transición instantánea
    try {
      AssetLottie('assets/ini.json').load();
    } catch (_) {}

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Navegación automática cuando termina la animación
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateNext();
      }
    });

    // Timeout de seguridad por si la animación no se completa
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_hasNavigated) {
        _navigateNext();
      }
    });
  }

  Future<void> _checkToken() async {
    try {
      _sessionToken = await _secureStorage.read(key: 'session_token');
    } catch (e) {
      debugPrint("Error leyendo token en Splash: $e");
    }
  }

  Future<void> _navigateNext() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // Asegurar que terminó la lectura del token
    await _tokenFuture;

    Widget targetPage;
    if (_sessionToken != null) {
      try {
        final data = jsonDecode(_sessionToken!);
        final uid = data['userId']?.toString() ?? '';
        final token = data['token']?.toString() ?? '';
        if (token.isNotEmpty) {
          MarkApiClient.instance.setToken(token);
          // Ronda 146: Enviar token FCM cada vez que se abre la app con sesión activa
          unawaited(() async {
            try {
              final fcm = await FirebaseMessaging.instance.getToken();
              if (fcm != null && fcm.isNotEmpty) {
                await MarkApiClient.instance.updateFcm(fcm, tokenOverride: token);
              }
            } catch (e) {
              debugPrint("Error actualizando FCM en SplashScreen: $e");
            }
          }());
        }
        final prefs = await SharedPreferences.getInstance();
        if (uid.isNotEmpty) {
          await prefs.setString('userId', uid);
        }
        final isDemo = prefs.getBool('isDemoUser') ?? false;
        await DriverLocalDb.instance.switchUser(uid, isDemo: isDemo);
        await CustodiaLocalDb.instance.switchUser(uid, isDemo: isDemo);
        // Precargar y sincronizar catálogos maestros en segundo plano
        unawaited(
          MarkApiClient.instance
              .preloadAndCacheCatalogos()
              .catchError((_) => <String, dynamic>{}),
        );

        targetPage = HomePage(
          userId: data['userId'],
          userName: data['userName'],
          idCollaborator: data['idCollaborator'],
          circulationCardPermission: data['circulationCardPermission'],
          idMainAccount: data['idMainAccount'],
          taxesPermission: data['taxesPermission'],
          uuid: data['uuid'],
          verificationsPermission: data['verificationsPermission'],
          insurancePermission: data['insurancePermission'],
          inspectionsPermission: data['inspectionsPermission'],
          creditPermission: data['creditPermission'],
          additionalPermissions: data['additionalPermissions'],
          creationId: data['creationId'],
          email: data['email'],
          password: data['password'],
        );
      } catch (e) {
        targetPage = const LoginPage();
      }
    } else {
      targetPage = const LoginPage();
    }

    if (!mounted) return;

    // Transición suave FadeTransition hacia Login o Home
    Get.off(
      () => targetPage,
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 350,
            height: 350,
            child: Lottie.asset(
              'assets/caleni_splash_telematics.json',
              controller: _controller,
              fit: BoxFit.contain,
              onLoaded: (composition) {
                _controller
                  ..duration = composition.duration
                  ..forward();
              },
            ),
          ),
        ),
      ),
    );
  }
}

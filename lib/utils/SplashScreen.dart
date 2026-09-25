import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:mark_v3/pages/login_page.dart';
import 'package:mark_v3/pages/home_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _sessionToken;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _checkToken();
  }

  Future<void> _checkToken() async {
    _sessionToken = await _secureStorage.read(key: 'session_token');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Cambia esto al color de fondo de tu app
      body: Center(
        child: Lottie.asset(
          'assets/ini.json', // Animación de Lottie local
          controller: _controller,
          width: 300,
          height: 300,
          onLoaded: (composition) {
            _controller
              ..duration = composition.duration
              ..forward().whenComplete(() {
                if (mounted) {
                  if (_sessionToken != null) {
                    try {
                      final data = jsonDecode(_sessionToken!);
                      Get.off(
                        () => HomePage(
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
                        ),
                        transition: Transition.zoom,
                        duration: const Duration(milliseconds: 800),
                      );
                    } catch (e) {
                      Get.off(() => const LoginPage(), transition: Transition.zoom, duration: const Duration(milliseconds: 800));
                    }
                  } else {
                    Get.off(
                      () => const LoginPage(),
                      transition: Transition.zoom,
                      duration: const Duration(milliseconds: 800),
                    );
                  }
                }
              });
          },
        ),
      ),
    );
  }
}
